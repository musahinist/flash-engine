import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../framework.dart';

class FTriangle extends FNodeWidget {
  final double size;
  final Color color;

  const FTriangle({
    super.key,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
    this.size = 100,
    this.color = Colors.white,
  });

  @override
  State<FTriangle> createState() => _FTriangleState();
}

class _FTriangleState extends FNodeWidgetState<FTriangle, _TriangleNode> {
  @override
  _TriangleNode createNode() => _TriangleNode(size: widget.size, color: widget.color);

  @override
  void applyProperties([FTriangle? oldWidget]) {
    super.applyProperties(oldWidget);
    node.color = widget.color;
    node.size = widget.size;
  }
}

class _TriangleNode extends FNode {
  _TriangleNode({required this.size, required this.color});

  double size;
  Color color;

  // A Path is a native SkPath; building one per frame was the most expensive
  // per-primitive allocation in the engine.
  final Path _path = Path();
  final Paint _paint = Paint();
  double _pathSize = double.nan;
  Color? _paintColor;

  @override
  Rect? get bounds => Rect.fromCenter(center: Offset.zero, width: size, height: size);

  @override
  void draw(Canvas canvas) {
    if (_pathSize != size) {
      _pathSize = size;
      final half = size / 2;
      _path
        ..reset()
        ..moveTo(0, -half)
        ..lineTo(half, half)
        ..lineTo(-half, half)
        ..close();
    }
    if (_paintColor != color) {
      _paintColor = color;
      _paint.color = color;
    }
    canvas.drawPath(_path, _paint);
  }
}
