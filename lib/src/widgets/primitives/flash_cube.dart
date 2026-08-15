import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';
import '../layout/group.dart';
import 'flash_box.dart';

class FCube extends StatelessWidget {
  final double size;
  final Color color;
  final v.Vector3? position;
  final v.Vector3? rotation;
  final v.Vector3? scale;
  final String? name;

  const FCube({
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
    return FNodes(
      name: name ?? 'Cube',
      position: position,
      rotation: rotation,
      scale: scale,
      children: [
        // Front
        FBox(name: 'Front', position: v.Vector3(0, 0, half), width: size, height: size, color: color),
        // Back
        FBox(
          name: 'Back',
          position: v.Vector3(0, 0, -half),
          rotation: v.Vector3(0, pi, 0),
          width: size,
          height: size,
          color: color.withValues(alpha: 0.8),
        ),
        // Top
        FBox(
          name: 'Top',
          position: v.Vector3(0, half, 0),
          rotation: v.Vector3(-pi / 2, 0, 0),
          width: size,
          height: size,
          color: color.withValues(alpha: 0.9),
        ),
        // Bottom
        FBox(
          name: 'Bottom',
          position: v.Vector3(0, -half, 0),
          rotation: v.Vector3(pi / 2, 0, 0),
          width: size,
          height: size,
          color: color.withValues(alpha: 0.7),
        ),
        // Left
        FBox(
          name: 'Left',
          position: v.Vector3(-half, 0, 0),
          rotation: v.Vector3(0, -pi / 2, 0),
          width: size,
          height: size,
          color: color.withValues(alpha: 0.75),
        ),
        // Right
        FBox(
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

/// Outward face normals of a unit cube, in the engine's Y-up convention.
///
/// `top` and `bottom` were previously (0, -1, 0) and (0, 1, 0) — a Y-down
/// leftover that shaded the top face as though it were the underside.
abstract final class CubeFaceNormals {
  static final v.Vector3 front = v.Vector3(0, 0, 1);
  static final v.Vector3 back = v.Vector3(0, 0, -1);
  static final v.Vector3 top = v.Vector3(0, 1, 0);
  static final v.Vector3 bottom = v.Vector3(0, -1, 0);
  static final v.Vector3 left = v.Vector3(-1, 0, 0);
  static final v.Vector3 right = v.Vector3(1, 0, 0);

  static List<v.Vector3> get all => [front, back, top, bottom, left, right];
  static const List<String> names = ['front', 'back', 'top', 'bottom', 'left', 'right'];
}
