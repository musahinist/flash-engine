import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Compiles and runs every code sample in README.md.
///
/// The previous README documented fifteen classes that no longer existed — a
/// `Flash` widget, `FlashBox`, `FlashRigidBody`, and a physics example built on
/// Forge2D types (`BodyDef`, `FixtureDef`, `PolygonShape`) that had been
/// removed from the project entirely. Not one line of it compiled. Keeping the
/// samples in a test means that cannot happen quietly again.
void main() {
  testWidgets('Getting started sample', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FScene(
            showDebugOverlay: false,
            scene: [
              FCamera(position: v.Vector3(0, 0, 500), fov: 60),
              FLight(position: v.Vector3(100, 100, 200), intensity: 1.5),
              FBox(position: v.Vector3(0, 0, 0), width: 100, height: 100, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sceneBuilder sample', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FScene(
          showDebugOverlay: false,
          sceneBuilder: (context, elapsed) => [
            FCamera(position: v.Vector3(0, 0, 500)),
            FBox(
              position: v.Vector3(math.cos(elapsed) * 200, 0, 0),
              width: 50,
              height: 50,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('physics sample', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FScene(
          showDebugOverlay: false,
          physicsWorld: FPhysicsSystem(gravity: v.Vector2(0, -980)),
          scene: [
            FStaticBody.square(position: v.Vector3(0, -200, 0), size: 800, color: Colors.grey),
            FRigidBody.circle(position: v.Vector3(0, 200, 0), radius: 20, color: Colors.red),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid sample', (tester) async {
    void paintTile(Canvas canvas, Offset centre, Size cellSize, int x, int y) {}

    await tester.pumpWidget(
      MaterialApp(
        home: FScene(
          showDebugOverlay: false,
          scene: [
            FGridView(
              grid: const FIsometricGrid(cellWidth: 64),
              children: [
                FTileMap(tilePainter: paintTile),
                const FCell(x: 2, y: 3, child: FCube(size: 40, color: Colors.cyan)),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('camera presets named in the README exist', () {
    expect(FCameraNode.isometric(), isA<FCameraNode>());
    expect(FCameraNode.topDown(), isA<FCameraNode>());
  });

  test('light types named in the README exist', () {
    expect(FLightType.values, containsAll([FLightType.point, FLightType.directional, FLightType.ambient]));
  });

  test('particle presets named in the README exist', () {
    expect(ParticleEmitterConfig.fire, isNotNull);
    expect(ParticleEmitterConfig.smoke, isNotNull);
    expect(ParticleEmitterConfig.explosion, isNotNull);
    expect(ParticleEmitterConfig.rain, isNotNull);
    expect(ParticleEmitterConfig.confetti, isNotNull);
  });
}
