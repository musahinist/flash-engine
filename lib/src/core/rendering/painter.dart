import 'dart:ffi' hide Size;
import 'dart:ui' as ui hide Size;
import 'package:ffi/ffi.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import '../systems/particle.dart';
import '../systems/engine.dart';
import '../native/flash_native_bindings.dart' as native;
import 'camera.dart';

class FPainter extends CustomPainter {
  final FEngine engine;
  final FCameraNode? camera;

  FPainter({required this.engine, required this.camera, super.repaint});

  /// Reused so a camera-less scene does not allocate one per frame.
  static FCameraNode? _fallbackCamera;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // Clip content to viewport bounds to prevent bleeding during transitions
    canvas.clipRect(Offset.zero & size);

    // One projection path: the camera owns viewport · projection · view.
    final activeCam = camera ?? (_fallbackCamera ??= FCameraNode(name: 'PainterFallback'));
    final cameraMatrix = activeCam.getScreenMatrix(Vector2(size.width, size.height));

    final flatList = engine.renderNodes;
    final lights = engine.lights;
    final emitters = engine.emitters;

    // Z-Sorting (Painter's Algorithm: Back-to-Front)
    // Draw distant objects (Low Z) first, then close objects (High Z) on top.
    flatList.sort((a, b) {
      final az = a.worldPosition.z;
      final bz = b.worldPosition.z;
      // 1. Sort by Z Ascending (Back to Front)
      final cmp = az.compareTo(bz);
      if (cmp != 0) return cmp;

      // 2. Stable Tie-Breaker: If Z is equal, sort by hashCode (Creation/Memory order)
      // This prevents Z-fighting flickering for objects on the same plane.
      return a.hashCode.compareTo(b.hashCode);
    });

    for (final node in flatList) {
      node.renderSelf(canvas, cameraMatrix, lights);
    }

    // Render particles (after regular nodes for proper layering)
    for (final emitter in emitters) {
      _renderParticles(canvas, cameraMatrix, emitter);
    }
  }

  // Scratch buffers the native vertex builder writes into.
  //
  // These used to be sized for a hard-coded 1,000,000 particles at 30 vertices
  // each: 240 MB of floats plus 120 MB of colours, allocated on first particle
  // draw and never released. On a "mobile first" engine that is an instant
  // out-of-memory. They now grow on demand to whatever the largest live
  // emitter actually needs, which for every bundled preset is a few hundred KB.
  static const int _maxVerticesPerParticle = 30; // 12-sided "round" shape
  static int _bufferCapacity = 0;
  static Pointer<Float> _verticesPtr = nullptr;
  static Pointer<Uint32> _colorsPtr = nullptr;
  static final Pointer<Float> _matrixPtr = calloc<Float>(16);

  /// Particle capacity the scratch buffers are currently sized for.
  static int get _maxParticleCapacity => _bufferCapacity;

  /// Grows the scratch buffers so they can hold [particleCount] particles.
  static void _ensureCapacity(int particleCount) {
    if (particleCount <= _bufferCapacity) return;

    // Grow geometrically so a slowly ramping emitter does not reallocate
    // every frame.
    var target = _bufferCapacity == 0 ? 256 : _bufferCapacity;
    while (target < particleCount) {
      target *= 2;
    }

    if (_verticesPtr != nullptr) calloc.free(_verticesPtr);
    if (_colorsPtr != nullptr) calloc.free(_colorsPtr);

    _verticesPtr = calloc<Float>(target * _maxVerticesPerParticle * 2);
    _colorsPtr = calloc<Uint32>(target * _maxVerticesPerParticle);
    _bufferCapacity = target;
  }

  void _renderParticles(Canvas canvas, Matrix4 cameraMatrix, FParticleEmitter emitter) {
    if (!emitter.isActive) return;
    final count = emitter.activeCount;
    if (count == 0) return;

    _ensureCapacity(count);

    // Copy matrix to native memory
    final matrixData = cameraMatrix.storage;
    for (int i = 0; i < 16; i++) {
      _matrixPtr[i] = matrixData[i];
    }

    final renderedCount = native.fillVertexBuffer(
      emitter.nativeEmitterPointer,
      _matrixPtr,
      _verticesPtr,
      _colorsPtr,
      _maxParticleCapacity,
    );

    if (renderedCount > 0) {
      // Get vertex multiplier based on shape
      final vCount = switch (emitter.shapeType) {
        1 => 12, // Hexagon
        2 => 18, // Octagon
        3 => 30, // 12-sided (Round)
        4 => 3, // Triangle (1M+ Ultra Performance)
        _ => 6, // Quad (2 triangles)
      };

      final totalVertices = renderedCount * vCount;

      final vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        _verticesPtr.asTypedList(totalVertices * 2),
        colors: _colorsPtr.cast<Int32>().asTypedList(totalVertices),
      );

      canvas.drawVertices(vertices, BlendMode.srcOver, Paint());
    }
  }

  @override
  bool shouldRepaint(covariant FPainter oldDelegate) => true;
}
