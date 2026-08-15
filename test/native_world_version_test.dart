import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart';

/// The world matrix used to cross the FFI boundary once per node per frame,
/// whether or not the node had moved.
///
/// The getter gated on `nativeScene.totalUpdates`, but C++ increments that
/// unconditionally at the top of every `update_scene_transforms`. So the
/// comparison was always true. Meanwhile C++ already tracked a per-node
/// `worldVersion` that only advances when the matrix is actually recomputed —
/// the right field to compare against, and the one the getter now uses.
void main() {
  late FEngine engine;

  setUp(() => engine = FEngine());
  tearDown(() => engine.dispose());

  FNode attach(String name) {
    final node = FNode(name: name);
    engine.scene.addChild(node);
    return node;
  }

  test('a stationary node stops re-reading its matrix', () {
    final node = attach('still')..transform.position = Vector3(10, 20, 30);

    engine.debugTick(1 / 60);
    node.worldMatrix;
    final afterFirst = node.debugMatrixFetchCount;
    expect(afterFirst, greaterThan(0), reason: 'the first frame must fetch once');

    for (int i = 0; i < 100; i++) {
      engine.debugTick(1 / 60);
      node.worldMatrix;
    }

    expect(
      node.debugMatrixFetchCount,
      afterFirst,
      reason: '100 frames of standing still cost ${node.debugMatrixFetchCount - afterFirst} '
          'extra boundary reads',
    );
  });

  test('a moving node keeps re-reading', () {
    final node = attach('moving');

    engine.debugTick(1 / 60);
    node.worldMatrix;
    final afterFirst = node.debugMatrixFetchCount;

    for (int i = 0; i < 10; i++) {
      node.transform.position = Vector3(i.toDouble(), 0, 0);
      engine.debugTick(1 / 60);
      node.worldMatrix;
    }

    expect(node.debugMatrixFetchCount, greaterThan(afterFirst));
  });

  test('the value stays correct across the gate', () {
    // The gate is only safe if a stale cache is impossible. Move, settle,
    // move again, and check the matrix tracks each time.
    final node = attach('checked');

    node.transform.position = Vector3(5, 0, 0);
    engine.debugTick(1 / 60);
    expect(node.worldPosition.x, closeTo(5, 0.001));

    for (int i = 0; i < 20; i++) {
      engine.debugTick(1 / 60);
    }
    expect(node.worldPosition.x, closeTo(5, 0.001), reason: 'value drifted while idle');

    node.transform.position = Vector3(-9, 0, 0);
    engine.debugTick(1 / 60);
    expect(node.worldPosition.x, closeTo(-9, 0.001));
  });

  test('a child re-reads when only its parent moves', () {
    // The child's own transform is untouched, so its dirty flag never sets —
    // it must still notice that C++ recomputed its world matrix.
    final parent = attach('parent');
    final child = FNode(name: 'child')..transform.position = Vector3(1, 0, 0);
    parent.addChild(child);

    parent.transform.position = Vector3(100, 0, 0);
    engine.debugTick(1 / 60);
    expect(child.worldPosition.x, closeTo(101, 0.001));

    parent.transform.position = Vector3(200, 0, 0);
    engine.debugTick(1 / 60);
    expect(child.worldPosition.x, closeTo(201, 0.001), reason: 'child kept a stale parent transform');
  });
}
