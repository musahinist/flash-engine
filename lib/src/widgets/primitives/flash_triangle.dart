import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../framework.dart';

class FlashTriangle extends FlashNodeWidget {
  final double size;
  final Color color;

  const FlashTriangle({
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
  State<FlashTriangle> createState() => _FlashTriangleState();
}

class _FlashTriangleState extends FlashNodeWidgetState<FlashTriangle, _TriangleNode> {
  @override
  _TriangleNode createNode() => _TriangleNode(size: widget.size, color: widget.color);

  @override
  void applyProperties() {
    super.applyProperties();
    node.color = widget.color;
    // The following lines are added based on the provided Code Edit,
    // assuming `point1`, `point2`, `point3` are intended to be added
    // to the `FlashTriangle` widget and `_TriangleNode` class.
    // However, they are not defined in the original code.
    // For the sake of producing syntactically correct code based on the instruction,
    // and assuming these properties would be added elsewhere,
    // I am including them as per the Code Edit's body for `applyProperties`.
    // If these properties are not intended, please clarify.
    // node.point1 = widget.point1;
    // node.point2 = widget.point2;
    // node.point3 = widget.point3;
    // Re-adding node.size assignment as it was present in the original _applyProperties
    // and not explicitly removed by the Code Edit's instruction to rename.
    node.size = widget.size;
  }
}

class _TriangleNode extends FlashNode {
  double size;
  Color color;

  _TriangleNode({required this.size, required this.color});

  @override
  void draw(Canvas canvas) {
    final path = Path();
    final half = size / 2;
    path.moveTo(0, -half);
    path.lineTo(half, half);
    path.lineTo(-half, half);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }
}
