import 'dart:ffi' hide Size;
import 'dart:ui' as ui hide Size;
import 'package:ffi/ffi.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import '../systems/particle.dart';
import '../systems/engine.dart';
import '../native/particles_ffi.dart';
import 'camera.dart';

class FPainter extends CustomPainter {
  final FEngine engine;
  final FCameraNode? camera;

  FPainter({required this.engine, required this.camera, super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // Clip content to viewport bounds to prevent bleeding during transitions
    canvas.clipRect(Offset.zero & size);

    // Viewport Matrix: Map NDC [-1, 1] to Screen [0, width], [0, height]
    final viewportMatrix = Matrix4.identity()
      ..setTranslationRaw(size.width / 2, size.height / 2, 0.0)
      ..scaleByVector3(Vector3(size.width / 2, -size.height / 2, 1.0));

    // Use active camera or fallback
    final activeCam = camera ?? FCameraNode(name: 'PainterFallback');
    final projectionMatrix = activeCam.getProjectionMatrix(size.width, size.height);
    final viewMatrix = activeCam.getViewMatrix();
    final cameraMatrix = viewportMatrix * projectionMatrix * viewMatrix;

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

  // Native buffers for 500k particles to save memory (Quads)
  static final Pointer<Float> _verticesPtr = calloc<Float>(500000 * 6 * 2);
  static final Pointer<Uint32> _colorsPtr = calloc<Uint32>(500000 * 6);
  static final Pointer<Float> _matrixPtr = calloc<Float>(16);

  void _renderParticles(Canvas canvas, Matrix4 cameraMatrix, FParticleEmitter emitter) {
    if (emitter.isDisposed) return;
    final count = emitter.activeCount;
    if (count == 0) return;

    // Copy matrix to native memory
    final matrixData = cameraMatrix.storage;
    for (int i = 0; i < 16; i++) {
      _matrixPtr[i] = matrixData[i];
    }

    // Fill native buffers in C++
    final fillFunc = FlashNativeParticles.fillVertexBuffer;
    if (fillFunc == null) return;

    final renderedCount = fillFunc(emitter.nativeEmitterPointer, _matrixPtr, _verticesPtr, _colorsPtr, 500000);

    if (renderedCount > 0) {
      final vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        _verticesPtr.asTypedList(renderedCount * 6 * 2),
        colors: _colorsPtr.cast<Int32>().asTypedList(renderedCount * 6),
      );

      canvas.drawVertices(vertices, BlendMode.srcOver, Paint());
    }
  }

  @override
  bool shouldRepaint(covariant FPainter oldDelegate) => true;
}
