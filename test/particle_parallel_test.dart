import 'dart:ffi' hide Size;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/native/flash_native_bindings.dart' as native;
import 'package:vector_math/vector_math_64.dart' as v;

/// `fill_vertex_buffer` splits the particle array into chunks, runs a visibility
/// pass across the thread pool, then has each chunk write its vertices at an
/// offset derived from the counts of every chunk before it.
///
/// That offset arithmetic is the whole correctness argument for the parallel
/// path: get it wrong and chunks overwrite each other, which shows up as
/// flickering or missing particles rather than a crash. So the test is parity —
/// the same input down both paths must produce byte-identical output.
///
/// It is not a smoke test. Uneven visibility across chunks is exactly what
/// makes the offsets non-trivial, so half the particles are pushed behind the
/// camera on purpose.
void main() {
  /// Mirrors `g_parallelThreshold`'s default in `src/native/particles.cpp`.
  const defaultThreshold = 4096;

  /// Runs the fill and returns the vertex and colour buffers as Dart lists.
  ({int rendered, List<double> vertices, List<int> colors}) fill(
    FParticleEmitter emitter,
    int sides,
    Pointer<Float> matrix,
  ) {
    final vertsPerParticle = (sides - 2) * 3;
    final capacity = emitter.activeCount;
    final vertices = calloc<Float>(capacity * vertsPerParticle * 2);
    final colors = calloc<Uint32>(capacity * vertsPerParticle);
    try {
      final rendered = native.fillVertexBuffer(
        emitter.nativeEmitterPointer,
        matrix,
        vertices,
        colors,
        capacity,
      );
      final n = rendered * vertsPerParticle;
      return (
        rendered: rendered,
        vertices: vertices.asTypedList(n * 2).toList(),
        colors: colors.asTypedList(n).toList(),
      );
    } finally {
      calloc.free(vertices);
      calloc.free(colors);
    }
  }

  /// An emitter holding [count] particles, half of them behind the camera so
  /// the visible count varies from chunk to chunk.
  FParticleEmitter buildEmitter(int count, int shapeType) {
    final engine = FEngine();
    addTearDown(engine.dispose);

    final emitter = FParticleEmitter(
      config: ParticleEmitterConfig(
        emissionRate: count * 60.0,
        maxParticles: count,
        lifetimeMin: 60,
        lifetimeMax: 60,
        gravity: v.Vector3.zero(),
        velocityMin: v.Vector3(-200, -200, -200),
        velocityMax: v.Vector3(200, 200, 200),
        shapeType: shapeType,
        sizeMin: 2,
        sizeMax: 20,
        startColor: Colors.orange,
      ),
    );
    engine.scene.addChild(emitter);
    while (emitter.activeCount < count) {
      engine.debugTick(1 / 60);
    }
    // A frame of drift, so positions are not all identical to the origin.
    engine.debugTick(1 / 60);
    return emitter;
  }

  late Pointer<Float> matrix;

  setUp(() {
    // Perspective-ish: w depends on z, so roughly half the particles fall
    // behind the near plane and get culled by pass 1.
    matrix = calloc<Float>(16);
    for (int i = 0; i < 16; i++) {
      matrix[i] = 0;
    }
    matrix[0] = 1;
    matrix[5] = 1;
    matrix[10] = 1;
    matrix[11] = 1; // z feeds w
    matrix[15] = 1;
  });

  tearDown(() {
    calloc.free(matrix);
    native.setParticleParallelThreshold(defaultThreshold);
  });

  for (final (shape, sides, label) in [(3, 12, '12-sided'), (4, 3, 'triangle')]) {
    test('parallel and serial fills agree exactly ($label)', () {
      final emitter = buildEmitter(20000, shape);
      addTearDown(emitter.dispose);

      native.setParticleParallelThreshold(1 << 30);
      final serial = fill(emitter, sides, matrix);

      native.setParticleParallelThreshold(0);
      final parallel = fill(emitter, sides, matrix);

      expect(serial.rendered, greaterThan(0), reason: 'nothing was visible; the test proves nothing');
      expect(serial.rendered, lessThan(emitter.activeCount),
          reason: 'nothing was culled, so chunk offsets are all uniform and untested');

      expect(parallel.rendered, serial.rendered);
      expect(parallel.vertices, serial.vertices);
      expect(parallel.colors, serial.colors);
    });
  }

  test('a fill smaller than one chunk per thread still works', () {
    // chunks are capped at the particle count, so this exercises the path where
    // there are fewer chunks than pool threads.
    final emitter = buildEmitter(3, 4);
    addTearDown(emitter.dispose);

    native.setParticleParallelThreshold(1 << 30);
    final serial = fill(emitter, 3, matrix);

    native.setParticleParallelThreshold(0);
    final parallel = fill(emitter, 3, matrix);

    expect(parallel.rendered, serial.rendered);
    expect(parallel.vertices, serial.vertices);
  });

  test('the pool reports a usable thread count', () {
    // 1 means the pool found no concurrency and every dispatch runs inline —
    // correct, but worth knowing rather than silently losing the parallel path.
    expect(native.particlePoolConcurrency(), greaterThanOrEqualTo(1));
  });

  test('repeated fills are stable', () {
    // The pool reuses its chunk scratch across calls. If a stale visibleCount
    // or index list leaked between frames, the second fill would differ.
    final emitter = buildEmitter(20000, 3);
    addTearDown(emitter.dispose);

    native.setParticleParallelThreshold(0);
    final first = fill(emitter, 12, matrix);
    final second = fill(emitter, 12, matrix);

    expect(second.rendered, first.rendered);
    expect(second.vertices, first.vertices);
  });
}
