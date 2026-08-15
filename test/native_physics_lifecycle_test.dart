import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Exercises the native physics allocation and teardown paths.
///
/// `create_physics_world` allocates everything with calloc, but the teardown
/// used to release it with delete[]/delete — undefined behaviour that happened
/// not to crash on this allocator. Creating and destroying many worlds, and
/// running a long simulation, is the cheapest way to keep that honest.
void main() {
  FPhysicsBody spawn(FPhysicsSystem world, {required double x, required double y, int type = FPhysics.dynamicBody}) {
    return FPhysicsBody(
      world: world.world,
      type: type,
      shapeType: FPhysics.circle,
      x: x,
      y: y,
      width: 24,
      height: 24,
    );
  }

  test('physics world can be created and destroyed repeatedly', () {
    for (int i = 0; i < 50; i++) {
      final world = FPhysicsSystem(gravity: v.Vector2(0, -980));
      spawn(world, x: 0, y: 100);
      world.update(1 / 60);
      world.dispose();
    }
  });

  test('a dynamic body falls under Y-up negative gravity', () {
    final world = FPhysicsSystem(gravity: v.Vector2(0, -980));
    addTearDown(world.dispose);

    final body = spawn(world, x: 0, y: 500);
    final startY = body.transform.position.y;

    for (int i = 0; i < 60; i++) {
      world.update(1 / 60);
      body.update(1 / 60);
    }

    expect(
      body.transform.position.y,
      lessThan(startY),
      reason: 'gravity is negative in the Y-up system, so the body should fall',
    );
  });

  test('a long multi-contact run stays stable', () {
    // Also covers the warm-start cache, which is now rebuilt each step. It
    // previously kept an entry for every pair that had ever touched and grew
    // for the whole lifetime of the world.
    final world = FPhysicsSystem(gravity: v.Vector2(0, -980));
    addTearDown(world.dispose);

    final ground = FPhysicsBody(
      world: world.world,
      type: FPhysics.staticBody,
      shapeType: FPhysics.box,
      x: 0,
      y: -200,
      width: 4000,
      height: 40,
    );

    final bodies = [for (int i = 0; i < 30; i++) spawn(world, x: (i - 15) * 45.0, y: 100.0 + i * 30)];

    for (int step = 0; step < 400; step++) {
      world.update(1 / 60);
    }

    for (final b in bodies) {
      b.update(1 / 60);
      expect(b.transform.position.y.isFinite, isTrue, reason: 'solver produced a non-finite position');
    }
    expect(ground.transform.position.y, closeTo(-200, 1.0), reason: 'static body drifted');
  });
}
