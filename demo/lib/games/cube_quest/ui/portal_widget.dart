import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget for rendering portals
class PortalWidget extends StatefulWidget {
  final int colorIndex;
  final double size;

  const PortalWidget({super.key, required this.colorIndex, this.size = 50});

  @override
  State<PortalWidget> createState() => _PortalWidgetState();
}

class _PortalWidgetState extends State<PortalWidget> with SingleTickerProviderStateMixin {
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
          painter: _PortalPainter(colorIndex: widget.colorIndex, progress: _anim.value),
          size: Size(widget.size, widget.size),
        );
      },
    );
  }
}

class _PortalPainter extends CustomPainter {
  final int colorIndex;
  final double progress;

  static const portalColors = [Colors.blue, Colors.orange, Colors.green];

  _PortalPainter({required this.colorIndex, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final color = portalColors[colorIndex % portalColors.length];

    // Outer glow
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.45,
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Swirling rings
    for (int i = 0; i < 4; i++) {
      final ringProgress = (progress + i * 0.25) % 1;
      final ringSize = size.width * 0.2 + ringProgress * size.width * 0.25;
      final alpha = (1 - ringProgress) * 0.6;

      canvas.drawCircle(
        Offset(cx, cy),
        ringSize,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Center vortex
    final vortexPath = Path();
    const spirals = 3;
    for (int s = 0; s < spirals; s++) {
      for (int i = 0; i <= 20; i++) {
        final t = i / 20;
        final angle = t * math.pi * 4 + progress * math.pi * 2 + s * (math.pi * 2 / spirals);
        final radius = t * size.width * 0.35;
        final x = cx + math.cos(angle) * radius;
        final y = cy + math.sin(angle) * radius * 0.6; // Squish for isometric

        if (i == 0) {
          vortexPath.moveTo(x, y);
        } else {
          vortexPath.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(
      vortexPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Center bright spot
    canvas.drawCircle(
      Offset(cx, cy),
      4 + math.sin(progress * math.pi * 4) * 2,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PortalPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colorIndex != colorIndex;
}
