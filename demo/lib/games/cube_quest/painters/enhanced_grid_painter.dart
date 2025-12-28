import 'package:flutter/material.dart';

/// Enhanced grid painter with neon cyberpunk style
class EnhancedGridPainter extends CustomPainter {
  final double cameraX;
  final double cameraZ;
  final double gridSize;
  final Color primaryColor;
  final Color accentColor;

  const EnhancedGridPainter({
    required this.cameraX,
    required this.cameraZ,
    required this.gridSize,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfGrid = gridSize / 2.0;
    const range = 1400.0;
    final halfRange = range / 2.0;

    final centerX = size.width / 2.0;
    final centerY = size.height / 2.0;

    final double offsetX = -(cameraX % gridSize);
    final double offsetZ = -(cameraZ % gridSize);

    // Main grid lines
    final gridPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    // Accent lines (every 5 cells)
    final accentPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;

    // Center crosshair glow
    final centerGlowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    canvas.drawCircle(Offset(centerX, centerY), 150, centerGlowPaint);

    int lineIndex = 0;
    for (double i = -halfRange; i <= halfRange + gridSize; i += gridSize) {
      final x = i + offsetX + halfGrid;
      final z = i + offsetZ + halfGrid;

      // Determine if this is an accent line (every 5 cells)
      final isAccentX = ((cameraX / gridSize).floor() + lineIndex) % 5 == 0;
      final isAccentZ = ((cameraZ / gridSize).floor() + lineIndex) % 5 == 0;

      if (x >= -halfRange && x <= halfRange) {
        canvas.drawLine(
          Offset(centerX + x, centerY - halfRange),
          Offset(centerX + x, centerY + halfRange),
          isAccentX ? accentPaint : gridPaint,
        );
      }
      if (z >= -halfRange && z <= halfRange) {
        canvas.drawLine(
          Offset(centerX - halfRange, centerY + z),
          Offset(centerX + halfRange, centerY + z),
          isAccentZ ? accentPaint : gridPaint,
        );
      }

      lineIndex++;
    }

    // Draw origin marker if visible
    final originX = -cameraX + halfGrid;
    final originZ = -cameraZ + halfGrid;

    if (originX.abs() < halfRange && originZ.abs() < halfRange) {
      final originPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset(centerX + originX, centerY + originZ), gridSize * 0.3, originPaint);
    }
  }

  @override
  bool shouldRepaint(covariant EnhancedGridPainter oldDelegate) =>
      oldDelegate.cameraX != cameraX ||
      oldDelegate.cameraZ != cameraZ ||
      oldDelegate.gridSize != gridSize ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.accentColor != accentColor;
}
