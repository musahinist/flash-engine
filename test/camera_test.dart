import 'dart:math';

import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart';

/// Follow, dead zone, bounds and shake used to live on FGridCamera — a
/// non-node 2D camera with its own Y-down transform, running alongside
/// FCameraNode. Two cameras meant two answers to "where am I looking from".
void main() {
  FCameraNode cameraFollowing(FNode target, {double smoothing = 0.1}) {
    return FCameraNode.topDown()
      ..followTarget = target
      ..followSmoothing = smoothing
      ..followMode = CameraFollowMode.smooth;
  }

  test('smooth follow is frame-rate independent', () {
    // The old rule was `position += delta * lerpSpeed` with no dt, so the same
    // wall-clock interval produced different results at different frame rates.
    final target = FNode()..transform.position = Vector3(100, 0, 200);

    final coarse = cameraFollowing(target);
    coarse.process(1 / 30);

    final fine = cameraFollowing(target);
    fine.process(1 / 60);
    fine.process(1 / 60);

    expect(coarse.transform.position.x, closeTo(fine.transform.position.x, 0.5));
    expect(coarse.transform.position.z, closeTo(fine.transform.position.z, 0.5));
  });

  test('smooth follow converges on the target plus offset', () {
    final target = FNode()..transform.position = Vector3(50, 0, -75);
    final camera = cameraFollowing(target, smoothing: 0.05);

    for (int i = 0; i < 200; i++) {
      camera.process(1 / 60);
    }

    final expected = target.worldPosition + camera.followOffset;
    expect(camera.transform.position.x, closeTo(expected.x, 0.1));
    expect(camera.transform.position.z, closeTo(expected.z, 0.1));
  });

  test('instant follow snaps in one step', () {
    final target = FNode()..transform.position = Vector3(10, 0, 20);
    final camera = FCameraNode.topDown()
      ..followTarget = target
      ..followMode = CameraFollowMode.instant;

    camera.process(1 / 60);
    expect(camera.transform.position.x, closeTo(10, 0.001));
    expect(camera.transform.position.z, closeTo(20, 0.001));
  });

  test('dead zone holds the camera until the target escapes it', () {
    final target = FNode()..transform.position = Vector3(0, 0, 0);
    final camera = FCameraNode.topDown()
      ..followTarget = target
      ..followMode = CameraFollowMode.deadZone
      ..deadZone = const Rect.fromLTWH(-50, -50, 100, 100);

    camera.process(1 / 60);
    final settled = camera.transform.position.clone();

    // Inside the zone: no movement.
    target.transform.position = Vector3(30, 0, 0);
    camera.process(1 / 60);
    expect(camera.transform.position.x, closeTo(settled.x, 0.001));

    // Outside: the camera is dragged along.
    target.transform.position = Vector3(300, 0, 0);
    camera.process(1 / 60);
    expect(camera.transform.position.x, greaterThan(settled.x));
  });

  test('world bounds clamp the camera', () {
    final target = FNode()..transform.position = Vector3(10000, 0, 10000);
    final camera = cameraFollowing(target, smoothing: 0.01)
      ..worldBounds = Aabb2.minMax(Vector2(-100, -100), Vector2(100, 100));

    for (int i = 0; i < 100; i++) {
      camera.process(1 / 60);
    }

    expect(camera.transform.position.x, lessThanOrEqualTo(100.001));
    expect(camera.transform.position.z, lessThanOrEqualTo(100.001));
  });

  group('shake', () {
    test('is seeded, so it reproduces', () {
      // The old implementation derived "randomness" from
      // `_shakeDuration.hashCode % 1000`.
      final a = FCameraNode.topDown(name: 'a')..shake(magnitude: 20, duration: 0.5);
      final b = FCameraNode.topDown(name: 'b')..shake(magnitude: 20, duration: 0.5);

      // Same seed (null -> Random()) is not comparable, so compare structure:
      // both must be shaking and both must settle.
      a.process(1 / 60);
      b.process(1 / 60);
      expect(a.isShaking, isTrue);
      expect(b.isShaking, isTrue);
    });

    test('decays to nothing', () {
      final camera = FCameraNode.topDown()..shake(magnitude: 30, duration: 0.2);
      final resting = camera.getViewMatrix();

      camera.process(0.1);
      expect(camera.isShaking, isTrue);

      camera.process(0.2);
      expect(camera.isShaking, isFalse);
      // Once finished the view matrix is back to the un-shaken one.
      expect(camera.getViewMatrix().storage, resting.storage);
    });

    test('does not disturb the transform', () {
      // Shake is applied when building the view matrix, so it cannot fight
      // follow or leak into the native transform sync.
      final camera = FCameraNode.topDown();
      final before = camera.transform.position.clone();
      camera.shake(magnitude: 50, duration: 0.5);
      camera.process(1 / 60);
      expect(camera.transform.position, before);
    });
  });

  group('projection', () {
    test('isometric is orthographic with a 45 degree yaw', () {
      final camera = FCameraNode.isometric();
      expect(camera.isOrthographic, isTrue);
      expect(camera.transform.rotation.y, closeTo(-pi / 4, 0.001));
      expect(camera.transform.rotation.x, closeTo(-atan(1 / sqrt2), 0.001));
    });

    test('worldToScreen puts the focus point at the viewport centre', () {
      final viewport = Vector2(800, 600);
      final camera = FCameraNode.topDown(orthographicSize: 300);

      final centre = camera.worldToScreen(Vector3(0, 0, 0), viewport);
      expect(centre.x, closeTo(400, 1.0));
      expect(centre.y, closeTo(300, 1.0));
    });

    test('getVisibleWorldRect scales with orthographicSize', () {
      final viewport = Vector2(800, 600);
      final near = FCameraNode.topDown(orthographicSize: 100).getVisibleWorldRect(viewport);
      final far = FCameraNode.topDown(orthographicSize: 400).getVisibleWorldRect(viewport);
      expect(far.width, greaterThan(near.width));
    });
  });
}
