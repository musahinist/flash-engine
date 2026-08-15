import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// Box2D-style collision filtering: `categoryBits` and `maskBits`.
///
/// A pair collides only if each side's mask includes the other's category. The
/// green boxes are the telling case — their mask names only themselves, so they
/// fall straight through the ground and through everything else, and stack only
/// on each other.
class CollisionLayersDemoExample extends StatefulWidget {
  const CollisionLayersDemoExample({super.key});

  @override
  State<CollisionLayersDemoExample> createState() => _CollisionLayersDemoExampleState();
}

class _CollisionLayersDemoExampleState extends State<CollisionLayersDemoExample> {
  static const int _ground = 0x0001;
  static const int _blue = 0x0002;
  static const int _red = 0x0004;
  static const int _green = 0x0008;

  int _resetKey = 0;

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Collision Layers',
      subtitle: 'categoryBits says what a body is; maskBits says what it hits.',
      controls: [
        DemoButton(
          label: 'Drop again',
          icon: Icons.replay_rounded,
          onPressed: () => setState(() => _resetKey++),
        ),
        DemoPanel(
          title: 'Layers',
          children: [
            DemoLegend(
              entries: const [
                (color: Colors.white24, label: 'ground — hits everything'),
                (color: DemoTheme.accent, label: 'blue — ground + blue'),
                (color: DemoTheme.danger, label: 'red — ground + red'),
                (color: DemoTheme.positive, label: 'green — green only'),
              ],
            ),
          ],
        ),
      ],
      hint: 'Green falls through the floor: its mask does not include the ground.',
      scene: FScene(
        key: ValueKey(_resetKey),
        scene: [
          FCamera(position: v.Vector3(0, 0, 1000), fov: 60),
          FPhysicsWorld(gravity: FPhysics.standardGravity),

          FStaticBody(
            name: 'Ground',
            position: v.Vector3(0, -350, 0),
            width: 800,
            height: 40,
            categoryBits: _ground,
            maskBits: 0xFFFF,
            child: const FBox(width: 800, height: 40, color: Colors.white24),
          ),

          // Blue: hits the ground and other blue. Red passes through it.
          for (int i = 0; i < 20; i++)
            FRigidBody.square(
              key: ValueKey('blue_$i'),
              name: 'BlueBox',
              position: v.Vector3(-150 + (i * 20), 400 + (i * 60), 0),
              size: 30,
              categoryBits: _blue,
              maskBits: _ground | _blue,
              child: const FBox(width: 30, height: 30, color: DemoTheme.accent),
            ),

          // Red: hits the ground and other red. Blue passes through it.
          for (int i = 0; i < 20; i++)
            FRigidBody.square(
              key: ValueKey('red_$i'),
              name: 'RedBox',
              position: v.Vector3(150 - (i * 20), 400 + (i * 60), 0),
              size: 30,
              categoryBits: _red,
              maskBits: _ground | _red,
              child: const FBox(width: 30, height: 30, color: DemoTheme.danger),
            ),

          // Green: hits only green, so the floor is not there as far as it is
          // concerned.
          for (int i = 0; i < 10; i++)
            FRigidBody.square(
              key: ValueKey('green_$i'),
              name: 'GreenBox',
              position: v.Vector3(-50 + (i * 10), 600 + (i * 60), 0),
              size: 30,
              categoryBits: _green,
              maskBits: _green,
              child: const FBox(width: 30, height: 30, color: DemoTheme.positive),
            ),
        ],
      ),
    );
  }
}
