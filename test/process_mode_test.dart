import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';

/// [ProcessMode] used to be inert.
///
/// `FNode.update` checked it, but every subclass in the engine overrode
/// `update` and did its work *after* `super.update(dt)` — so a disabled
/// physics body still synced, a disabled timer still counted down, and a
/// disabled emitter still spawned. Nothing overrode `process`, the method the
/// docs pointed at. `FSceneTree.paused` had the mirror problem: it returned
/// early from the whole traversal, which made `ProcessMode.always` and
/// `ProcessMode.paused` unreachable.
class _ProbeNode extends FNode {
  _ProbeNode() : super(name: 'probe');

  int processCalls = 0;

  @override
  void process(double dt) => processCalls++;
}

void main() {
  late FEngine engine;

  setUp(() => engine = FEngine());
  tearDown(() => engine.dispose());

  _ProbeNode attach({ProcessMode mode = ProcessMode.inherit, FNode? parent}) {
    final node = _ProbeNode()..processMode = mode;
    (parent ?? engine.scene).addChild(node);
    return node;
  }

  test('inherit runs while the tree is running', () {
    final node = attach();
    engine.tree.process(1 / 60);
    expect(node.processCalls, 1);
  });

  test('disabled never runs', () {
    final node = attach(mode: ProcessMode.disabled);
    engine.tree.process(1 / 60);
    engine.tree.process(1 / 60);
    expect(node.processCalls, 0);
  });

  test('disabled also stops descendants', () {
    final parent = attach(mode: ProcessMode.disabled);
    final child = attach(parent: parent);
    engine.tree.process(1 / 60);
    expect(parent.processCalls, 0);
    expect(child.processCalls, 0);
  });

  test('inherit stops while the tree is paused', () {
    final node = attach();
    engine.tree.paused = true;
    engine.tree.process(1 / 60);
    expect(node.processCalls, 0);
  });

  test('always keeps running while paused', () {
    final node = attach(mode: ProcessMode.always);
    engine.tree.paused = true;
    engine.tree.process(1 / 60);
    expect(node.processCalls, 1);
  });

  test('paused runs only while paused', () {
    final node = attach(mode: ProcessMode.paused);

    engine.tree.process(1 / 60);
    expect(node.processCalls, 0, reason: 'should be idle while the tree runs');

    engine.tree.paused = true;
    engine.tree.process(1 / 60);
    expect(node.processCalls, 1, reason: 'should run while the tree is paused');
  });

  test('engine subsystems honour the pause', () {
    // Physics, tweens and scene transitions used to keep advancing underneath
    // a pause menu.
    engine.tree.paused = true;
    final before = engine.elapsed;
    engine.tree.process(1 / 60);
    expect(engine.elapsed, before);
  });
}
