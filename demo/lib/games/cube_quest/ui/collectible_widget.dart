import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/collectible.dart';

/// Widget for rendering different collectible types
class CollectibleWidget extends StatefulWidget {
  final CollectibleType type;

  const CollectibleWidget({super.key, required this.type});

  @override
  State<CollectibleWidget> createState() => _CollectibleWidgetState();
}

class _CollectibleWidgetState extends State<CollectibleWidget> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
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
          painter: _CollectiblePainter(type: widget.type, progress: _anim.value),
          size: const Size(40, 40),
        );
      },
    );
  }
}

class _CollectiblePainter extends CustomPainter {
  final CollectibleType type;
  final double progress;

  _CollectiblePainter({required this.type, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 7), shadowPaint);

    // Float animation
    final floatY = math.sin(progress * math.pi * 2) * 3;

    canvas.save();
    canvas.translate(cx, cy - 12 + floatY);

    switch (type) {
      case CollectibleType.diamond:
        _drawDiamond(canvas);
        break;
      case CollectibleType.star:
        _drawStar(canvas);
        break;
      case CollectibleType.key:
        _drawKey(canvas);
        break;
      case CollectibleType.heart:
        _drawHeart(canvas);
        break;
    }

    canvas.restore();
  }

  void _drawDiamond(Canvas canvas) {
    const dSize = 12.0;
    final rotateAngle = progress * math.pi * 2;

    final top = const Offset(0, -dSize * 1.1);
    final bottom = const Offset(0, dSize * 1.1);

    final midPoints = <Offset>[];
    for (int i = 0; i < 6; i++) {
      final a = rotateAngle + (i * math.pi * 2 / 6);
      midPoints.add(Offset(math.cos(a) * dSize, math.sin(a) * dSize * 0.5));
    }

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.3);

    for (int i = 0; i < 6; i++) {
      final p1 = midPoints[i];
      final p2 = midPoints[(i + 1) % 6];

      final pathTop = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      fillPaint.color = HSLColor.fromAHSL(1, 190, 0.8, 0.4 + (i % 3) * 0.1).toColor();
      canvas.drawPath(pathTop, fillPaint);
      canvas.drawPath(pathTop, linePaint);

      final pathBottom = Path()
        ..moveTo(bottom.dx, bottom.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      fillPaint.color = HSLColor.fromAHSL(1, 190, 0.8, 0.3 + (i % 3) * 0.1).toColor();
      canvas.drawPath(pathBottom, fillPaint);
      canvas.drawPath(pathBottom, linePaint);
    }

    // Highlight
    canvas.drawCircle(
      Offset(-dSize * 0.3, -dSize * 0.5),
      dSize * 0.2,
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
  }

  void _drawStar(Canvas canvas) {
    const size = 14.0;
    final rotateAngle = progress * math.pi * 2 * 0.5;

    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = rotateAngle + (i * 2 * math.pi / 5) - math.pi / 2;
      final innerAngle = outerAngle + math.pi / 5;

      final outerX = math.cos(outerAngle) * size;
      final outerY = math.sin(outerAngle) * size * 0.6;
      final innerX = math.cos(innerAngle) * size * 0.4;
      final innerY = math.sin(innerAngle) * size * 0.6 * 0.4;

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();

    // Gold gradient effect
    final paint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Outline
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.orange.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Shine
    canvas.drawCircle(Offset(-size * 0.2, -size * 0.3), 3, Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  void _drawKey(Canvas canvas) {
    final rotateAngle = math.sin(progress * math.pi * 2) * 0.2;

    canvas.rotate(rotateAngle);

    final paint = Paint()
      ..color = Colors.orange.shade600
      ..style = PaintingStyle.fill;

    // Key head (circle)
    canvas.drawCircle(const Offset(0, -6), 7, paint);
    canvas.drawCircle(const Offset(0, -6), 4, Paint()..color = Colors.orange.shade900);

    // Key shaft
    final shaftPath = Path()
      ..moveTo(-2, -1)
      ..lineTo(-2, 12)
      ..lineTo(2, 12)
      ..lineTo(2, -1)
      ..close();
    canvas.drawPath(shaftPath, paint);

    // Key teeth
    canvas.drawRect(const Rect.fromLTWH(2, 6, 4, 2), paint);
    canvas.drawRect(const Rect.fromLTWH(2, 10, 3, 2), paint);

    // Shine
    canvas.drawCircle(const Offset(-2, -8), 2, Paint()..color = Colors.yellow.withValues(alpha: 0.5));
  }

  void _drawHeart(Canvas canvas) {
    final scale = 1 + math.sin(progress * math.pi * 4) * 0.1;

    canvas.scale(scale);

    final path = Path();
    const double w = 12;
    const double h = 11;

    path.moveTo(0, h * 0.3);
    path.cubicTo(-w * 0.5, -h * 0.3, -w, h * 0.3, 0, h);
    path.moveTo(0, h * 0.3);
    path.cubicTo(w * 0.5, -h * 0.3, w, h * 0.3, 0, h);

    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Outline
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.red.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Shine
    canvas.drawCircle(const Offset(-4, -2), 2.5, Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant _CollectiblePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.type != type;
}
