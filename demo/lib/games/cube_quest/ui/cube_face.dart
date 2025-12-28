import 'package:flutter/material.dart';

/// Cube face widget (reused from original cube game)
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
