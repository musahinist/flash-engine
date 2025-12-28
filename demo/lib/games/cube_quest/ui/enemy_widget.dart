import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/enemy.dart';

/// Widget for rendering enemy cubes
class EnemyWidget extends StatefulWidget {
  final EnemyType type;
  final double cubeSize;

  const EnemyWidget({super.key, required this.type, this.cubeSize = 50});

  @override
  State<EnemyWidget> createState() => _EnemyWidgetState();
}

class _EnemyWidgetState extends State<EnemyWidget> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return CustomPaint(
          painter: _EnemyPainter(type: widget.type, cubeSize: widget.cubeSize, animValue: _anim.value),
          size: Size(widget.cubeSize, widget.cubeSize),
        );
      },
    );
  }
}

class _EnemyPainter extends CustomPainter {
  final EnemyType type;
  final double cubeSize;
  final double animValue;

  _EnemyPainter({required this.type, required this.cubeSize, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Enemy color based on type
    final (MaterialColor baseColor, Color eyeColor, Function pattern) = switch (type) {
      EnemyType.patrol => (Colors.purple, Colors.yellow, _drawPatrolPattern),
      EnemyType.chaser => (Colors.red, Colors.white, _drawChaserPattern),
      EnemyType.jumper => (Colors.green, Colors.orange, _drawJumperPattern),
    };

    // Cube body
    final bodyPath = Path()
      ..addRect(Rect.fromCenter(center: Offset(cx, cy), width: cubeSize * 0.8, height: cubeSize * 0.8));

    // Drop shadow
    canvas.drawPath(
      bodyPath.shift(const Offset(2, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Main body
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor.withValues(alpha: 0.9), baseColor.shade900],
        ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: cubeSize, height: cubeSize)),
    );

    // Border
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = baseColor.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw type-specific pattern
    pattern(canvas, cx, cy, cubeSize, animValue);

    // Eyes (angry expression)
    _drawEyes(canvas, cx, cy, cubeSize, eyeColor, animValue);
  }

  void _drawPatrolPattern(Canvas canvas, double cx, double cy, double size, double anim) {
    // Horizontal stripes
    final paint = Paint()
      ..color = Colors.purple.shade300.withValues(alpha: 0.5)
      ..strokeWidth = 3;

    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(cx - size * 0.35, cy + i * size * 0.15),
        Offset(cx + size * 0.35, cy + i * size * 0.15),
        paint,
      );
    }
  }

  void _drawChaserPattern(Canvas canvas, double cx, double cy, double size, double anim) {
    // Pulsing danger sign
    final pulseScale = 1 + math.sin(anim * math.pi * 2) * 0.1;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(pulseScale);

    final path = Path();
    const r = 8.0;
    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 3;
      final x = math.cos(angle) * r;
      final y = math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = Colors.yellow.withValues(alpha: 0.7));
    canvas.restore();
  }

  void _drawJumperPattern(Canvas canvas, double cx, double cy, double size, double anim) {
    // Spring coils
    final paint = Paint()
      ..color = Colors.lightGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final bounce = math.sin(anim * math.pi * 4) * 3;

    for (int i = 0; i < 3; i++) {
      final y = cy + size * 0.15 + i * 4 + bounce;
      canvas.drawArc(Rect.fromCenter(center: Offset(cx, y), width: size * 0.4, height: 4), 0, math.pi, false, paint);
    }
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double size, Color color, double anim) {
    final eyeY = cy - size * 0.15;
    final eyeSpacing = size * 0.15;

    // Eye whites
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - eyeSpacing, eyeY), width: 10, height: 8),
      Paint()..color = Colors.white,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + eyeSpacing, eyeY), width: 10, height: 8),
      Paint()..color = Colors.white,
    );

    // Pupils (move slightly with animation)
    final pupilOffset = math.sin(anim * math.pi * 2) * 1.5;
    canvas.drawCircle(Offset(cx - eyeSpacing + pupilOffset, eyeY), 3, Paint()..color = color);
    canvas.drawCircle(Offset(cx + eyeSpacing + pupilOffset, eyeY), 3, Paint()..color = color);

    // Angry eyebrows
    final browPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx - eyeSpacing - 5, eyeY - 7), Offset(cx - eyeSpacing + 3, eyeY - 4), browPaint);
    canvas.drawLine(Offset(cx + eyeSpacing + 5, eyeY - 7), Offset(cx + eyeSpacing - 3, eyeY - 4), browPaint);
  }

  @override
  bool shouldRepaint(covariant _EnemyPainter oldDelegate) =>
      oldDelegate.animValue != animValue || oldDelegate.type != type;
}
