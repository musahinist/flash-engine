import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../framework.dart';

class FlashCircle extends FlashNodeWidget {
  final double radius;
  final Color color;

  const FlashCircle({
    super.key,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
    this.radius = 50,
    this.color = Colors.white,
  });

  @override
  State<FlashCircle> createState() => _FlashCircleState();
}

class _FlashCircleState extends FlashNodeWidgetState<FlashCircle, _CircleNode> {
  @override
  _CircleNode createNode() => _CircleNode(radius: widget.radius, color: widget.color);

  @override
  void applyProperties() {
    super.applyProperties();
    node.color = widget.color;
    node.radius = widget.radius;
  }
}

class _CircleNode extends FlashNode {
  double radius;
  Color color;

  _CircleNode({required this.radius, required this.color});

  @override
  void draw(Canvas canvas) {
    canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
  }
}
