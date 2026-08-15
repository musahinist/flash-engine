import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
// Not exported from package:flash yet (see plan finding 1.44 — the native
// bindings stay private until the loader consolidation in phase 2).
import 'package:flash/src/core/native/particles_ffi.dart';
import 'package:vector_math/vector_math_64.dart';

/// Covers the native scene-graph slot pool and the order-independent
/// transform resolve added alongside it.
///
/// The pool is fixed-size (10k slots). Before `destroy_native_node` existed,
/// every add/remove cycle burned a slot permanently, and once the pool ran dry
/// `create_native_node` returned -1 and nodes silently fell back to the
/// pure-Dart transform path. None of that surfaced as an error, which is why
/// these are worth pinning down.
void main() {
  test('node slots are returned to the pool on remove', () {
    final engine = FEngine();
    addTearDown(engine.dispose);

    final before = engine.nativeScene.ref.activeCount;

    // Churn well past what a leak would tolerate if slots were never reused.
    for (int i = 0; i < 500; i++) {
      final node = FNode(name: 'churn$i');
      engine.scene.addChild(node);
      engine.scene.removeChild(node);
    }

    final after = engine.nativeScene.ref.activeCount;
    expect(
      after - before,
      lessThanOrEqualTo(1),
      reason: 'activeCount grew by ${after - before} across 500 add/remove '
          'cycles — released slots are not being reused',
    );
    expect(engine.nativeScene.ref.freeCount, greaterThan(0));
  });

  test('a reused slot still produces the correct world transform', () {
    final engine = FEngine();
    addTearDown(engine.dispose);

    // Free a slot, then build a parent/child pair that will reuse it. The
    // child can now land on a lower index than its parent, which the old
    // flat-order resolve got wrong.
    final throwaway = FNode(name: 'throwaway');
    engine.scene.addChild(throwaway);
    engine.scene.removeChild(throwaway);

    final parent = FNode(name: 'parent')..transform.position = Vector3(100, 50, 0);
    final child = FNode(name: 'child')..transform.position = Vector3(10, 5, 0);
    engine.scene.addChild(parent);
    parent.addChild(child);

    FlashNativeParticles.updateSceneTransforms!(engine.nativeScene);

    expect(child.worldPosition.x, closeTo(110, 0.001));
    expect(child.worldPosition.y, closeTo(55, 0.001));
  });

  test('world transform composes regardless of parent/child slot order', () {
    final engine = FEngine();
    addTearDown(engine.dispose);

    final parent = FNode(name: 'p')..transform.position = Vector3(7, -3, 2);
    final child = FNode(name: 'c')..transform.position = Vector3(1, 1, 1);
    final grandchild = FNode(name: 'g')..transform.position = Vector3(2, 0, 0);

    // Attach out of order so the hierarchy does not match creation order.
    engine.scene.addChild(parent);
    child.addChild(grandchild);
    parent.addChild(child);

    FlashNativeParticles.updateSceneTransforms!(engine.nativeScene);

    expect(grandchild.worldPosition.x, closeTo(10, 0.001));
    expect(grandchild.worldPosition.y, closeTo(-2, 0.001));
    expect(grandchild.worldPosition.z, closeTo(3, 0.001));
  });

  test('releasing a node orphans children still pointing at its slot', () {
    final engine = FEngine();
    addTearDown(engine.dispose);

    final parent = FNode(name: 'p')..transform.position = Vector3(100, 0, 0);
    final child = FNode(name: 'c')..transform.position = Vector3(5, 0, 0);
    engine.scene.addChild(parent);
    parent.addChild(child);

    FlashNativeParticles.updateSceneTransforms!(engine.nativeScene);
    expect(child.worldPosition.x, closeTo(105, 0.001));

    // Detaching the parent must not leave the child inheriting from a slot
    // that a later node will reuse.
    engine.scene.removeChild(parent);
    for (int i = 0; i < 5; i++) {
      engine.scene.addChild(FNode(name: 'filler$i')..transform.position = Vector3(999, 999, 0));
    }
    FlashNativeParticles.updateSceneTransforms!(engine.nativeScene);

    expect(child.worldPosition.x, lessThan(900), reason: 'child inherited a recycled slot');
  });
}
