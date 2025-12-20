import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';
import '../layout/group.dart';
import 'flash_box.dart';

class FlashCube extends StatelessWidget {
  final double size;
  final Color color;
  final v.Vector3? position;
  final v.Vector3? rotation;
  final v.Vector3? scale;
  final String? name;

  const FlashCube({
    super.key,
    this.size = 100,
    this.color = Colors.white,
    this.position,
    this.rotation,
    this.scale,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final half = size / 2;
    return FlashNodes(
      name: name ?? 'Cube',
      position: position,
      rotation: rotation,
      scale: scale,
      children: [
        // Front
        FlashBox(name: 'Front', position: v.Vector3(0, 0, half), width: size, height: size, color: color),
        // Back
        FlashBox(
          name: 'Back',
          position: v.Vector3(0, 0, -half),
          rotation: v.Vector3(0, pi, 0),
          width: size,
          height: size,
          color: color.withValues(alpha: 0.8),
        ),
        // Top
        FlashBox(
          name: 'Top',
          position: v.Vector3(0, half, 0),
          rotation: v.Vector3(-pi / 2, 0, 0),
          width: size,
          height: size,
          color: color.withValues(alpha: 0.9),
        ),
        // Bottom
        FlashBox(
          name: 'Bottom',
          position: v.Vector3(0, -half, 0),
          rotation: v.Vector3(pi / 2, 0, 0),
          width: size,
          height: size,
          color: color.withValues(alpha: 0.7),
        ),
        // Left
        FlashBox(
          name: 'Left',
          position: v.Vector3(-half, 0, 0),
          rotation: v.Vector3(0, -pi / 2, 0),
          width: size,
          height: size,
          color: color.withValues(alpha: 0.75),
        ),
        // Right
        FlashBox(
          name: 'Right',
          position: v.Vector3(half, 0, 0),
          rotation: v.Vector3(0, pi / 2, 0),
          width: size,
          height: size,
          color: color.withValues(alpha: 0.85),
        ),
      ],
    );
  }
}
