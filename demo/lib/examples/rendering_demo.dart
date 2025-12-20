import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:forge2d/forge2d.dart' as f2d;
import 'dart:math';

class RenderingDemoExample extends StatefulWidget {
  const RenderingDemoExample({super.key});

  @override
  State<RenderingDemoExample> createState() => _RenderingDemoExampleState();
}

class _RenderingDemoExampleState extends State<RenderingDemoExample> {
  final List<v.Vector3> _pathPoints = [];
  double _time = 0;
  late final FlashPhysicsSystem _physicsWorld;

  @override
  void initState() {
    super.initState();
    _physicsWorld = FlashPhysicsSystem(gravity: v.Vector2(0, -9.81));
    _generateWavyPath();
  }

  void _generateWavyPath() {
    for (int i = 0; i < 30; i++) {
      final x = (i - 15) * 20.0;
      final y = sin(i * 0.3) * 50.0;
      _pathPoints.add(v.Vector3(x, y, 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(title: const Text('Renderers Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Flash(
        physicsWorld: _physicsWorld,
        onUpdate: () {
          setState(() {
            _time += 1 / 60.0;
          });
        },
        child: Stack(
          children: [
            // Camera (Optimized for mobile visibility)
            FlashCamera(position: v.Vector3(0, 0, 1200), fov: 60, far: 5000),

            // No need for FlashPhysicsSystem, passed directly to Flash

            // 1. LINE RENDERER: Static Wavy Path (Now with Collision!)
            FlashRigidBody(
              name: 'WavyFloor',
              position: v.Vector3(0, -150, 0),
              bodyDef: f2d.BodyDef()..type = f2d.BodyType.static,
              fixtures: [
                f2d.FixtureDef(f2d.ChainShape()..createChain(_pathPoints.map((p) => f2d.Vector2(p.x, p.y)).toList()))
                  ..restitution = 1.0,
              ],
              child: FlashLineRenderer(
                name: 'WavyPath',
                points: _pathPoints,
                width: 15,
                glow: true,
                gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.cyanAccent, Colors.purpleAccent]),
              ),
            ),

            // 2. LINE RENDERER: Animated Circle (Orbit)
            FlashNodeGroup(
              position: v.Vector3(0, 150, 0),
              rotation: v.Vector3(0, 0, _time * 2), // Faster rotation
              child: FlashLineRenderer(
                name: 'CirclePath',
                points: _generateCirclePoints(100, 32),
                isLoop: true,
                width: 10, // Increased width
                color: Colors.white24,
              ),
            ),

            // 3. TRAIL RENDERER: Bouncing Physics Ball
            FlashRigidBody(
              name: 'TrailBall',
              position: v.Vector3(0, 300, 0),
              bodyDef: f2d.BodyDef()
                ..type = f2d.BodyType.dynamic
                ..bullet =
                    true // Prevent tunneling
                ..linearVelocity = f2d.Vector2(50, -100), // Slow fall to waves
              fixtures: [
                f2d.FixtureDef(f2d.CircleShape()..radius = 25) // Slightly larger
                  ..density = 1.0
                  ..restitution =
                      1.0 // Maximum bounce
                  ..friction = 0.0,
              ],
              child: FlashNodes(
                children: [
                  FlashCircle(radius: 25, color: Colors.orangeAccent),
                  const FlashTrailRenderer(
                    lifetime: 1.2, // Longer trail
                    startWidth: 20,
                    endWidth: 0,
                    startColor: Colors.orangeAccent,
                    endColor: Colors.transparent,
                  ),
                ],
              ),
            ),

            // 4. OLD FLOOR REMOVED (The wavy line is the floor now)

            // 5. SIDE WALLS (Brought closer for mobile screens)
            Builder(
              builder: (context) {
                final engine = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>()?.engine;
                if (engine == null) return const SizedBox.shrink();

                return ListenableBuilder(
                  listenable: engine,
                  builder: (context, _) {
                    final camera = engine.activeCamera;
                    if (camera == null) return const SizedBox.shrink();

                    final bounds = camera.getWorldBounds(camera.transform.position.z.abs(), engine.viewportSize);
                    final wallX = bounds.x; // Exact edge

                    return FlashNodes(
                      children: [
                        FlashRigidBody(
                          name: 'LeftWall',
                          position: v.Vector3(-wallX - 10, 0, 0),
                          bodyDef: f2d.BodyDef()..type = f2d.BodyType.static,
                          fixtures: [
                            f2d.FixtureDef(f2d.PolygonShape()..setAsBox(20, 1000, f2d.Vector2.zero(), 0))
                              ..restitution = 1.0,
                          ],
                          child: FlashBox(width: 40, height: 2000, color: Colors.cyanAccent.withValues(alpha: 0.3)),
                        ),
                        FlashRigidBody(
                          name: 'RightWall',
                          position: v.Vector3(wallX + 10, 0, 0),
                          bodyDef: f2d.BodyDef()..type = f2d.BodyType.static,
                          fixtures: [
                            f2d.FixtureDef(f2d.PolygonShape()..setAsBox(20, 1000, f2d.Vector2.zero(), 0))
                              ..restitution = 1.0,
                          ],
                          child: FlashBox(width: 40, height: 2000, color: Colors.cyanAccent.withValues(alpha: 0.3)),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            // Legend
            Positioned(
              left: 20,
              bottom: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _debugInfo('LineRenderer:', 'Static path with glow & gradient', Colors.cyanAccent),
                  _debugInfo('TrailRenderer:', 'Dynamic movement trail on physics body', Colors.orangeAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<v.Vector3> _generateCirclePoints(double radius, int segments) {
    return List.generate(segments, (i) {
      final angle = (i / segments) * pi * 2;
      return v.Vector3(cos(angle) * radius, sin(angle) * radius, 0);
    });
  }

  Widget _debugInfo(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
