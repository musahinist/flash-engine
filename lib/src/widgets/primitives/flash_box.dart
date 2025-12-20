import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../../core/rendering/light.dart'; // For lighting
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
  });

  @override
  State<FlashBox> createState() => _FlashBoxState();
}

class _FlashBoxState extends FlashNodeWidgetState<FlashBox, _BoxNode> {
  @override
  _BoxNode createNode() => _BoxNode(width: widget.width, height: widget.height, color: widget.color);

  @override
  void applyProperties() {
    super.applyProperties();
    node.width = widget.width;
    node.height = widget.height;
    node.color = widget.color;
  }
}

class _BoxNode extends FlashNode {
  double width;
  double height;
  Color color;

  _BoxNode({required this.width, required this.height, required this.color});

  @override
  void draw(Canvas canvas) {
    // Default to unlit (full brightness) if no lights are present
    double brightness = lights.isEmpty ? 1.0 : 0.2; // 0.2 is ambient for lit scenes

    if (lights.isNotEmpty) {
      final worldPos = worldPosition;
      // Normal of the rect in world space.
      // Assuming initial normal is (0, 0, 1) locally?
      // A 2D rect usually faces Z axis in 2D plane (XY plane). Normal is +Z.
      // So forward vector is correct.
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
    final drawColor = Color.from(
      alpha: color.a,
      red: color.r * brightness,
      green: color.g * brightness,
      blue: color.b * brightness,
    );

    // Draw centered rect with width/height
    final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    final paint = Paint()..color = drawColor;
    canvas.drawRect(rect, paint);

    // Optional: Draw border for visibility (scaled relative to size?)
    // If width/height is 1.0, border 0.05 is visible.
    // If width/height is 400, border 0.05 is tiny.
    // Let's make border optional or logic based?
    // For "Physics Demo", visual clarity is helpful.
    // Fixed strokeWidth might disappear at scale.
    // We'll keep it simple for now or remove border if lighting handles depth.
    // Lighting handles visual cue. I'll remove border for cleaner look,
    // or make it proportional.
    // Users preferred generic primitives without borders usually.
    /*
    final border = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.min(width, height) * 0.02;
    canvas.drawRect(rect, border);
    */
  }
}
