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
  _CircleNode({required double radius, required Color color})
    : _radius = radius,
      _color = color;

  double _radius;
  Color _color;

  // Rebuilt only when the colour changes, rather than allocated every frame.
  final Paint _paint = Paint();
  Color? _paintColor;

  double get radius => _radius;
  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
  }

  Color get color => _color;
  set color(Color value) => _color = value;

  @override
  Rect? get bounds => Rect.fromCircle(center: Offset.zero, radius: _radius);

  @override
  void draw(Canvas canvas) {
    if (_paintColor != _color) {
      _paintColor = _color;
      _paint.color = _color;
    }
    canvas.drawCircle(Offset.zero, _radius, _paint);
  }
}
