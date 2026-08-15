import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';

/// Soft body against rigid body used to test every point of every soft body
/// against every rigid body in the world, recomputing that body's cos/sin
/// inside the point loop. It now takes the soft body's own bounds to the
/// broadphase tree and only tests the bodies that could be touching, with the
/// per-body trig hoisted out of the point loop.
///
/// The failure mode of getting a broadphase wrong is a soft body quietly
/// falling through geometry, so these check contact still happens — including
/// against a body the soft body is only just reaching.
void main() {
  const staticBody = 0;
  const circle = 0;
  const box = 1;

  late FPhysicsSystem physics;

  setUp(() => physics = FPhysicsSystem());
  tearDown(() => physics.dispose());

  /// A ring of [count] points, centred on ([cx], [cy]).
  List<Offset> ring(double cx, double cy, double radius, {int count = 16}) {
    return List.generate(count, (i) {
      final a = i * 2 * math.pi / count;
      return Offset(cx + math.cos(a) * radius, cy + math.sin(a) * radius);
    });
  }

  int addGround(double y) => FPhysicsSystem.createBody(
      physics.world, staticBody, box, 0, y, 2000, 40, 0, 0x0001, 0xFFFF);

  /// Lowest point of the soft body.
  double lowestY(int sbId, int pointCount) {
    var lowest = double.infinity;
    for (int i = 0; i < pointCount; i++) {
      final p = FPhysicsSystem.getSoftBodyPointPos(physics.world, sbId, i);
      if (p.dy < lowest) lowest = p.dy;
    }
    return lowest;
  }

  void step(int frames) {
    for (int i = 0; i < frames; i++) {
      physics.update(1 / 60);
    }
  }

  test('a soft body falls', () {
    // Baseline: without this the resting test below could pass on a body that
    // never moved at all.
    final points = ring(0, 400, 50);
    final sb = FPhysicsSystem.createSoftBody(physics.world, points);
    final before = lowestY(sb, points.length);
    step(30);
    expect(lowestY(sb, points.length), lessThan(before - 10));
  });

  test('a soft body comes to rest on the ground instead of passing through', () {
    addGround(-300);
    final points = ring(0, 200, 50);
    final sb = FPhysicsSystem.createSoftBody(physics.world, points);

    step(240);
    final lowest = lowestY(sb, points.length);

    // Ground surface is at -280. Allow for the soft body's own squash and the
    // 2-unit point radius the contact test adds.
    expect(lowest, greaterThan(-300), reason: 'the soft body fell through the ground');
    expect(lowest, lessThan(-240), reason: 'the soft body never reached the ground');
  });

  test('a soft body rests on a circle too', () {
    // The circle branch of the contact test is separate code from the box one.
    FPhysicsSystem.createBody(
        physics.world, staticBody, circle, 0, -300, 240, 240, 0, 0x0001, 0xFFFF);
    final points = ring(0, 100, 40);
    final sb = FPhysicsSystem.createSoftBody(physics.world, points);

    step(240);
    expect(lowestY(sb, points.length), greaterThan(-260),
        reason: 'the soft body sank into the circle');
  });

  test('distant bodies do not affect the result', () {
    // The whole point of the broadphase: bodies nowhere near the soft body
    // must be skipped, and skipping them must not change the outcome.
    addGround(-300);
    final points = ring(0, 200, 50);
    final sb = FPhysicsSystem.createSoftBody(physics.world, points);
    step(240);
    final withoutCrowd = lowestY(sb, points.length);

    final physics2 = FPhysicsSystem();
    addTearDown(physics2.dispose);
    FPhysicsSystem.createBody(
        physics2.world, staticBody, box, 0, -300, 2000, 40, 0, 0x0001, 0xFFFF);
    for (int i = 0; i < 200; i++) {
      FPhysicsSystem.createBody(
          physics2.world, staticBody, circle, -4000 + i * 5.0, 3000, 20, 20, 0, 0x0001, 0xFFFF);
    }
    final sb2 = FPhysicsSystem.createSoftBody(physics2.world, ring(0, 200, 50));
    for (int i = 0; i < 240; i++) {
      physics2.update(1 / 60);
    }
    var lowest2 = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final p = FPhysicsSystem.getSoftBodyPointPos(physics2.world, sb2, i);
      if (p.dy < lowest2) lowest2 = p.dy;
    }

    expect(lowest2, closeTo(withoutCrowd, 1.0));
  });

  test('a rotated box deflects the soft body along its slope', () {
    // The per-body cos/sin moved out of the point loop, and a rotated body is
    // what catches getting that hoist wrong: with the wrong sign the local
    // transform is a rotation the other way and contact resolves against a
    // surface that is not there.
    //
    // The assertion is deflection, not resting height. A 20-degree incline is
    // a slope — the soft body lands on it, slides down it, and eventually
    // leaves the edge, all of which is correct. What distinguishes contact
    // from falling straight through is that x moves at all.
    FPhysicsSystem.createBody(
        physics.world, staticBody, box, 0, -300, 600, 60, 0.35, 0x0001, 0xFFFF);
    final points = ring(0, 100, 40);
    final sb = FPhysicsSystem.createSoftBody(physics.world, points);

    double centreX() {
      var sum = 0.0;
      for (int i = 0; i < points.length; i++) {
        sum += FPhysicsSystem.getSoftBodyPointPos(physics.world, sb, i).dx;
      }
      return sum / points.length;
    }

    step(60);
    expect(centreX().abs(), lessThan(5), reason: 'it should still be falling straight down');
    final heightOnContact = lowestY(sb, points.length);

    step(100);
    // Landed and slid: downhill in x, and descending far slower than gravity
    // would carry it over the same interval.
    expect(centreX(), lessThan(-100), reason: 'no contact — it fell straight past the box');
    expect(lowestY(sb, points.length), greaterThan(heightOnContact - 150),
        reason: 'it kept free-falling instead of riding the slope');
  });

  test('multiple soft bodies each find the ground', () {
    addGround(-300);
    final a = FPhysicsSystem.createSoftBody(physics.world, ring(-300, 200, 50));
    final b = FPhysicsSystem.createSoftBody(physics.world, ring(300, 200, 50));

    step(240);
    expect(lowestY(a, 16), greaterThan(-300));
    expect(lowestY(b, 16), greaterThan(-300));
  });
}
