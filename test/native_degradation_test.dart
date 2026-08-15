import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/native/flash_native.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// The engine degrades in tiers rather than failing as a whole when the native
/// core is missing. Previously `FEngine()` simply threw a null-check error
/// from its constructor, so nothing at all could be built.
void main() {
  setUp(() => FlashNative.debugOverrideAvailable = false);
  tearDown(() => FlashNative.debugOverrideAvailable = null);

  group('Tier 0 — scene graph works without the native core', () {
    test('FEngine can still be constructed', () {
      final engine = FEngine();
      addTearDown(engine.dispose);

      expect(engine.hasNativeSceneGraph, isFalse);
      expect(engine.scene, isNotNull);
    });

    test('transforms compose correctly in pure Dart', () {
      final engine = FEngine();
      addTearDown(engine.dispose);

      final parent = FNode(name: 'p')..transform.position = v.Vector3(100, 50, 0);
      final child = FNode(name: 'c')..transform.position = v.Vector3(10, 5, 0);
      engine.scene.addChild(parent);
      parent.addChild(child);

      // No updateSceneTransforms call: the Dart fallback resolves on demand.
      expect(child.worldPosition.x, closeTo(110, 0.001));
      expect(child.worldPosition.y, closeTo(55, 0.001));
    });

    test('nodes can be added and removed without native slots', () {
      final engine = FEngine();
      addTearDown(engine.dispose);

      final node = FNode(name: 'n');
      engine.scene.addChild(node);
      expect(node.nativeNodeId, -1);
      engine.scene.removeChild(node);
      node.dispose();
    });
  });

  group('Tier 1 — particles disable themselves', () {
    test('emitter constructs but is inert', () {
      final emitter = FParticleEmitter(config: ParticleEmitterConfig.fire);
      addTearDown(emitter.dispose);

      expect(emitter.isActive, isFalse);
      expect(emitter.activeCount, 0);
      // Must not throw.
      emitter.update(1 / 60);
    });
  });

  group('Tier 2 — physics fails loudly', () {
    test('FPhysicsSystem throws a descriptive error', () {
      expect(
        () => FPhysicsSystem(),
        throwsA(
          isA<FlashNativeUnavailableError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('Physics'), contains('native core')),
          ),
        ),
      );
    });
  });
}
