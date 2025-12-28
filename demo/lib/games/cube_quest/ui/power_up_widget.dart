import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/collectible.dart';

/// Widget for rendering power-ups on the grid
class PowerUpWidget extends StatefulWidget {
  final PowerUpType type;

  const PowerUpWidget({super.key, required this.type});

  @override
  State<PowerUpWidget> createState() => _PowerUpWidgetState();
}

class _PowerUpWidgetState extends State<PowerUpWidget> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
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
          painter: _PowerUpPainter(type: widget.type, progress: _anim.value),
          size: const Size(50, 50),
        );
      },
    );
  }
}

class _PowerUpPainter extends CustomPainter {
  final PowerUpType type;
  final double progress;

  _PowerUpPainter({required this.type, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Glow effect
    final glowPaint = Paint()
      ..color = type.color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(Offset(cx, cy - 8), 18, glowPaint);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 10),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Float animation
    final floatY = math.sin(progress * math.pi * 2) * 4;

    canvas.save();
    canvas.translate(cx, cy - 12 + floatY);

    // Rotation for effect
    final rotation = progress * math.pi * 2;

    switch (type) {
      case PowerUpType.speed:
        _drawSpeed(canvas, rotation);
        break;
      case PowerUpType.shield:
        _drawShield(canvas, rotation);
        break;
      case PowerUpType.magnet:
        _drawMagnet(canvas, rotation);
        break;
      case PowerUpType.ghost:
        _drawGhost(canvas, rotation);
        break;
    }

    canvas.restore();
  }

  void _drawSpeed(Canvas canvas, double rotation) {
    // Lightning bolt
    final path = Path()
      ..moveTo(4, -12)
      ..lineTo(-4, 0)
      ..lineTo(2, 0)
      ..lineTo(-4, 12)
      ..lineTo(8, -2)
      ..lineTo(2, -2)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.yellow, Colors.orange],
        ).createShader(const Rect.fromLTWH(-8, -12, 16, 24)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.orange.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawShield(Canvas canvas, double rotation) {
    // Shield shape
    final path = Path()
      ..moveTo(0, -12)
      ..lineTo(10, -6)
      ..quadraticBezierTo(10, 4, 0, 12)
      ..quadraticBezierTo(-10, 4, -10, -6)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.lightBlue, Colors.blue],
        ).createShader(const Rect.fromLTWH(-10, -12, 20, 24)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue.shade800
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Shield star
    canvas.drawCircle(const Offset(0, -2), 4, Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  void _drawMagnet(Canvas canvas, double rotation) {
    // U-shaped magnet
    final paint = Paint()..style = PaintingStyle.fill;

    // Left arm (red)
    final leftArm = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -10, 6, 16), const Radius.circular(2)));
    paint.color = Colors.red;
    canvas.drawPath(leftArm, paint);

    // Right arm (blue)
    final rightArm = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, -10, 6, 16), const Radius.circular(2)));
    paint.color = Colors.blue;
    canvas.drawPath(rightArm, paint);

    // Bottom curve (gray)
    canvas.drawArc(
      const Rect.fromLTWH(-10, -2, 20, 16),
      0,
      math.pi,
      false,
      Paint()
        ..color = Colors.grey.shade600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    // Magnetic waves
    final wavePaint = Paint()
      ..color = Colors.purple.withValues(alpha: 0.5 * (1 - (rotation % 1)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
      final waveProgress = (rotation + i * 0.33) % 1;
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(0, 3), width: 15 + waveProgress * 10, height: 10 + waveProgress * 6),
        -math.pi,
        math.pi,
        false,
        wavePaint..color = Colors.purple.withValues(alpha: 0.5 * (1 - waveProgress)),
      );
    }
  }

  void _drawGhost(Canvas canvas, double rotation) {
    // Ghost body
    final ghostPath = Path()
      ..moveTo(-10, 10)
      ..lineTo(-10, -4)
      ..quadraticBezierTo(-10, -12, 0, -12)
      ..quadraticBezierTo(10, -12, 10, -4)
      ..lineTo(10, 10);

    // Wavy bottom
    for (int i = 0; i < 4; i++) {
      final double waveX = (10 - (i + 1) * 5).toDouble();
      final double waveY = 10 + math.sin(rotation * 4 + i.toDouble()) * 2;
      ghostPath.quadraticBezierTo(waveX + 2.5, waveY + 4, waveX, waveY);
    }
    ghostPath.close();

    // Semi-transparent ghost
    canvas.drawPath(
      ghostPath,
      Paint()..color = Colors.grey.shade300.withValues(alpha: 0.7 + math.sin(rotation * math.pi * 2) * 0.2),
    );

    canvas.drawPath(
      ghostPath,
      Paint()
        ..color = Colors.grey.shade500
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Eyes
    canvas.drawOval(const Rect.fromLTWH(-6, -6, 5, 6), Paint()..color = Colors.black);
    canvas.drawOval(const Rect.fromLTWH(1, -6, 5, 6), Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant _PowerUpPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.type != type;
}
