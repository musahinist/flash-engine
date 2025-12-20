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
  late final FlashPhysicsWorld _physicsWorld;

  @override
  void initState() {
    super.initState();
    // Gravity pointing down (-Y)
    _physicsWorld = FlashPhysicsWorld(gravity: v.Vector2(0, -50.0));
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
        child: Stack(
          children: [
            // Floor (Static)
            FlashRigidBody(
              bodyDef: BodyDef()
                ..type = BodyType.static
                ..position = Vector2(0, -100),
              fixtures: [
                FixtureDef(PolygonShape()..setAsBoxXY(200, 10))
                  ..restitution =
                      0.5 // Bouncy
                  ..friction = 0.3,
              ],
              child: FlashBox(name: 'Floor', scale: v.Vector3(400, 20, 50), color: Colors.blueGrey),
            ),

            // Falling Boxes
            _buildFallingBox(v.Vector3(0, 100, 0), Colors.redAccent),
            _buildFallingBox(v.Vector3(50, 150, 0), Colors.amberAccent),
            _buildFallingBox(v.Vector3(-50, 200, 0), Colors.cyanAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildFallingBox(v.Vector3 position, Color color) {
    final controller = FlashAudioController();
    Body? bodyRef;

    return FlashRigidBody(
      position: position,
      bodyDef: BodyDef()
        ..type = BodyType.dynamic
        ..linearDamping = 1.0
        ..angularDamping = 1.0
        ..position = Vector2(position.x, position.y),
      fixtures: [
        FixtureDef(PolygonShape()..setAsBoxXY(10, 10))
          ..density = 1.0
          ..restitution = 0.8
          ..friction = 0.4,
      ],
      onCollision: (contact) {
        // Only play if the body is moving fast enough (impact)
        // This prevents sound when resting or sliding slowly
        if (bodyRef != null && bodyRef!.linearVelocity.length > 2.0) {
          controller.play();
        }
      },
      onUpdate: (body) {
        bodyRef = body;
        // Stop audio if body is effectively stationary
        if (body.linearVelocity.length < 1.0) {
          controller.stop();
        }
      },
      child: Stack(
        children: [
          FlashBox(scale: v.Vector3(20, 20, 20), color: color),
          FlashAudioPlayer(
            assetPath: 'asset/demo.mp3',
            controller: controller,
            autoplay: false,
            is3D: true,
            minDistance: 50,
            maxDistance: 1000,
          ),
        ],
      ),
    );
  }
}
