import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math' as math;

class SoftBodyDemoExample extends StatefulWidget {
  const SoftBodyDemoExample({super.key});

  @override
  State<SoftBodyDemoExample> createState() => _SoftBodyDemoExampleState();
}

class _SoftBodyDemoExampleState extends State<SoftBodyDemoExample> {
  v.Vector2? _dragTarget;
  final GlobalKey _sceneKey = GlobalKey();

  void _handleDrag(Offset localPos, Size boxSize) {
    const double cameraHalfSize = 500.0;
    final scale = (2 * cameraHalfSize) / boxSize.height;
    final worldX = (localPos.dx - boxSize.width / 2) * scale;
    final worldY = -(localPos.dy - boxSize.height / 2) * scale;
    setState(() {
      _dragTarget = v.Vector2(worldX, worldY);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: GestureDetector(
        onPanStart: (details) {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          _handleDrag(box.globalToLocal(details.globalPosition), box.size);
        },
        onPanUpdate: (details) {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          _handleDrag(box.globalToLocal(details.globalPosition), box.size);
        },
        onPanEnd: (_) => setState(() => _dragTarget = null),
        child: FScene(
          key: _sceneKey,
          scene: [
            const _NeonGrid(),
            FCamera(position: v.Vector3(0, 0, 1000), isOrthographic: true, orthographicSize: 500.0),

            // Declarative widget for the soft body
            // Declarative widget for the soft body
            FNeonJelly(radius: 120, pointsCount: 40, dragTarget: _dragTarget),
          ],
          overlay: [_buildHUD()],
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
          const _HUDLabel(text: 'SYSTEM: BIO_SOFT_CORE', color: Colors.cyanAccent),
          const SizedBox(height: 4),
          _HUDLabel(text: 'PRESSURE: NOMINAL', color: Colors.white.withValues(alpha: 0.3), isSmall: true),
        ],
      ),
    );
  }
}

// --- DECLARATIVE WIDGET ---

class FNeonJelly extends FNodeWidget {
  final double radius;
  final int pointsCount;
  final v.Vector2? dragTarget;

  const FNeonJelly({super.key, required this.radius, required this.pointsCount, this.dragTarget});

  @override
  State<FNeonJelly> createState() => _FNeonJellyState();
}

class _FNeonJellyState extends FNodeWidgetState<FNeonJelly, SoftBlobNode> {
  @override
  SoftBlobNode createNode() => SoftBlobNode(radius: widget.radius, pointsCount: widget.pointsCount);

  @override
  void applyProperties([FNeonJelly? oldWidget]) {
    super.applyProperties(oldWidget);
    node.dragTarget = widget.dragTarget;
  }
}

// --- ENGINE NODE ---

class SoftBlobNode extends FNode {
  final List<VerletPoint> points = [];
  final double targetArea;
  final double pressureConstant = 25000.0;
  final double radius;
  v.Vector2? dragTarget;

  SoftBlobNode({required this.radius, int pointsCount = 20}) : targetArea = math.pi * radius * radius {
    for (int i = 0; i < pointsCount; i++) {
      final angle = (i / pointsCount) * math.pi * 2;
      points.add(VerletPoint(v.Vector2(math.cos(angle) * radius, math.sin(angle) * radius)));
    }
  }

  @override
  void process(double dt) {
    // sub-stepping for stability
    const int substeps = 8;
    final double sdt = dt / substeps;

    for (int s = 0; s < substeps; s++) {
      // 1. Gravity
      for (final p in points) {
        p.acceleration += v.Vector2(0, -980);
      }

      // 2. Drag
      if (dragTarget != null) {
        VerletPoint? nearest;
        double minDist = double.infinity;
        for (final p in points) {
          final d = (p.position - dragTarget!).length;
          if (d < minDist) {
            minDist = d;
            nearest = p;
          }
        }
        if (nearest != null && minDist < 200) {
          nearest.position += (dragTarget! - nearest.position) * 0.15;
        }
      }

      // 3. Integrate
      for (final p in points) {
        p.update(sdt, 0.98);
      }

      // 4. Constraints
      final rest = (2 * math.pi * radius) / points.length;
      for (int i = 0; i < points.length; i++) {
        _constrainDistance(points[i], points[(i + 1) % points.length], rest, 1.0);
        // Interior supports
        _constrainDistance(points[i], points[(i + points.length ~/ 2) % points.length], radius * 2, 0.05);
      }

      // 5. Pressure
      _applyPressure();

      // 6. World Bounds
      for (final p in points) {
        if (p.position.y < -400) {
          p.position.y = -400;
          p.oldPosition.x += (p.position.x - p.oldPosition.x) * 0.2; // Friction
        }
        if (p.position.x.abs() > 450) {
          p.position.x = 450 * p.position.x.sign;
        }
      }
    }
  }

  void _constrainDistance(VerletPoint p1, VerletPoint p2, double rest, double stiffness) {
    final delta = p2.position - p1.position;
    final dist = delta.length;
    if (dist == 0) return;
    final diff = (dist - rest) / dist;
    p1.position += delta * 0.5 * diff * stiffness;
    p2.position -= delta * 0.5 * diff * stiffness;
  }

  void _applyPressure() {
    double currentArea = 0;
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i].position;
      final p2 = points[(i + 1) % points.length].position;
      currentArea += (p1.x * p2.y - p2.x * p1.y);
    }
    currentArea = currentArea.abs() * 0.5;

    final areaDiff = targetArea - currentArea;
    for (int i = 0; i < points.length; i++) {
      final prev = points[(i - 1 + points.length) % points.length].position;
      final next = points[(i + 1) % points.length].position;
      final normal = v.Vector2(next.y - prev.y, -(next.x - prev.x)).normalized();
      points[i].position += normal * (areaDiff * pressureConstant * 0.000000001);
    }
  }

  @override
  void draw(Canvas canvas) {
    if (points.isEmpty) return;

    // Calculate center of mass for dynamic lighting
    double avgX = 0;
    double avgY = 0;
    for (final p in points) {
      avgX += p.position.x;
      avgY += p.position.y;
    }
    final center = Offset(avgX / points.length, avgY / points.length);

    final path = Path();

    // Smooth Catmull-Rom Spline implementation
    if (points.length > 2) {
      path.moveTo(
        (points[points.length - 1].position.x + points[0].position.x) / 2,
        (points[points.length - 1].position.y + points[0].position.y) / 2,
      );

      for (int i = 0; i < points.length; i++) {
        final p0 = points[i].position;
        final p1 = points[(i + 1) % points.length].position;

        // Use quadratic bezier midpoints for ultra-smooth organic feel
        final midX = (p0.x + p1.x) / 2;
        final midY = (p0.y + p1.y) / 2;

        path.quadraticBezierTo(p0.x, p0.y, midX, midY);
      }
    }
    path.close();

    // Pulse effect for the core
    final pulse = 1.0 + 0.1 * math.sin(DateTime.now().millisecondsSinceEpoch / 200.0);

    // Visual layers
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.cyanAccent.withValues(alpha: 0.4),
          Colors.blueAccent.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5))
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // Core Nucleus
    canvas.drawCircle(
      center,
      15 * pulse,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);

    // Nervous system lines
    final nervePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.2)
      ..strokeWidth = 1.2;
    for (int i = 0; i < points.length; i += 5) {
      canvas.drawLine(center, Offset(points[i].position.x, points[i].position.y), nervePaint);
    }
  }
}

// --- PHYSICS HELPER ---

class VerletPoint {
  v.Vector2 position;
  v.Vector2 oldPosition;
  v.Vector2 acceleration = v.Vector2.zero();

  VerletPoint(this.position) : oldPosition = v.Vector2.copy(position);

  void update(double dt, double friction) {
    final velocity = (position - oldPosition) * friction;
    oldPosition = v.Vector2.copy(position);
    position += velocity + acceleration * (dt * dt);
    acceleration = v.Vector2.zero();
  }
}

// --- REUSED VISUALS ---

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
