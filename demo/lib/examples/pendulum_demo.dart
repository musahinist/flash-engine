import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math' as math;
import 'dart:ffi' hide Size;

class PendulumDemoExample extends StatefulWidget {
  const PendulumDemoExample({super.key});

  @override
  State<PendulumDemoExample> createState() => _PendulumDemoExampleState();
}

class _PendulumDemoExampleState extends State<PendulumDemoExample> {
  int? _draggedBodyId;
  v.Vector3? _dragTarget;
  static const double _cameraHalfSize = 500.0;
  final GlobalKey _sceneKey = GlobalKey();

  void _handleDrag(Offset localPos, Size boxSize) {
    final scale = (2 * _cameraHalfSize) / boxSize.height;
    final worldX = (localPos.dx - boxSize.width / 2) * scale;
    final worldY = -(localPos.dy - boxSize.height / 2) * scale;

    setState(() {
      _dragTarget = v.Vector3(worldX, worldY, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    const double ballRadius = 28.0;
    const double spacing = 62.0;
    const double wireLength = 320.0;
    const double anchorY = 320.0;
    final List<Color> colors = [
      Colors.cyanAccent,
      Colors.purpleAccent,
      Colors.limeAccent,
      Colors.orangeAccent,
      Colors.blueAccent,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: GestureDetector(
        onPanStart: (details) {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.globalPosition);
          _handleDrag(local, box.size);
        },
        onPanUpdate: (details) {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.globalPosition);
          _handleDrag(local, box.size);
        },
        onPanEnd: (_) => setState(() {
          _draggedBodyId = null;
          _dragTarget = null;
        }),
        child: FScene(
          key: _sceneKey,
          showDebugOverlay: false,
          scene: [
            const _NeonGrid(),
            FCamera(position: v.Vector3(0, 0, 1000), isOrthographic: true, orthographicSize: 500.0),

            for (int i = 0; i < 5; i++) ...[
              FStaticBody(
                name: 'Anchor_$i',
                position: v.Vector3(-spacing * 2 + (i * spacing), anchorY, 0),
                width: 10,
                height: 10,
                child: const SizedBox.shrink(),
              ),

              FRigidBody.circle(
                key: ValueKey('ball_$i'),
                name: 'Ball_$i',
                position: () {
                  final anchorX = -spacing * 2 + (i * spacing);
                  if (i == 0) {
                    return v.Vector3(
                      anchorX + math.sin(-math.pi / 3) * wireLength,
                      anchorY - math.cos(-math.pi / 3) * wireLength,
                      0,
                    );
                  }
                  return v.Vector3(anchorX, anchorY - wireLength, 0);
                }(),
                radius: ballRadius,
                restitution: 1.0,
                friction: 0.0,
                onUpdate: (body) {
                  if (_dragTarget != null) {
                    final ballPos = v.Vector2(body.transform.position.x, body.transform.position.y);
                    final dist = v.Vector2(_dragTarget!.x, _dragTarget!.y) - ballPos;

                    // Pick the closest ball if none is held
                    if (_draggedBodyId == null && dist.length < ballRadius * 4) {
                      _draggedBodyId = body.bodyId;
                    }

                    if (_draggedBodyId == body.bodyId) {
                      // Apply magnetic force
                      body.applyForce(dist.x * 30000, dist.y * 30000);

                      // Precise dragging damping
                      body.world.ref.bodies[body.bodyId].vx *= 0.8;
                      body.world.ref.bodies[body.bodyId].vy *= 0.8;
                    }
                  }
                },
                child: _GlowNode(color: colors[i], radius: ballRadius),
              ),

              FDistanceJoint(nodeA: 'Anchor_$i', nodeB: 'Ball_$i', length: wireLength, frequency: 0, dampingRatio: 1.0),
            ],
          ],
          overlay: [
            _buildHUD(),
            if (_dragTarget != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    if (size.height <= 0) return const SizedBox.shrink();
                    final scale = (2 * _cameraHalfSize) / size.height;
                    final screenX = (_dragTarget!.x / scale) + size.width / 2;
                    final screenY = -(_dragTarget!.y / scale) + size.height / 2;
                    return CustomPaint(painter: _TouchIndicatorPainter(Offset(screenX, screenY)));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    return Positioned(
      top: 40,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HUDLabel(text: 'SYSTEM: PENDULUM_CORE', color: Colors.cyanAccent),
          const SizedBox(height: 4),
          _HUDLabel(text: 'MOMENTUM TRANSFER: ACTIVE', color: Colors.white.withValues(alpha: 0.24), isSmall: true),
        ],
      ),
    );
  }
}

class _GlowNode extends StatelessWidget {
  final Color color;
  final double radius;
  const _GlowNode({required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: radius * 2.5,
          height: radius * 2.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 5)],
          ),
        ),
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 10)],
          ),
        ),
        Container(
          width: radius * 0.4,
          height: radius * 0.4,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
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
      ..color = Colors.cyanAccent.withValues(alpha: 0.03)
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

class _TouchIndicatorPainter extends CustomPainter {
  final Offset pos;
  _TouchIndicatorPainter(this.pos);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(pos, 30, paint);

    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(pos, 10, innerPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
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
        fontSize: isSmall ? 10 : 14,
        letterSpacing: 1.5,
      ),
    );
  }
}
