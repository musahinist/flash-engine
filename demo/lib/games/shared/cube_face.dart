import 'package:flutter/material.dart';

/// A single cube face. Shared by the cube games, which held identical copies.
class CubeFace extends StatelessWidget {
  final Color color;
  final double size;

  const CubeFace({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1.0),
      ),
    );
  }
}
