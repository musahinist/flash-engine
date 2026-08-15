import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';

/// Native bodies used to be permanent. `create_body` handed out slots from a
/// fixed pool with no way to give one back, so removing an `FPhysicsBody` from
/// the tree stopped it being drawn but left it in the world — still falling,
/// still colliding with whatever was still visible, and still holding its slot.
///
/// Two consequences, both of which these tests pin down: a scene that spawned
/// bodies over time was quietly shoved around by geometry nobody could see, and
/// after 2048 bodies every further one silently failed to be created.
void main() {
  late FPhysicsSystem physics;
  late FEngine engine;

  setUp(() {
    physics = FPhysicsSystem();
    engine = FEngine();
  });
  tearDown(() {
    engine.dispose();
    physics.dispose();
  });

  FPhysicsBody addBody({double x = 0, double y = 300}) {
    final body = FPhysicsBody(world: physics.world, x: x, y: y);
    engine.scene.addChild(body);
    return body;
  }

  void remove(FPhysicsBody body) {
    engine.scene.removeChild(body);
    body.dispose();
  }

  test('a removed body stops being simulated', () {
    final body = addBody();
    remove(body);

    final before = FPhysicsSystem.getBodyPosition(physics.world, body.bodyId).dy;
    for (int i = 0; i < 60; i++) {
      physics.update(1 / 60);
    }
    final after = FPhysicsSystem.getBodyPosition(physics.world, body.bodyId).dy;

    expect(after, before, reason: 'a detached body kept falling');
  });

  test('a removed body no longer collides with live ones', () {
    // The symptom that made this worth chasing: invisible bodies pushing
    // visible ones around.
    final ghost = addBody(x: 0, y: 0);
    remove(ghost);

    final live = addBody(x: 0, y: 60);
    for (int i = 0; i < 120; i++) {
      physics.update(1 / 60);
    }

    // Nothing to rest on, so it should be well below where the ghost sat.
    final y = FPhysicsSystem.getBodyPosition(physics.world, live.bodyId).dy;
    expect(y, lessThan(-200), reason: 'the live body landed on a body that was removed');
  });

  test('the slot is returned to the pool and reused', () {
    // activeCount is a high-water mark, as it is for the node pool: freed slots
    // go to a free list rather than decrementing it.
    final first = addBody();
    final id = first.bodyId;
    remove(first);
    expect(physics.world.ref.bodyFreeCount, 1);

    final second = addBody();
    expect(second.bodyId, id, reason: 'the freed slot was not reused');
    expect(physics.world.ref.bodyFreeCount, 0);
  });

  test('spawning and removing in a loop does not exhaust the pool', () {
    // Without a free list this ran the 2048-slot pool dry and every later
    // create_body returned -1.
    for (int i = 0; i < 5000; i++) {
      final body = addBody();
      expect(body.bodyId, greaterThanOrEqualTo(0), reason: 'pool exhausted at iteration $i');
      remove(body);
    }
    expect(physics.world.ref.activeCount, lessThan(10),
        reason: 'slots were not being recycled');
  });

  test('a recycled slot does not inherit the previous body\'s contacts', () {
    // Warm-start impulses are cached per body pair. A recycled slot picking up
    // the old body's cached impulses would be flung apart on its first frame.
    final ground = FPhysicsBody(world: physics.world, type: 0, x: 0, y: -200, width: 400, height: 40);
    engine.scene.addChild(ground);

    final first = addBody(y: -150);
    for (int i = 0; i < 120; i++) {
      physics.update(1 / 60);
    }
    remove(first);

    final second = addBody(y: -150);
    expect(second.bodyId, first.bodyId, reason: 'slot was not reused; test proves nothing');

    physics.update(1 / 60);
    final pos = FPhysicsSystem.getBodyPosition(physics.world, second.bodyId);
    expect(pos.dy, closeTo(-150, 20), reason: 'the recycled body was kicked by stale impulses');
  });

  test('releasing twice is harmless', () {
    final body = addBody();
    remove(body);
    expect(body.isReleased, isTrue);
    body.dispose();
    expect(physics.world.ref.bodyFreeCount, 1, reason: 'the slot was freed twice');
  });

  test('joints on a destroyed body are dropped', () {
    // A joint left holding a destroyed body would be re-pointed at whatever
    // recycled the slot, silently attaching to the wrong thing.
    final anchor = FPhysicsBody(world: physics.world, type: 0, x: 0, y: 200);
    final hanging = addBody(y: 100);
    engine.scene.addChild(anchor);

    final joint = FDistanceJointStructure(bodyA: anchor, bodyB: hanging, length: 100)
      ..create(physics.world);
    expect(joint.isCreated, isTrue);

    remove(hanging);
    // Simulating with a joint pointing at a dead body must not crash or move
    // the anchor, which is static.
    for (int i = 0; i < 60; i++) {
      physics.update(1 / 60);
    }
    expect(FPhysicsSystem.getBodyPosition(physics.world, anchor.bodyId).dy, closeTo(200, 0.001));
  });
}
