import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:forge2d/forge2d.dart' as f2d;

/// Demonstrates both Verlet (FlashRopeWidget) and Forge2D joint systems
class JointDemoExample extends StatefulWidget {
  const JointDemoExample({super.key});

  @override
  State<JointDemoExample> createState() => _JointDemoExampleState();
}

class _JointDemoExampleState extends State<JointDemoExample> {
  // Verlet anchor position (controlled by gesture)
  v.Vector3 _verletAnchor = v.Vector3(0, 100, 0);

  // Key to access FlashRopeWidget state
  final GlobalKey<FlashRopeWidgetState> _ropeKey = GlobalKey();

  // Forge2D system
  late FlashPhysicsWorld _physicsWorld;
  late FlashPhysicsBody _pendulumBob;
  final List<FlashPhysicsBody> _chainBodies = [];
  v.Vector2 _forge2dAnchor = v.Vector2(0, 0);

  String _debugText = 'Drag anchor points to interact';

  @override
  void initState() {
    super.initState();
    _initForge2D();
  }

  void _initForge2D() {
    _physicsWorld = FlashPhysicsWorld(gravity: v.Vector2(0, -9.81));
    const chainLength = 8;
    const linkSize = 20.0;
    FlashPhysicsBody? prevBody;

    for (int i = 0; i < chainLength; i++) {
      final bodyDef = f2d.BodyDef()
        ..type = i == 0 ? f2d.BodyType.static : f2d.BodyType.dynamic
        ..position = v.Vector2(0, FlashPhysics.toMeters(-i * linkSize));

      final body = _physicsWorld.world.createBody(bodyDef);
      body.createFixture(
        f2d.FixtureDef(f2d.CircleShape()..radius = 8)
          ..density = 1.0
          ..friction = 0.3,
      );

      final physicsBody = FlashPhysicsBody(body: body, name: 'Chain$i');
      _chainBodies.add(physicsBody);

      if (prevBody != null) {
        FlashRevoluteJoint2D(
          bodyA: prevBody,
          bodyB: physicsBody,
          anchorWorldPoint: v.Vector2(0, FlashPhysics.toMeters(-(i - 0.5) * linkSize)),
        ).create(_physicsWorld);
      }
      prevBody = physicsBody;
    }

    final bobDef = f2d.BodyDef()
      ..type = f2d.BodyType.dynamic
      ..position = v.Vector2(0, FlashPhysics.toMeters(-chainLength * linkSize));
    final bobBody = _physicsWorld.world.createBody(bobDef);
    bobBody.createFixture(
      f2d.FixtureDef(f2d.CircleShape()..radius = 20)
        ..density = 3.0
        ..friction = 0.5,
    );

    _pendulumBob = FlashPhysicsBody(body: bobBody, name: 'PendulumBob');

    if (_chainBodies.isNotEmpty) {
      FlashRevoluteJoint2D(
        bodyA: _chainBodies.last,
        bodyB: _pendulumBob,
        anchorWorldPoint: v.Vector2(0, FlashPhysics.toMeters(-(chainLength - 0.5) * linkSize)),
      ).create(_physicsWorld);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1b2a),
      appBar: AppBar(title: const Text('Joint System Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Flash(
        enableInputCapture: false,
        showDebugOverlay: false,
        child: Builder(
          builder: (context) {
            final inherited = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>();
            final engine = inherited?.engine;

            if (engine != null) {
              engine.onUpdate = () {
                final dt = 1 / 60.0;
                _physicsWorld.update(dt);
                for (final body in _chainBodies) {
                  body.update(dt);
                }
                _pendulumBob.update(dt);
                setState(() {});
              };
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final halfWidth = constraints.maxWidth / 2;

                return Stack(
                  children: [
                    // LEFT: Verlet Rope using FlashRopeWidget
                    Positioned.fill(
                      right: halfWidth,
                      child: FlashRopeWidget(
                        key: _ropeKey,
                        anchorPosition: _verletAnchor,
                        segments: 12,
                        length: 180,
                        damping: 0.98,
                        constraintIterations: 6,
                        painter: (positions) => FlashRopePainter(
                          positions: positions,
                          color: Colors.cyanAccent,
                          center: Offset(halfWidth / 2, 250),
                        ),
                      ),
                    ),

                    // RIGHT: Forge2D Chain
                    Positioned.fill(
                      left: halfWidth,
                      child: CustomPaint(painter: _Forge2DPainter(_chainBodies, _pendulumBob, halfWidth / 2, 120, 3)),
                    ),

                    // Divider
                    Positioned(
                      left: halfWidth - 1,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: Container(color: Colors.white30),
                    ),

                    // LEFT GESTURE
                    Positioned.fill(
                      right: halfWidth,
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          final x = d.localPosition.dx - halfWidth / 2;
                          final y = -(d.localPosition.dy - 250);
                          _verletAnchor = v.Vector3(x * 0.7, y * 0.7, 0);
                          _ropeKey.currentState?.moveAnchor(_verletAnchor);
                          setState(
                            () => _debugText = 'Verlet: ${d.localPosition.dx.toInt()}, ${d.localPosition.dy.toInt()}',
                          );
                        },
                      ),
                    ),

                    // RIGHT GESTURE
                    Positioned.fill(
                      left: halfWidth,
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          final x = (d.localPosition.dx - halfWidth / 2) / 3;
                          final y = (d.localPosition.dy - 120) / 3;
                          _forge2dAnchor = v.Vector2(x, y);
                          if (_chainBodies.isNotEmpty) {
                            _chainBodies.first.body.setTransform(_forge2dAnchor, 0);
                          }
                          setState(
                            () => _debugText = 'Forge2D: ${d.localPosition.dx.toInt()}, ${d.localPosition.dy.toInt()}',
                          );
                        },
                      ),
                    ),

                    // Labels
                    Positioned(top: 100, left: 20, child: _label('VERLET', 'FlashRopeWidget', Colors.cyanAccent)),
                    Positioned(top: 100, right: 20, child: _label('FORGE2D', 'Physics Engine', Colors.orangeAccent)),

                    // Debug text
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            _debugText,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _label(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
        ],
      ),
    );
  }
}

class _Forge2DPainter extends CustomPainter {
  final List<FlashPhysicsBody> chain;
  final FlashPhysicsBody bob;
  final double cx, cy, scale;
  _Forge2DPainter(this.chain, this.bob, this.cx, this.cy, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (int i = 0; i < chain.length; i++) {
      final p = chain[i].body.position;
      if (i == 0) {
        path.moveTo(cx + p.x * scale, cy - p.y * scale);
      } else {
        path.lineTo(cx + p.x * scale, cy - p.y * scale);
      }
    }

    final bp = bob.body.position;
    final bx = cx + bp.x * scale, by = cy - bp.y * scale;
    path.lineTo(bx, by);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.orangeAccent.withValues(alpha: 0.4)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    for (int i = 0; i < chain.length; i++) {
      final p = chain[i].body.position;
      canvas.drawCircle(Offset(cx + p.x * scale, cy - p.y * scale), i == 0 ? 12 : 7, Paint()..color = Colors.white);
    }

    canvas.drawCircle(Offset(bx, by), 28, Paint()..color = Colors.orangeAccent);
    canvas.drawCircle(
      Offset(bx, by),
      28,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
