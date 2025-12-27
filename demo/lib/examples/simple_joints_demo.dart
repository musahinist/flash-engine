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

  // Notifier to trigger repaints of the custom painter on every engine tick
  final ValueNotifier<int> _tickNotifier = ValueNotifier(0);

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
        autoUpdate: false, // Fix: Prevent full widget tree rebuild (flickering)
        onUpdate: () {
          // Sync custom painter with engine tick
          _tickNotifier.value++;
        },
        child: Stack(
          children: [
            // Camera
            FlashCamera(position: v.Vector3(0, 0, 1000)),

            // --- Joint Visualization Overlay ---
            // Draws lines for ropes and pendulums so they look interconnected
            Positioned.fill(
              child: CustomPaint(
                painter: _JointPainter(
                  repaint: _tickNotifier, // Repaint every frame
                  leftAnchor: _leftAnchor,
                  rightAnchor: _rightAnchor,
                  ropeSegments: _ropeSegments,
                  ball: _ball,
                  pendulumAnchor: _pendulumAnchor,
                  pendulumBob: _pendulumBob,
                ),
              ),
            ),

            // Ground
            FlashStaticBody(
              name: 'Ground',
              position: v.Vector3(0, -350, 0),
              width: 1000,
              height: 40,
              color: Colors.grey[900]!,
              debugDraw: true,
            ),

            // --- Rope Bridge Setup ---
            // Left Anchor
            FlashStaticBody(
              name: 'LeftAnchor',
              position: v.Vector3(-200, 100, 0),
              width: 20,
              height: 20,
              color: Colors.brown,
              debugDraw: true,
              onCreated: (body) {
                _leftAnchor = body;
                _checkAndCreateRope();
              },
            ),

            // Right Anchor
            FlashStaticBody(
              name: 'RightAnchor',
              position: v.Vector3(200, 100, 0),
              width: 20,
              height: 20,
              color: Colors.brown,
              debugDraw: true,
              onCreated: (body) {
                _rightAnchor = body;
                _checkAndCreateRope();
              },
            ),

            // Rope Segments (8 segments)
            for (int i = 0; i < 8; i++)
              FlashRigidBody.square(
                key: ValueKey('rope_$i'),
                name: 'RopeSeg_$i',
                position: v.Vector3(-150.0 + (i * 40), 100, 0),
                size: 20,
                color: Colors.orange,
                debugDraw: true,
                onCreated: (body) {
                  _ropeSegments[i] = body;
                  _checkAndCreateRope();
                },
              ),

            // Ball attached to rope
            FlashRigidBody.circle(
              name: 'HeavyBall',
              position: v.Vector3(0, 50, 0),
              radius: 20,
              color: Colors.red,
              debugDraw: true,
              onCreated: (body) {
                _ball = body;
                _checkAndCreateRope();
              },
            ),

            // --- Pendulum Setup ---
            FlashStaticBody(
              name: 'PendulumAnchor',
              position: v.Vector3(-300, 200, 0),
              width: 20,
              height: 20,
              color: Colors.grey,
              debugDraw: true,
              onCreated: (body) {
                _pendulumAnchor = body;
                _checkAndCreatePendulum();
              },
            ),

            FlashRigidBody.circle(
              name: 'PendulumBob',
              position: v.Vector3(-200, 200, 0), // Start horizontally
              radius: 15,
              color: Colors.blueAccent,
              debugDraw: true,
              onCreated: (body) {
                _pendulumBob = body;
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

class _JointPainter extends CustomPainter {
  final FlashPhysicsBody? leftAnchor;
  final FlashPhysicsBody? rightAnchor;
  final Map<int, FlashPhysicsBody> ropeSegments;
  final FlashPhysicsBody? ball;
  final FlashPhysicsBody? pendulumAnchor;
  final FlashPhysicsBody? pendulumBob;

  _JointPainter({
    required Listenable repaint,
    required this.leftAnchor,
    required this.rightAnchor,
    required this.ropeSegments,
    required this.ball,
    required this.pendulumAnchor,
    required this.pendulumBob,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Camera Transform Helper:
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    Offset toScreen(v.Vector3 pos) {
      // Y-Flip because Physics is Y-Up, Screen is Y-Down
      return Offset(centerX + pos.x, centerY - pos.y);
    }

    // Draw Rope
    if (leftAnchor != null && ropeSegments.containsKey(0)) {
      canvas.drawLine(toScreen(leftAnchor!.transform.position), toScreen(ropeSegments[0]!.transform.position), paint);
    }

    for (int i = 0; i < 7; i++) {
      if (ropeSegments.containsKey(i) && ropeSegments.containsKey(i + 1)) {
        canvas.drawLine(
          toScreen(ropeSegments[i]!.transform.position),
          toScreen(ropeSegments[i + 1]!.transform.position),
          paint,
        );
      }
    }

    if (rightAnchor != null && ropeSegments.containsKey(7)) {
      canvas.drawLine(toScreen(ropeSegments[7]!.transform.position), toScreen(rightAnchor!.transform.position), paint);
    }

    // Draw Ball Connection (to segment 3)
    if (ball != null && ropeSegments.containsKey(3)) {
      canvas.drawLine(toScreen(ropeSegments[3]!.transform.position), toScreen(ball!.transform.position), paint);
    }

    // Draw Pendulum
    if (pendulumAnchor != null && pendulumBob != null) {
      canvas.drawLine(toScreen(pendulumAnchor!.transform.position), toScreen(pendulumBob!.transform.position), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _JointPainter oldDelegate) => true;
}
