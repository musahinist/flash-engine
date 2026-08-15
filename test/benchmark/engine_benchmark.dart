import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/native/flash_native_bindings.dart' as native;
import 'package:ffi/ffi.dart';
import 'dart:ffi';
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

    test('particle vertex fill (paint path)', () {
      // fill_vertex_buffer is only reached through FPainter, which needs a real
      // CustomPaint — so the engine-loop scenarios above never touch it. This
      // drives it directly, because it is the path the 1M-particle target
      // actually depends on.
      final engine = FEngine();
      addTearDown(engine.dispose);

      final emitter = FParticleEmitter(
        config: ParticleEmitterConfig(
          emissionRate: 200000,
          maxParticles: 100000,
          lifetimeMin: 5,
          lifetimeMax: 8,
          shapeType: 3, // 12-sided: the most vertices per particle
          startColor: Colors.orange,
        ),
      );
      engine.scene.addChild(emitter);
      for (int i = 0; i < 60; i++) {
        engine.debugTick(1 / 60);
      }

      const maxVertsPerParticle = 30;
      final capacity = emitter.activeCount;
      final vertices = calloc<Float>(capacity * maxVertsPerParticle * 2);
      final colors = calloc<Uint32>(capacity * maxVertsPerParticle);
      final matrix = calloc<Float>(16);
      addTearDown(() {
        calloc.free(vertices);
        calloc.free(colors);
        calloc.free(matrix);
      });
      // A plain perspective-ish matrix; only w must stay positive.
      for (int i = 0; i < 16; i++) {
        matrix[i] = 0;
      }
      matrix[0] = 1;
      matrix[5] = 1;
      matrix[10] = 1;
      matrix[15] = 1000;

      final sw = Stopwatch()..start();
      const iterations = 60;
      var rendered = 0;
      for (int i = 0; i < iterations; i++) {
        rendered = native.fillVertexBuffer(
          emitter.nativeEmitterPointer,
          matrix,
          vertices,
          colors,
          capacity,
        );
      }
      sw.stop();

      // ignore: avoid_print
      print('\n=== particle vertex fill ===\n'
          '  ${emitter.activeCount} particles, 12 sides, $rendered rendered\n'
          '  ${(sw.elapsedMicroseconds / iterations / 1000).toStringAsFixed(3)} ms per fill');
      expect(rendered, greaterThan(0));
    });
  });
}
