import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:forge2d/forge2d.dart'; // Import forge2d for Physics definitions

class AudioDemo extends StatefulWidget {
  const AudioDemo({super.key});

  @override
  State<AudioDemo> createState() => _AudioDemoState();
}

class _AudioDemoState extends State<AudioDemo> {
  late final FlashPhysicsSystem _physicsWorld;

  @override
  void initState() {
    super.initState();
    // Standard gravity (m/s^2), pointing down
    _physicsWorld = FlashPhysicsSystem(gravity: v.Vector2(0, -9.81));
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Physics Audio Collision'), backgroundColor: Colors.transparent),
      body: Flash(
        physicsWorld: _physicsWorld,
        autoUpdate: true,
        child: Stack(
          children: [
            FlashCamera(position: v.Vector3(0, 0, 800), fov: 60),

            // Floor
            FlashRigidBody(
              position: v.Vector3(0, -200, 0),
              bodyDef: BodyDef()..type = BodyType.static,
              fixtures: [FixtureDef(PolygonShape()..setAsBoxXY(400, 10))..friction = 0.0],
              child: FlashBox(name: 'Floor', width: 800, height: 20, color: Colors.grey),
            ),

            // Left Wall
            FlashRigidBody(
              position: v.Vector3(-400, 0, 0),
              bodyDef: BodyDef()..type = BodyType.static,
              fixtures: [FixtureDef(PolygonShape()..setAsBoxXY(10, 200))..restitution = 1.0],
              child: FlashBox(name: 'LeftWall', width: 20, height: 400, color: Colors.grey),
            ),

            // Right Wall
            FlashRigidBody(
              position: v.Vector3(400, 0, 0),
              bodyDef: BodyDef()..type = BodyType.static,
              fixtures: [FixtureDef(PolygonShape()..setAsBoxXY(10, 200))..restitution = 1.0],
              child: FlashBox(name: 'RightWall', width: 20, height: 400, color: Colors.grey),
            ),

            // Slider A (Moving Right)
            _buildSliderBox(position: v.Vector3(-200, -170, 0), velocity: v.Vector2(300, 0), color: Colors.cyanAccent),

            // Slider B (Moving Left)
            _buildSliderBox(position: v.Vector3(200, -170, 0), velocity: v.Vector2(-300, 0), color: Colors.pinkAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderBox({required v.Vector3 position, required v.Vector2 velocity, required Color color}) {
    final controller = FlashAudioController();
    Body? bodyRef;
    int lastPlayTime = 0;
    const int cooldownMs = 200; // Prevent spamming sounds (max 5 per second)

    return FlashRigidBody(
      position: position,
      bodyDef: BodyDef()
        ..type = BodyType.dynamic
        ..linearVelocity = velocity
        ..fixedRotation =
            true // prevent tumbling
        ..linearDamping =
            0.0 // no air resistance
        ..angularDamping = 0.0,
      fixtures: [
        FixtureDef(PolygonShape()..setAsBoxXY(20, 20))
          ..density = 1.0
          ..restitution =
              1.0 // Perfectly elastic bounce
          ..friction = 0.0, // No friction logic on floor
      ],
      onCollision: (contact) {
        if (bodyRef != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastPlayTime < cooldownMs) return;

          // Play sound on impact
          // For elastic collision, velocity direction changes but magnitude stays similar.
          // Just verify we hit something
          controller.play();
          lastPlayTime = now;
        }
      },
      onUpdate: (body) {
        bodyRef = body;
      },
      child: Stack(
        children: [
          FlashBox(width: 40, height: 40, color: color),
          FlashAudioPlayer(
            assetPath: 'asset/demo.mp3',
            controller: controller,
            autoplay: false,
            is3D: false, // Temporarily disable 3D to rule out distance issues
            // minDistance: 50,
            // maxDistance: 1000,
          ),
        ],
      ),
    );
  }
}
