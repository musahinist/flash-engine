import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:forge2d/forge2d.dart' as f2d;

class GodotDemo extends StatefulWidget {
  const GodotDemo({super.key});

  @override
  State<GodotDemo> createState() => _GodotDemoState();
}

class _GodotDemoState extends State<GodotDemo> {
  ui.Image? _spriteImage;
  late final FlashPhysicsWorld _physicsWorld;

  @override
  void initState() {
    super.initState();
    _physicsWorld = FlashPhysicsWorld(gravity: v.Vector2(0, -500.0));
    _loadSprite();
  }

  Future<void> _loadSprite() async {
    // Generate a simple circular gradient sprite in memory
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 128, 128));

    final paint = Paint()
      ..shader = ui.Gradient.radial(const Offset(64, 64), 64, [Colors.blueAccent, Colors.blue.withValues(alpha: 0)]);

    canvas.drawCircle(const Offset(64, 64), 64, paint);

    // Add a "core" to the sprite
    canvas.drawCircle(const Offset(64, 64), 20, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final img = await picture.toImage(128, 128);

    setState(() {
      _spriteImage = img;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_spriteImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Godot-like Components Demo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Flash(
        physicsWorld: _physicsWorld,
        child: Stack(
          children: [
            // Static Floor
            FlashStaticBody(
              position: v.Vector3(0, -300, 0),
              fixtures: [f2d.FixtureDef(f2d.PolygonShape()..setAsBox(400, 20, f2d.Vector2.zero(), 0))],
              child: const FlashBox(width: 800, height: 40, color: Colors.white24),
            ),

            // Rigid Bodies (Falling Sprites)
            for (int i = 0; i < 5; i++)
              FlashRigidBody(
                position: v.Vector3(-200.0 + i * 100.0, 400.0 + i * 50.0, 0),
                fixtures: [
                  f2d.FixtureDef(f2d.CircleShape()..radius = 30)
                    ..restitution = 0.6
                    ..friction = 0.3,
                ],
                child: FlashSprite(image: _spriteImage!, width: 60, height: 60),
              ),

            // World Space Label
            FlashLabel(
              text: 'PHYSICS WORLD',
              position: v.Vector3(0, 500, 0),
              style: TextStyle(
                color: Colors.cyanAccent.withValues(alpha: 0.8),
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),

            // Interactive Label
            FlashLabel(
              text: 'Declarative Nodes',
              position: v.Vector3(0, -350, 0),
              style: const TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
