import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Frustum culling was rewritten to be allocation-free: instead of building a
/// Matrix4, a List and eight Vector4s per bounded node per frame, it multiplies
/// in place and ANDs six-bit outcodes, bailing out as soon as the intersection
/// empties.
///
/// The behaviour must be identical: a node is culled only when all four corners
/// of its bounds fall outside the *same* clip plane.
void main() {
  late FEngine engine;

  setUp(() {
    engine = FEngine();
    engine.viewportSize.setValues(800, 600);
  });
  tearDown(() => engine.dispose());

  /// Adds a camera looking down -Z from z = 500, the engine's default pose.
  FCameraNode addCamera() {
    final camera = FCameraNode(name: 'cam');
    engine.scene.addChild(camera);
    engine.registerCamera(camera);
    return camera;
  }

  FBoxNodeStub addBox(double x, double y, {double z = 0, double size = 50}) {
    final node = FBoxNodeStub(size: size)..transform.position = v.Vector3(x, y, z);
    engine.scene.addChild(node);
    return node;
  }

  bool rendered(FNode node) => engine.renderNodes.contains(node);

  test('a node at the origin is visible', () {
    addCamera();
    final node = addBox(0, 0);
    engine.debugTick(1 / 60);
    expect(rendered(node), isTrue);
  });

  test('a node far off to the side is culled', () {
    addCamera();
    final node = addBox(100000, 0);
    engine.debugTick(1 / 60);
    expect(rendered(node), isFalse);
  });

  test('a node far above is culled', () {
    addCamera();
    final node = addBox(0, 100000);
    engine.debugTick(1 / 60);
    expect(rendered(node), isFalse);
  });

  test('a node behind the camera is culled', () {
    addCamera();
    final node = addBox(0, 0, z: 5000);
    engine.debugTick(1 / 60);
    expect(rendered(node), isFalse);
  });

  test('a node straddling the edge is kept', () {
    // Partially visible must not be culled: all four corners have to fail the
    // *same* plane. This is the case an over-eager early exit would break.
    final camera = addCamera();
    engine.debugTick(1 / 60); // activeCamera is only chosen during a tick
    final halfWidth = camera.getWorldBounds(500, v.Vector2(800, 600)).x;
    final node = addBox(halfWidth, 0, size: 400);
    engine.debugTick(1 / 60);
    expect(rendered(node), isTrue);
  });

  test('a node without bounds is never culled', () {
    addCamera();
    final node = FNode(name: 'unbounded')..transform.position = v.Vector3(100000, 100000, 0);
    engine.scene.addChild(node);
    engine.debugTick(1 / 60);
    expect(rendered(node), isTrue);
  });

  test('culling follows the camera', () {
    final camera = addCamera();
    final node = addBox(3000, 0);
    engine.debugTick(1 / 60);
    expect(rendered(node), isFalse, reason: 'should start off screen');

    camera.transform.position = v.Vector3(3000, 0, 500);
    engine.debugTick(1 / 60);
    expect(rendered(node), isTrue, reason: 'camera moved onto it');
  });
}

/// A minimal bounded node — FBox drags in the widget layer.
class FBoxNodeStub extends FNode {
  FBoxNodeStub({required this.size}) : super(name: 'boxStub');

  final double size;

  @override
  Rect? get bounds => Rect.fromCenter(center: Offset.zero, width: size, height: size);
}
