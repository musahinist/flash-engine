import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/native/flash_native_bindings.dart' show RayCastHit;

/// `ray_cast` walked every body in the world, even though the broadphase tree
/// was sitting right there and a segment is the query an AABB tree prunes best.
/// It now descends the tree and runs the exact shape test only on the leaves
/// the segment actually crosses.
///
/// These tests exist because that change can fail silently: a raycast that
/// misses something it should have hit looks like a gameplay quirk, not a bug.
/// So they check what the broadphase must not lose — the nearest hit, hits on
/// bodies the ray only clips, and misses staying misses.
void main() {
  const dynamicBody = 1;
  const staticBody = 0;
  const circle = 0;
  const box = 1;

  late FPhysicsSystem physics;

  setUp(() => physics = FPhysicsSystem());
  tearDown(() => physics.dispose());

  int addCircle(double x, double y, double radius, {int type = staticBody}) {
    return FPhysicsSystem.createBody(
      physics.world, type, circle, x, y, radius * 2, radius * 2, 0, 0x0001, 0xFFFF);
  }

  int addBox(double x, double y, double w, double h,
      {double rotation = 0, int type = staticBody}) {
    return FPhysicsSystem.createBody(
      physics.world, type, box, x, y, w, h, rotation, 0x0001, 0xFFFF);
  }

  RayCastHit? cast(double x0, double y0, double x1, double y1) =>
      FPhysicsSystem.rayCast(physics.world, x0, y0, x1, y1);

  test('a ray through empty space hits nothing', () {
    expect(cast(-500, 0, 500, 0), isNull);
  });

  test('a ray hits a circle in its path', () {
    final id = addCircle(0, 0, 50);
    final hit = cast(-500, 0, 500, 0);
    expect(hit, isNotNull);
    expect(hit!.bodyId, id);
    // Entry point on the near side, not the centre or the far side.
    expect(hit.x, closeTo(-50, 1));
  });

  test('a ray hits a box in its path', () {
    final id = addBox(0, 0, 100, 100);
    final hit = cast(-500, 0, 500, 0);
    expect(hit, isNotNull);
    expect(hit!.bodyId, id);
    expect(hit.x, closeTo(-50, 1));
  });

  test('the nearest of several bodies wins', () {
    // The broadphase returns candidates in tree order, which is not distance
    // order — the exact test still has to pick the closest.
    addCircle(300, 0, 40);
    final near = addCircle(-100, 0, 40);
    addCircle(100, 0, 40);

    final hit = cast(-500, 0, 500, 0);
    expect(hit, isNotNull);
    expect(hit!.bodyId, near, reason: 'a farther body was reported');
    expect(hit.fraction, lessThan(0.5));
  });

  test('the ray is a segment, not an infinite line', () {
    addCircle(400, 0, 40);
    // Stops well short of the body.
    expect(cast(-500, 0, 0, 0), isNull);
    // Extended past it, the same body is found.
    expect(cast(-500, 0, 500, 0)?.bodyId, isNotNull);
  });

  test('a body behind the ray origin is not hit', () {
    addCircle(-300, 0, 40);
    expect(cast(0, 0, 500, 0), isNull);
  });

  test('a ray parallel to an axis and level with a body edge still resolves', () {
    // The slab test divides by the ray direction; a zero component is the case
    // where a naive reciprocal produces NaN and the AABB test silently fails.
    addBox(0, 0, 100, 100);
    expect(cast(0, -500, 0, 500), isNotNull, reason: 'vertical ray missed');
    expect(cast(-500, 0, 500, 0), isNotNull, reason: 'horizontal ray missed');
    // Exactly along the box edge.
    expect(cast(-500, -50, 500, -50), isNotNull, reason: 'edge-aligned ray missed');
  });

  test('a diagonal ray hits a rotated box', () {
    addBox(0, 0, 100, 40, rotation: 0.7);
    expect(cast(-400, -400, 400, 400), isNotNull);
  });

  test('a ray that just misses stays a miss', () {
    addCircle(0, 0, 50);
    // Well clear of the circle, but inside the AABB fattening, so the broad
    // phase offers it as a candidate and the exact test has to reject it.
    expect(cast(-500, 51.5, 500, 51.5), isNull);
  });

  test('moving bodies are still found after a step', () {
    // The tree's AABBs are refreshed during step_physics. A raycast between
    // frames must see the body where the solver left it.
    final id = addCircle(0, 300, 40, type: dynamicBody);
    for (int i = 0; i < 60; i++) {
      physics.update(1 / 60);
    }
    final y = FPhysicsSystem.getBodyPosition(physics.world, id).dy;
    expect(y, lessThan(250), reason: 'the body did not fall; test proves nothing');

    final hit = cast(-500, y, 500, y);
    expect(hit, isNotNull, reason: 'the tree AABB went stale as the body fell');
    expect(hit!.bodyId, id);
  });

  test('a hit normal points back along the ray', () {
    addCircle(0, 0, 50);
    final hit = cast(-500, 0, 500, 0);
    expect(hit, isNotNull);
    expect(hit!.normalX, lessThan(0), reason: 'normal faces away from the ray origin');
  });

  test('many bodies: the ray finds the one it crosses', () {
    // The point of the tree. A column of bodies well off the ray's path must
    // not change the answer.
    for (int i = 0; i < 300; i++) {
      addCircle(-2000 + i * 3.0, 900, 5);
    }
    final target = addCircle(0, 0, 40);
    final hit = cast(-500, 0, 500, 0);
    expect(hit?.bodyId, target);
  });
}
