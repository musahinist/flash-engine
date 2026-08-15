import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../framework.dart';

class FCircle extends FNodeWidget {
  final double radius;
  final Color color;

  const FCircle({
    super.key,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
    this.radius = 50,
    this.color = Colors.white,
    super.billboard,
  });

  @override
  State<FCircle> createState() => _FCircleState();
}

class _FCircleState extends FNodeWidgetState<FCircle, _CircleNode> {
  @override
  _CircleNode createNode() => _CircleNode(radius: widget.radius, color: widget.color);

  @override
  void applyProperties([FCircle? oldWidget]) {
    super.applyProperties(oldWidget);
    node.color = widget.color;
    node.radius = widget.radius;
  }
}

class _CircleNode extends FNode {
  _CircleNode({required this.radius, required this.color});

  double radius;
  Color color;

  // Rebuilt only when the colour changes, rather than allocated every frame.
  // The check lives in draw() rather than in a setter, so a caller writing the
  // same colour repeatedly costs nothing either way.
  final Paint _paint = Paint();
  Color? _paintColor;

  @override
  Rect? get bounds => Rect.fromCircle(center: Offset.zero, radius: radius);

  @override
  void draw(Canvas canvas) {
    if (_paintColor != color) {
      _paintColor = color;
      _paint.color = color;
    }
    canvas.drawCircle(Offset.zero, radius, _paint);
  }
}
