import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/native/flash_native_bindings.dart' as native;
import 'package:vector_math/vector_math_64.dart' as v;

/// Pins down the individual bugs fixed alongside the native rework. Each one
/// was silent: nothing crashed, nothing logged, the behaviour was just wrong.
void main() {
  group('FDirectionalLight.applyToColor', () {
    // Color.a/.r/.g/.b are doubles in 0..1 on modern Flutter, but the code
    // passed them to Color.fromARGB as if they were 0-255 bytes. Every shaded
    // colour collapsed to alpha=1 with channels of 0 or 1 — transparent black.
    test('produces a visible colour, not transparent black', () {
      final light = FDirectionalLight(direction: v.Vector3(0, -1, 0));
      final shaded = light.applyToColor(Colors.orange, CubeFaceNormals.top);

      expect(shaded.a, closeTo(1.0, 0.001), reason: 'alpha must survive shading');
      expect(shaded.r + shaded.g + shaded.b, greaterThan(0.1), reason: 'colour collapsed to black');
    });

    test('darkens a surface facing away from the light', () {
      final light = FDirectionalLight(direction: v.Vector3(0, -1, 0), ambient: 0.0);
      final lit = light.applyToColor(Colors.white, v.Vector3(0, -1, 0));
      final unlit = light.applyToColor(Colors.white, v.Vector3(0, 1, 0));
      expect(unlit.r, lessThan(lit.r));
    });
  });

  group('one-shot particle emitters', () {
    // Emission was gated on `activeCount == 0`, so the instant the last
    // particle of a burst died the buffer looked empty and the emitter fired
    // again — the "explosion" preset looped forever.
    test('a non-looping emitter stops after one burst', () {
      final emitter = FParticleEmitter(config: ParticleEmitterConfig.explosion);
      addTearDown(emitter.dispose);

      // Run long enough for the burst to spawn and fully expire.
      for (int i = 0; i < 600; i++) {
        emitter.update(1 / 60);
      }

      expect(emitter.activeCount, 0, reason: 'burst re-fired after its particles died');
    });

    test('restart() re-arms it', () {
      final emitter = FParticleEmitter(config: ParticleEmitterConfig.explosion);
      addTearDown(emitter.dispose);

      for (int i = 0; i < 600; i++) {
        emitter.update(1 / 60);
      }
      expect(emitter.activeCount, 0);

      emitter.restart();
      for (int i = 0; i < 10; i++) {
        emitter.update(1 / 60);
      }
      expect(emitter.activeCount, greaterThan(0));
    });

    test('a looping emitter keeps going', () {
      final emitter = FParticleEmitter(config: ParticleEmitterConfig.fire);
      addTearDown(emitter.dispose);

      for (int i = 0; i < 300; i++) {
        emitter.update(1 / 60);
      }
      expect(emitter.activeCount, greaterThan(0));
    });
  });

  group('transform dirtying', () {
    /// Runs one engine frame: pushes Dart transforms into the native scene,
    /// then resolves world matrices. worldPosition reads the native result,
    /// so both halves are needed.
    void tick(FEngine engine) {
      engine.tree.process(1 / 60);
      if (engine.hasNativeSceneGraph) {
        native.updateSceneTransforms(engine.nativeScene);
      }
    }

    test('an invisible node still syncs later transform changes', () {
      // setWorldDirty() used to bail out when _worldDirty was already set, and
      // that flag is only cleared by reading worldMatrix. A node that is never
      // rendered never clears it, so every subsequent move was dropped.
      final engine = FEngine();
      addTearDown(engine.dispose);

      final node = FNode(name: 'hidden')..visible = false;
      engine.scene.addChild(node);

      // A frame in between: this is what clears _worldDirty on a visible node
      // and what the old short-circuit relied on never happening here.
      node.transform.position = v.Vector3(10, 0, 0);
      tick(engine);
      node.transform.position = v.Vector3(20, 0, 0);
      tick(engine);
      node.transform.position = v.Vector3(30, 0, 0);
      tick(engine);

      expect(node.worldPosition.x, closeTo(30, 0.001));
    });

    test('in-place vector edits are picked up', () {
      // The getters hand out the live Vector3, so this bypasses the setter.
      final engine = FEngine();
      addTearDown(engine.dispose);

      final node = FNode(name: 'n');
      engine.scene.addChild(node);
      node.transform.position = v.Vector3(1, 2, 3);
      tick(engine);
      expect(node.worldPosition.x, closeTo(1, 0.001));

      // Bypasses the setter entirely.
      node.transform.position.x = 99;
      tick(engine);

      expect(node.worldPosition.x, closeTo(99, 0.001));
    });
  });

  group('engine update listeners', () {
    test('listeners receive the real dt and can unsubscribe', () {
      final engine = FEngine();
      addTearDown(engine.dispose);

      final seen = <double>[];
      void listener(double dt) => seen.add(dt);

      engine.addUpdateListener(listener);
      expect(seen, isEmpty);

      engine.removeUpdateListener(listener);
      // Removal must be complete: the old chaining scheme could not undo itself.
      expect(seen, isEmpty);
    });

    test('multiple listeners coexist', () {
      final engine = FEngine();
      addTearDown(engine.dispose);

      var a = 0;
      var b = 0;
      engine.addUpdateListener((_) => a++);
      engine.addUpdateListener((_) => b++);

      // Previously the second registration would have swallowed the first
      // unless it manually chained to it.
      expect(a, 0);
      expect(b, 0);
    });
  });
}
