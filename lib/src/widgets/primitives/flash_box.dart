import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../framework.dart';

class FlashBox extends FlashNodeWidget {
  final double width;
  final double height;
  final Color color;

  const FlashBox({
    super.key,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    this.width = 1.0,
    this.height = 1.0,
    this.color = Colors.white,
    super.child,
    super.billboard,
  });

  @override
  State<FlashBox> createState() => _FlashBoxState();
}

class _FlashBoxState extends FlashNodeWidgetState<FlashBox, _BoxNode> {
  @override
  _BoxNode createNode() => _BoxNode(width: widget.width, height: widget.height, color: widget.color);

  @override
  void applyProperties([FlashBox? oldWidget]) {
    super.applyProperties(oldWidget);
    node.width = widget.width;
    node.height = widget.height;
    node.color = widget.color;
  }
}

class _BoxNode extends FlashNode {
  double width;
  double height;
  Color color;

  final Paint _paint = Paint();
  Color? _lastColor;
  double _lastBrightness = -1.0;

  _BoxNode({required this.width, required this.height, required this.color});

  @override
  void draw(Canvas canvas) {
    // Default to unlit (full brightness) if no lights are present
    double brightness = lights.isEmpty ? 1.0 : 0.2; // 0.2 is ambient for lit scenes

    if (lights.isNotEmpty) {
      final worldPos = worldPosition;
      final normal = worldMatrix.forward..normalize();

      for (final light in lights) {
        final lightPos = light.worldPosition;
        final lightDir = (lightPos - worldPos)..normalize();
        final dot = normal.dot(lightDir);
        if (dot > 0) {
          brightness += dot * light.intensity;
        }
      }
    }

    brightness = brightness.clamp(0.0, 1.0);

    // Update paint if color or brightness changed
    if (color != _lastColor || brightness != _lastBrightness) {
      _lastColor = color;
      _lastBrightness = brightness;
      _paint.color = Color.from(
        alpha: color.a,
        red: color.r * brightness,
        green: color.g * brightness,
        blue: color.b * brightness,
      );
    }

    // Draw centered rect with width/height
    // Reuse Rect? Since width/height might change rarely, we could cache it, but Rect creation is cheap.
    // However, recreating Rect every frame is what we want to avoid if possible.
    // But width/height are mutable. Let's just create Rect here, it's a struct basically.
    // Paint is the heavy one.
    final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    canvas.drawRect(rect, _paint);
  }

  @override
  Rect? get bounds => Rect.fromCenter(center: Offset.zero, width: width, height: height);
}
