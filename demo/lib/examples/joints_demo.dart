import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math' as math;

class JointsDemoExample extends StatefulWidget {
  const JointsDemoExample({super.key});

  @override
  State<JointsDemoExample> createState() => _JointsDemoExampleState();
}

class _Spark {
  final int id;
  final v.Vector3 position;
  _Spark(this.id, this.position);
}

class _JointsDemoExampleState extends State<JointsDemoExample> {
  final List<_Spark> _sparks = [];
  int _nextSparkId = 0;
  static const double _cameraSize = 600.0; // Half-height

  void _spawnSpark(v.Vector3 pos) {
    setState(() {
      _sparks.add(_Spark(_nextSparkId++, pos));
      if (_sparks.length > 20) _sparks.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: FScene(
        showDebugOverlay: false,
        onInit: (engine, viewport) {
          // One-time setup if needed
        },
        scene: [
          // Cyberpunk Background Elements
          const _NeonGrid(),

          // Orthographic Camera using our unified scale
          FCamera(position: v.Vector3(0, 0, 1000), isOrthographic: true, orthographicSize: _cameraSize),

          // --- THE NEON KINETIC SCULPTURE ---

          // 1. THE CORE HUB (Motorized) - Centered at (0, 0)
          FStaticBody(
            name: 'CorePivot',
            position: v.Vector3(0, 0, 0),
            width: 40,
            height: 40,
            child: const _GlowNode(color: Colors.cyan, radius: 20),
          ),

          FRigidBody.square(
            name: 'CentralGear',
            position: v.Vector3(0, 0, 0),
            size: 100,
            child: const _NeonGear(color: Colors.cyanAccent),
          ),

          FRevoluteJoint(
            nodeA: 'CorePivot',
            nodeB: 'CentralGear',
            anchor: v.Vector2(0, 0),
            enableMotor: true,
            motorSpeed: 1.1,
            maxMotorTorque: 10000.0,
          ),

          // 2. THE MECHANICAL ARMS (Four Directions)
          ..._buildMechanicalArms(),

          // 3. THE RECOVERY WEB (Bottom reactive part)
          ..._buildNeonWeb(),

          // 4. INTERACTIVE SPARKLES
          for (final spark in _sparks)
            FRigidBody.circle(
              key: ValueKey('spark_${spark.id}'),
              name: 'Spark',
              position: spark.position,
              radius: 5,
              restitution: 0.8,
              child: const _GlowNode(color: Colors.yellowAccent, radius: 5),
            ),
        ],
        overlay: [
          _buildSciFiHUD(),
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                // Convert screen touch to world space (simple 1:1 for ortho @ 500 size)
                final box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(details.globalPosition);
                // Unified conversion formula for orthographic projection:
                // scale = (2 * halfHeight) / viewportHeight
                final scale = (2 * _cameraSize) / box.size.height;
                final worldX = (local.dx - box.size.width / 2) * scale;
                final worldY = -(local.dy - box.size.height / 2) * scale;
                _spawnSpark(v.Vector3(worldX, worldY, 0));
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMechanicalArms() {
    List<Widget> arms = [];
    final angles = [0, math.pi / 2, math.pi, 3 * math.pi / 2];
    final colors = [Colors.purpleAccent, Colors.limeAccent, Colors.orangeAccent, Colors.blueAccent];

    for (int i = 0; i < 4; i++) {
      final angle = angles[i];
      final color = colors[i];
      final dir = v.Vector2(math.cos(angle), math.sin(angle));
      final endPos = v.Vector3(dir.x * 150, dir.y * 150, 0);

      arms.add(
        FRigidBody.square(
          name: 'Arm_$i',
          position: endPos,
          size: 40,
          child: _NeonGear(color: color, size: 40),
        ),
      );

      arms.add(
        FDistanceJoint(
          nodeA: 'CentralGear',
          nodeB: 'Arm_$i',
          anchorA: v.Vector2(dir.x * 50, dir.y * 50),
          length: 150,
          frequency: 0, // Perfectly Rigid
          dampingRatio: 1.0,
        ),
      );

      // Sarkaç (Pendulum) at the end of each arm
      final bobPos = v.Vector3(endPos.x, endPos.y - 120, 0);
      arms.add(
        FRigidBody.circle(
          name: 'Bob_$i',
          position: bobPos,
          radius: 18,
          child: _GlowNode(color: color, radius: 18),
        ),
      );

      arms.add(FDistanceJoint(nodeA: 'Arm_$i', nodeB: 'Bob_$i', length: 120, frequency: 0, dampingRatio: 1.0));
    }
    return arms;
  }

  List<Widget> _buildNeonWeb() {
    return [
      FStaticBody(
        name: 'WebAnchorLeft',
        position: v.Vector3(-220, -400, 0),
        width: 20,
        height: 20,
        child: const _GlowNode(color: Colors.white24, radius: 10),
      ),
      FStaticBody(
        name: 'WebAnchorRight',
        position: v.Vector3(220, -400, 0),
        width: 20,
        height: 20,
        child: const _GlowNode(color: Colors.white24, radius: 10),
      ),
      for (int i = 0; i < 6; i++)
        FRigidBody.circle(
          name: 'WebNode_$i',
          position: v.Vector3(-150.0 + (i * 60), -450, 0),
          radius: 8,
          child: const _GlowNode(color: Colors.cyanAccent, radius: 8),
        ),

      FDistanceJoint(nodeA: 'WebAnchorLeft', nodeB: 'WebNode_0', length: 100, frequency: 0, dampingRatio: 1.0),
      for (int i = 0; i < 5; i++)
        FDistanceJoint(nodeA: 'WebNode_$i', nodeB: 'WebNode_${i + 1}', length: 60, frequency: 0, dampingRatio: 1.0),
      FDistanceJoint(nodeA: 'WebNode_5', nodeB: 'WebAnchorRight', length: 100, frequency: 0, dampingRatio: 1.0),
    ];
  }

  Widget _buildSciFiHUD() {
    return Positioned(
      left: 20,
      top: 20,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HUDLabel(text: 'SYSTEM: ACTIVE', color: Colors.cyanAccent),
            const SizedBox(height: 8),
            _HUDLabel(text: 'KINETIC SCULPTURE BETA v1.0', color: Colors.purpleAccent, isSmall: true),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HUDMetric(label: 'HUB VELOCITY', value: '1.5 rad/s'),
                  _HUDMetric(label: 'JOINT TENSION', value: 'STABLE'),
                  _HUDMetric(label: 'NEON FLUX', value: 'OPTIMAL'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _HUDLabel(text: 'TAP TO INJECT PARTICLES', color: Colors.yellowAccent, isSmall: true),
          ],
        ),
      ),
    );
  }
}

// --- VISUAL COMPONENTS ---

class _GlowNode extends StatelessWidget {
  final Color color;
  final double radius;
  const _GlowNode({required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Blur
        Container(
          width: radius * 3,
          height: radius * 3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 30, spreadRadius: 10)],
          ),
        ),
        // Neon Ring
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.8), blurRadius: 15, spreadRadius: 2)],
          ),
        ),
        // Hot Core
        Container(
          width: radius * 0.4,
          height: radius * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: color, blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}

class _NeonGear extends StatelessWidget {
  final Color color;
  final double size;
  const _NeonGear({required this.color, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main structural ring
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 4),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)],
          ),
        ),
        // Inner detail ring
        Container(
          width: size * 0.7,
          height: size * 0.7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
        ),
        // Mechanical spokes
        for (int i = 0; i < 4; i++)
          Transform.rotate(
            angle: (i * math.pi / 4),
            child: Container(width: size, height: 2, color: color.withOpacity(0.6)),
          ),
        // Glowing Hub
        Container(
          width: size * 0.2,
          height: size * 0.2,
          decoration: BoxDecoration(
            color: color,
            boxShadow: [BoxShadow(color: Colors.white, blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}

class _NeonGrid extends StatelessWidget {
  const _NeonGrid();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: CustomPaint(painter: _GridPainter()));
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.05)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 50) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _HUDLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool isSmall;
  const _HUDLabel({required this.text, required this.color, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontFamily: 'Courier',
        fontWeight: FontWeight.bold,
        fontSize: isSmall ? 10 : 16,
        letterSpacing: 2,
      ),
    );
  }
}

class _HUDMetric extends StatelessWidget {
  final String label;
  final String value;
  const _HUDMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'Courier'),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
