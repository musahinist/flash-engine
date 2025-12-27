import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/systems/joints.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class SimpleJointsDemo extends StatefulWidget {
  const SimpleJointsDemo({super.key});

  @override
  State<SimpleJointsDemo> createState() => _SimpleJointsDemoState();
}

class _SimpleJointsDemoState extends State<SimpleJointsDemo> {
  // References to bodies
  FlashPhysicsBody? _leftAnchor;
  FlashPhysicsBody? _rightAnchor;
  final Map<int, FlashPhysicsBody> _ropeSegments = {};
  FlashPhysicsBody? _ball;

  FlashPhysicsBody? _pendulumAnchor;
  FlashPhysicsBody? _pendulumBob;

  bool _ropeCreated = false;
  bool _pendulumCreated = false;

  void _checkAndCreateRope() {
    if (_ropeCreated) return;
    if (_leftAnchor == null || _rightAnchor == null || _ball == null) return;
    // We expect 8 segments (0 to 7)
    if (_ropeSegments.length != 8) return;

    print('🔗 Creating Rope Bridge...');

    // Create chain
    FlashPhysicsBody? prevBody = _leftAnchor;

    // Left anchor to first segment
    for (int i = 0; i < 8; i++) {
      final currentBody = _ropeSegments[i]!;
      final joint = FlashDistanceJoint(
        bodyA: prevBody!,
        bodyB: currentBody,
        length: 50,
        frequency: 10,
        dampingRatio: 0.5,
      );
      joint.create(prevBody.world);
      prevBody = currentBody;
    }

    // Last segment to right anchor
    final joint = FlashDistanceJoint(
      bodyA: prevBody!,
      bodyB: _rightAnchor!,
      length: 50,
      frequency: 10,
      dampingRatio: 0.5,
    );
    joint.create(prevBody.world);

    // Connect Ball to middle segment (index 3)
    final ballJoint = FlashDistanceJoint(
      bodyA: _ropeSegments[3]!,
      bodyB: _ball!,
      length: 80,
      frequency: 2,
      dampingRatio: 0.1,
    );
    ballJoint.create(_ball!.world);

    _ropeCreated = true;
    print('✅ Rope Bridge Created!');
  }

  void _checkAndCreatePendulum() {
    if (_pendulumCreated) return;
    if (_pendulumAnchor == null || _pendulumBob == null) return;

    print('🔄 Creating Pendulum...');

    final joint = FlashRevoluteJoint(bodyA: _pendulumAnchor!, bodyB: _pendulumBob!, anchor: v.Vector2(-300, 200));
    joint.create(_pendulumAnchor!.world);

    _pendulumCreated = true;
    print('✅ Pendulum Created!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Joints Demo'), backgroundColor: Colors.black87),
      body: Flash(
        autoUpdate: true,
        child: Stack(
          children: [
            // Camera
            FlashCamera(position: v.Vector3(0, 0, 1000)),

            // Ground
            FlashStaticBody(
              name: 'Ground',
              position: v.Vector3(0, -300, 0),
              width: 800,
              height: 40,
              color: Colors.grey[900]!,
              onCreated: (body) => body.debugDraw = true,
            ),

            // Left anchor for rope
            FlashStaticBody(
              name: 'LeftAnchor',
              position: v.Vector3(-200, 150, 0),
              width: 20,
              height: 20,
              color: Colors.brown,
              onCreated: (body) {
                _leftAnchor = body;
                body.debugDraw = true;
                _checkAndCreateRope();
              },
            ),

            // Right anchor for rope
            FlashStaticBody(
              name: 'RightAnchor',
              position: v.Vector3(200, 150, 0),
              width: 20,
              height: 20,
              color: Colors.brown,
              onCreated: (body) {
                _rightAnchor = body;
                body.debugDraw = true;
                _checkAndCreateRope();
              },
            ),

            // Rope segments - 8 boxes connected with distance joints
            for (int i = 0; i < 8; i++)
              FlashRigidBody.square(
                key: ValueKey('rope_$i'),
                name: 'Rope$i',
                position: v.Vector3(-200 + (i + 1) * 50.0, 150, 0),
                size: 30,
                color: Colors.orange,
                onCreated: (body) {
                  _ropeSegments[i] = body;
                  body.debugDraw = true;
                  _checkAndCreateRope();
                },
              ),

            // Heavy ball in the middle
            FlashRigidBody.circle(
              key: const ValueKey('ball'),
              name: 'Ball',
              position: v.Vector3(0, 100, 0),
              radius: 40,
              color: Colors.red,
              onCreated: (body) {
                _ball = body;
                body.debugDraw = true;
                _checkAndCreateRope();
              },
            ),

            // Pendulum anchor
            FlashStaticBody(
              name: 'PendulumAnchor',
              position: v.Vector3(-300, 200, 0),
              width: 40,
              height: 20,
              color: Colors.grey[800]!,
              onCreated: (body) {
                _pendulumAnchor = body;
                body.debugDraw = true;
                _checkAndCreatePendulum();
              },
            ),

            // Pendulum bob
            FlashRigidBody.circle(
              key: const ValueKey('pendulum'),
              name: 'Pendulum',
              position: v.Vector3(200, 0, 0),
              radius: 25,
              color: Colors.blue,
              onCreated: (body) {
                _pendulumBob = body;
                body.debugDraw = true;
                _checkAndCreatePendulum();
              },
            ),

            // Info HUD
            Positioned(
              left: 20,
              top: 100,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link, color: Colors.cyanAccent),
                        const SizedBox(width: 8),
                        const Text(
                          'SIMPLE JOINTS DEMO',
                          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('🔗', 'Rope Bridge', '8 segments'),
                    _buildInfoRow('⚖️', 'Heavy Ball', 'Gravity test'),
                    _buildInfoRow('🔄', 'Pendulum', 'Revolute joint'),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.cyanAccent, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amberAccent, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Native Physics Rendering',
                          style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
