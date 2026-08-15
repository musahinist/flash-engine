import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/native/flash_native_bindings.dart' as native;
import 'package:ffi/ffi.dart';
import 'dart:ffi' hide Size;
import 'dart:ui' as ui;
import 'package:vector_math/vector_math_64.dart' as v;

/// Frame-time baseline for the engine loop.
///
/// The engine's only performance signal was [FEngine.fps], which counts ticker
/// callbacks and is therefore pinned to the display refresh — it reads 60
/// whether a frame costs 2 ms or 16 ms. These benchmarks measure the work
/// itself, per section, so an optimisation can be shown to have done
/// something rather than asserted to have.
///
/// Run with:
///   flutter test test/benchmark/engine_benchmark.dart --plain-name Baseline
///
/// These are **not** pass/fail tests. They print a report and assert only that
/// the engine did not fall over. Compare numbers across commits by hand.
/// Mirrors g_parallelThreshold's default in src/native/particles.cpp, so the
/// sweeps below can force each path and then restore normal behaviour.
const int kDefaultParallelThreshold = 4096;

void main() {
  /// Drives [frames] engine ticks without a Ticker, so the loop runs as fast
  /// as the machine allows instead of being paced to vsync.
  void run(FEngine engine, int frames) {
    for (int i = 0; i < frames; i++) {
      engine.debugTick(1 / 60);
    }
  }

  void report(String title, FEngine engine) {
    // ignore: avoid_print
    print('\n=== $title ===\n${engine.profiler.report()}');
  }

  group('Baseline', () {
    test('empty scene', () {
      final engine = FEngine()..profiler.enabled = true;
      addTearDown(engine.dispose);
      engine.viewportSize.setValues(1200, 800);

      run(engine, 300);
      report('empty scene', engine);
      expect(engine.profiler.averageFrameMs, greaterThanOrEqualTo(0));
    });

    test('1000 static nodes', () {
      final engine = FEngine()..profiler.enabled = true;
      addTearDown(engine.dispose);
      engine.viewportSize.setValues(1200, 800);

      final rnd = Random(7);
      for (int i = 0; i < 1000; i++) {
        engine.scene.addChild(
          FNode(name: 'n$i')
            ..transform.position = v.Vector3(
              (rnd.nextDouble() - 0.5) * 2000,
              (rnd.nextDouble() - 0.5) * 2000,
              (rnd.nextDouble() - 0.5) * 500,
            ),
        );
      }

      run(engine, 300);
      report('1000 static nodes', engine);
    });

    test('1000 moving nodes', () {
      // The interesting case: every node dirties its transform every frame, so
      // the full write path (Dart -> native struct) and the read path
      // (native -> Dart matrix) both run at full width.
      final engine = FEngine()..profiler.enabled = true;
      addTearDown(engine.dispose);
      engine.viewportSize.setValues(1200, 800);

      final nodes = <FNode>[];
      for (int i = 0; i < 1000; i++) {
        final node = FNode(name: 'm$i');
        engine.scene.addChild(node);
        nodes.add(node);
      }

      for (int frame = 0; frame < 300; frame++) {
        for (int i = 0; i < nodes.length; i++) {
          nodes[i].transform.position = v.Vector3(i.toDouble(), frame.toDouble(), 0);
        }
        engine.debugTick(1 / 60);
      }
      report('1000 moving nodes', engine);
    });

    test('deep hierarchy (10 wide x 4 deep)', () {
      // Exercises _canProcess walking to the root and setWorldDirty's subtree
      // propagation, both of which scale with depth.
      final engine = FEngine()..profiler.enabled = true;
      addTearDown(engine.dispose);
      engine.viewportSize.setValues(1200, 800);

      FNode makeSubtree(FNode parent, int depth) {
        if (depth == 0) return parent;
        for (int i = 0; i < 10; i++) {
          final child = FNode(name: 'd$depth-$i');
          parent.addChild(child);
          makeSubtree(child, depth - 1);
        }
        return parent;
      }

      makeSubtree(engine.scene, 4);
      run(engine, 200);
      report('deep hierarchy', engine);
    });

    test('500 rigid bodies', () {
      final engine = FEngine()..profiler.enabled = true;
      addTearDown(engine.dispose);
      engine.viewportSize.setValues(1200, 800);

      final world = FPhysicsSystem(gravity: v.Vector2(0, -980));
      addTearDown(world.dispose);
      engine.physicsWorld = world;

      // Ground.
      engine.scene.addChild(
        FPhysicsBody(
          world: world.world,
          type: FPhysics.staticBody,
          shapeType: FPhysics.box,
          x: 0,
          y: -600,
          width: 6000,
          height: 60,
        ),
      );

      final rnd = Random(11);
      for (int i = 0; i < 500; i++) {
        engine.scene.addChild(
          FPhysicsBody(
            world: world.world,
            type: FPhysics.dynamicBody,
            shapeType: i.isEven ? FPhysics.circle : FPhysics.box,
            x: (rnd.nextDouble() - 0.5) * 2000,
            y: rnd.nextDouble() * 2000,
            width: 24,
            height: 24,
          ),
        );
      }

      // Let them settle into contact — the expensive regime.
      run(engine, 400);
      report('500 rigid bodies', engine);
    });

    test('300 boxes stacking', () {
      // Box-box pairs are the expensive narrow-phase case: SAT with per-corner
      // projection. The mixed scenario above is half circles, which take a
      // much cheaper path, so it understates the cost of detectBoxBox.
      final engine = FEngine()..profiler.enabled = true;
      addTearDown(engine.dispose);
      engine.viewportSize.setValues(1200, 800);

      final world = FPhysicsSystem(gravity: v.Vector2(0, -980));
      addTearDown(world.dispose);
      engine.physicsWorld = world;

      engine.scene.addChild(
        FPhysicsBody(
          world: world.world,
          type: FPhysics.staticBody,
          shapeType: FPhysics.box,
          x: 0,
          y: -400,
          width: 3000,
          height: 60,
        ),
      );

      final rnd = Random(23);
      for (int i = 0; i < 300; i++) {
        engine.scene.addChild(
          FPhysicsBody(
            world: world.world,
            type: FPhysics.dynamicBody,
            shapeType: FPhysics.box,
            x: (rnd.nextDouble() - 0.5) * 900,
            y: -350 + (i ~/ 20) * 40.0,
            width: 30,
            height: 30,
            rotation: rnd.nextDouble() * 0.2,
          ),
        );
      }

      run(engine, 400);
      report('300 boxes stacking', engine);
    });

    test('100k particles', () {
      final engine = FEngine()..profiler.enabled = true;
      addTearDown(engine.dispose);
      engine.viewportSize.setValues(1200, 800);

      final emitter = FParticleEmitter(
        config: ParticleEmitterConfig(
          emissionRate: 100000,
          maxParticles: 100000,
          lifetimeMin: 2,
          lifetimeMax: 4,
          startColor: Colors.orange,
        ),
      );
      engine.scene.addChild(emitter);

      run(engine, 120);
      report('100k particles (active: ${emitter.activeCount})', engine);
    });

    test('paint path: sort + per-node draw', () {
      // FPainter never runs in the scenarios above, because they have no
      // CustomPaint. It is where the Z sort and the per-node MVP multiply
      // live, so it is the section that decides whether moving the render
      // list into C++ is worth the ABI change. Driven directly here against a
      // real Canvas.
      final engine = FEngine()..profiler.enabled = true;
      addTearDown(engine.dispose);
      engine.viewportSize.setValues(1200, 800);

      final camera = FCameraNode(name: 'cam');
      engine.scene.addChild(camera);
      engine.registerCamera(camera);

      final rnd = Random(31);
      for (int i = 0; i < 1000; i++) {
        engine.scene.addChild(
          _BenchBox(size: 40)
            ..transform.position = v.Vector3(
              (rnd.nextDouble() - 0.5) * 1600,
              (rnd.nextDouble() - 0.5) * 1000,
              (rnd.nextDouble() - 0.5) * 400,
            ),
        );
      }

      engine.debugTick(1 / 60);
      final painter = FPainter(engine: engine, camera: engine.activeCamera);

      const frames = 120;
      for (int i = 0; i < frames; i++) {
        engine.debugTick(1 / 60);
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(1200, 800));
        recorder.endRecording().dispose();
      }

      report('paint path: 1000 boxes, ${engine.renderNodes.length} in render list', engine);
    });

    test('serial vs parallel crossover', () {
        // ignore: avoid_print
      print('\n  ${'count'.padLeft(8)}${'serial'.padLeft(10)}${'parallel'.padLeft(10)}${'ratio'.padLeft(9)}');
        for (final count in [500, 1000, 2000, 4000, 8000, 16000, 32000, 64000]) {
          final engine = FEngine();
          final emitter = FParticleEmitter(
            config: ParticleEmitterConfig(
              emissionRate: count * 60.0,
              maxParticles: count,
              lifetimeMin: 60,
              lifetimeMax: 60,
              gravity: v.Vector3.zero(),
              shapeType: 3,
              startColor: Colors.orange,
            ),
          );
          engine.scene.addChild(emitter);
          while (emitter.activeCount < count) {
            engine.debugTick(1 / 60);
          }

          const vpp = 30;
          final cap = emitter.activeCount;
          final vertices = calloc<Float>(cap * vpp * 2);
          final colors = calloc<Uint32>(cap * vpp);
          final matrix = calloc<Float>(16);
          for (int i = 0; i < 16; i++) {
            matrix[i] = 0;
          }
          matrix[0] = 1;
          matrix[5] = 1;
          matrix[10] = 1;
          matrix[15] = 1000;

          double run(int n) {
            final sw = Stopwatch()..start();
            for (int i = 0; i < n; i++) {
              native.fillVertexBuffer(emitter.nativeEmitterPointer, matrix, vertices, colors, cap);
            }
            sw.stop();
            return sw.elapsedMicroseconds / n / 1000;
          }

          native.setParticleParallelThreshold(1 << 30);
          run(50);
          final s = run(300);
          native.setParticleParallelThreshold(0);
          run(50);
          final p = run(300);

          // ignore: avoid_print
      print('  ${cap.toString().padLeft(8)}${s.toStringAsFixed(3).padLeft(10)}'
              '${p.toStringAsFixed(3).padLeft(10)}${(s / p).toStringAsFixed(2).padLeft(9)}');

          calloc.free(vertices);
          calloc.free(colors);
          calloc.free(matrix);
          engine.dispose();
        }
        native.setParticleParallelThreshold(kDefaultParallelThreshold);
    });

    test('particle vertex fill (paint path)', () {
      // fill_vertex_buffer is only reached through FPainter, which needs a real
      // CustomPaint — so the engine-loop scenarios above never touch it. This
      // drives it directly, because it is the path the 1M-particle target
      // actually depends on.
      //
      // Swept over both shape and count, and reported in MB/s as well as ms,
      // because the interesting question is whether this function is compute
      // bound (in which case threads help) or bandwidth bound (in which case
      // nothing does except writing fewer bytes). A 12-sided particle emits 30
      // vertices; the shape the 1M demo uses emits 3.
      const cases = [
        (shape: 3, sides: 12, count: 100000, label: '12-sided'),
        (shape: 4, sides: 3, count: 100000, label: 'triangle'),
        (shape: 4, sides: 3, count: 1000000, label: 'triangle'),
        (shape: 0, sides: 4, count: 1000000, label: 'quad'),
        // The heaviest configuration the demo can actually reach: 12-sided is
        // capped at 500k, only the triangle shape goes to 1M.
        (shape: 3, sides: 12, count: 500000, label: '12-sided'),
      ];

      // ignore: avoid_print
      print('\n=== particle vertex fill ===');
      // ignore: avoid_print
      print('  pool concurrency: ${native.particlePoolConcurrency()} threads');
      // ignore: avoid_print
      print('  ${'shape'.padRight(10)}${'count'.padLeft(9)}'
          '${'serial'.padLeft(10)}${'parallel'.padLeft(10)}${'MB'.padLeft(8)}${'GB/s'.padLeft(8)}');

      for (final c in cases) {
        final engine = FEngine();
        final emitter = FParticleEmitter(
          config: ParticleEmitterConfig(
            emissionRate: c.count * 60.0,
            maxParticles: c.count,
            lifetimeMin: 60,
            lifetimeMax: 60,
            gravity: v.Vector3.zero(),
            shapeType: c.shape,
            startColor: Colors.orange,
          ),
        );
        engine.scene.addChild(emitter);
        while (emitter.activeCount < c.count) {
          engine.debugTick(1 / 60);
        }

        // A fan of `sides` corners is (sides - 2) triangles, 3 vertices each.
        final vertsPerParticle = (c.sides - 2) * 3;
        final capacity = emitter.activeCount;
        final vertices = calloc<Float>(capacity * vertsPerParticle * 2);
        final colors = calloc<Uint32>(capacity * vertsPerParticle);
        final matrix = calloc<Float>(16);
        for (int i = 0; i < 16; i++) {
          matrix[i] = 0;
        }
        matrix[0] = 1;
        matrix[5] = 1;
        matrix[10] = 1;
        matrix[15] = 1000;

        double run(int iterations) {
          final sw = Stopwatch()..start();
          for (int i = 0; i < iterations; i++) {
            native.fillVertexBuffer(
                emitter.nativeEmitterPointer, matrix, vertices, colors, capacity);
          }
          sw.stop();
          return sw.elapsedMicroseconds / iterations / 1000;
        }

        // Force each path in turn over identical input.
        native.setParticleParallelThreshold(1 << 30);
        run(3);
        final serialMs = run(20);

        native.setParticleParallelThreshold(0);
        run(3);
        final parallelMs = run(20);
        native.setParticleParallelThreshold(kDefaultParallelThreshold);

        // 2 floats per vertex plus a uint32 colour per vertex.
        final bytes = capacity * vertsPerParticle * (2 * 4 + 4);
        final mb = bytes / (1024 * 1024);
        final best = serialMs < parallelMs ? serialMs : parallelMs;
        final gbs = bytes / (best / 1000) / (1024 * 1024 * 1024);

        // ignore: avoid_print
        print('  ${c.label.padRight(10)}${capacity.toString().padLeft(9)}'
            '${serialMs.toStringAsFixed(2).padLeft(10)}'
            '${parallelMs.toStringAsFixed(2).padLeft(10)}'
            '${mb.toStringAsFixed(0).padLeft(8)}'
            '${gbs.toStringAsFixed(1).padLeft(8)}');

        calloc.free(vertices);
        calloc.free(colors);
        calloc.free(matrix);
        engine.dispose();
      }
    });
  });
}


/// Minimal bounded, drawable node for the paint benchmark.
class _BenchBox extends FNode {
  _BenchBox({required this.size}) : super(name: 'benchBox');

  final double size;
  final Paint _paint = Paint()..color = const Color(0xFF44AAFF);

  @override
  Rect? get bounds => Rect.fromCenter(center: Offset.zero, width: size, height: size);

  @override
  void draw(Canvas canvas) {
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size, height: size), _paint);
  }
}
