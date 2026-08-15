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
  _TriangleNode({required double size, required Color color})
    : _size = size,
      _color = color;

  double _size;
  Color _color;

  // A Path is a native SkPath; building one per frame was the most expensive
  // per-primitive allocation in the engine.
  final Path _path = Path();
  final Paint _paint = Paint();
  double _pathSize = double.nan;
  Color? _paintColor;

  double get size => _size;
  set size(double value) => _size = value;

  Color get color => _color;
  set color(Color value) => _color = value;

  @override
  Rect? get bounds => Rect.fromCenter(center: Offset.zero, width: _size, height: _size);

  @override
  void draw(Canvas canvas) {
    if (_pathSize != _size) {
      _pathSize = _size;
      final half = _size / 2;
      _path
        ..reset()
        ..moveTo(0, -half)
        ..lineTo(half, half)
        ..lineTo(-half, half)
        ..close();
    }
    if (_paintColor != _color) {
      _paintColor = _color;
      _paint.color = _color;
    }
    canvas.drawPath(_path, _paint);
  }
}
