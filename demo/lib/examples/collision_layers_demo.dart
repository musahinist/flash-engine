import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:forge2d/forge2d.dart' as f2d;

class CollisionLayersDemoExample extends StatefulWidget {
  const CollisionLayersDemoExample({super.key});

  @override
  State<CollisionLayersDemoExample> createState() => _CollisionLayersDemoExampleState();
}

class _CollisionLayersDemoExampleState extends State<CollisionLayersDemoExample> {
  // Define layers for clarity
  static const int floorLayer = FlashCollisionLayer.layer1;
  static const int blueLayer = FlashCollisionLayer.layer2;
  static const int redLayer = FlashCollisionLayer.layer3;
  static const int ghostLayer = FlashCollisionLayer.layer4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(title: const Text('Collision Layers Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Flash(
        child: Stack(
          children: [
            // Camera
            FlashCameraWidget(position: v.Vector3(0, 0, 500), fov: 60),

            // Physics World
            FlashPhysicsWorldWidget(gravity: v.Vector2(0, -9.81)),

            // Static Floor (Collides with everything except Ghosts)
            FlashRigidBody(
              name: 'Floor',
              position: v.Vector3(0, -200, 0),
              category: floorLayer,
              mask: floorLayer | blueLayer | redLayer, // Collides with floor components, blue and red. No Ghost.
              bodyDef: f2d.BodyDef()..type = f2d.BodyType.static,
              fixtures: [
                f2d.FixtureDef(f2d.PolygonShape()..setAsBox(300, 20, v.Vector2.zero(), 0))
                  ..friction = 0.5
                  ..restitution = 0.2,
              ],
              child: FlashBox(width: 600, height: 40, color: Colors.grey.shade800),
            ),

            // BLUE BOXES (Collide with Floor and Blue, but pass through Red)
            for (int i = 0; i < 3; i++)
              FlashRigidBody(
                name: 'BlueBox$i',
                position: v.Vector3(-100.0 + i * 20, 200.0 + i * 100, 0),
                category: blueLayer,
                mask: floorLayer | blueLayer, // No redLayer mask!
                fixtures: [
                  f2d.FixtureDef(f2d.PolygonShape()..setAsBox(20, 20, v.Vector2.zero(), 0))
                    ..density = 1.0
                    ..restitution = 0.5,
                ],
                child: FlashBox(width: 40, height: 40, color: Colors.blueAccent),
              ),

            // RED BOXES (Collide with Floor and Red, but pass through Blue)
            for (int i = 0; i < 3; i++)
              FlashRigidBody(
                name: 'RedBox$i',
                position: v.Vector3(100.0 - i * 20, 250.0 + i * 100, 0),
                category: redLayer,
                mask: floorLayer | redLayer, // No blueLayer mask!
                fixtures: [
                  f2d.FixtureDef(f2d.PolygonShape()..setAsBox(20, 20, v.Vector2.zero(), 0))
                    ..density = 1.0
                    ..restitution = 0.5,
                ],
                child: FlashBox(width: 40, height: 40, color: Colors.redAccent),
              ),

            // GHOST BOXES (Pass through everything, even the floor)
            for (int i = 0; i < 2; i++)
              FlashRigidBody(
                name: 'GhostBox$i',
                position: v.Vector3(0, 300.0 + i * 150, 0),
                category: ghostLayer,
                mask: FlashCollisionLayer.none, // Collides with nothing
                fixtures: [f2d.FixtureDef(f2d.PolygonShape()..setAsBox(15, 15, v.Vector2.zero(), 0))..density = 0.5],
                child: FlashBox(width: 30, height: 30, color: Colors.white.withValues(alpha: 0.3)),
              ),

            // UI Overlay
            Positioned(
              left: 20,
              bottom: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legend('BLUE', 'Collides with Floor & Blue', Colors.blueAccent),
                  _legend('RED', 'Collides with Floor & Red', Colors.redAccent),
                  _legend('GHOST', 'Passes through everything', Colors.white54),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {}), // Reset/Refresh
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _legend(String label, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
