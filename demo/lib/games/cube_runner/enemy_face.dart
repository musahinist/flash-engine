import 'dart:math' as math;
import 'package:flutter/material.dart';

enum EnemyFaceType { patrol, chaser, jumper }

class EnemyFace extends StatelessWidget {
  final EnemyFaceType type;
  final double size;
  final double animValue; // 0.0 to 1.0

  const EnemyFace({super.key, required this.type, required this.size, required this.animValue});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EnemyFacePainter(type: type, animValue: animValue),
      size: Size(size, size),
    );
  }
}

class _EnemyFacePainter extends CustomPainter {
  final EnemyFaceType type;
  final double animValue;

  _EnemyFacePainter({required this.type, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final cubeSize = size.width;

    // Determine colors based on type
    final (Color _, Color eyeColor, Function pattern) = switch (type) {
      EnemyFaceType.patrol => (Colors.purple, Colors.yellow, _drawPatrolPattern),
      EnemyFaceType.chaser => (Colors.red, Colors.white, _drawChaserPattern),
      EnemyFaceType.jumper => (Colors.green, Colors.orange, _drawJumperPattern),
    };

    // Note: We don't draw the cube body background here because FIsometricCubeWidget handles that.
    // We only draw the pattern and eyes on top.

    // Draw type-specific pattern
    pattern(canvas, cx, cy, cubeSize, animValue);

    // Eyes (angry expression)
    _drawEyes(canvas, cx, cy, cubeSize, eyeColor, animValue);
  }

  void _drawPatrolPattern(Canvas canvas, double cx, double cy, double size, double anim) {
    // Horizontal stripes
    final paint = Paint()
      ..color = Colors.purple.shade200.withValues(alpha: 0.5)
      ..strokeWidth = 3;

    for (int i = -1; i <= 1; i++) {
      // Offset Y slightly to look good on face
      final yOff = i * size * 0.15;
      canvas.drawLine(Offset(cx - size * 0.35, cy + yOff), Offset(cx + size * 0.35, cy + yOff), paint);
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
  bool shouldRepaint(covariant _EnemyFacePainter oldDelegate) =>
      oldDelegate.animValue != animValue || oldDelegate.type != type;
}
