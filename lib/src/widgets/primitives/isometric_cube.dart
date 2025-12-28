import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// A 3D isometric cube widget with proper face sorting.
///
/// Renders a cube from isometric viewpoint with correct
/// z-ordering (back faces first, front faces last).
///
/// Example:
/// ```dart
/// FIsometricCubeWidget(
///   size: 60,
///   color: Colors.cyan,
///   rotation: Matrix4.rotationY(pi / 4),
/// )
/// ```
class FIsometricCubeWidget extends StatelessWidget {
  /// Size of the cube (all sides equal)
  final double size;

  /// Base color of the cube
  final Color color;

  /// Additional rotation applied to the cube
  final Matrix4? rotation;

  /// Light direction for shading
  final v.Vector3 lightDirection;

  /// Optional widgets to render on specific faces (front, back, left, right, top, bottom)
  final Map<String, Widget>? faceChildren;

  FIsometricCubeWidget({
    super.key,
    required this.size,
    required this.color,
    this.rotation,
    v.Vector3? lightDirection,
    this.faceChildren,
  }) : lightDirection = lightDirection ?? v.Vector3(0.5, -1.0, -0.5);

  @override
  Widget build(BuildContext context) {
    final halfSize = size / 2;
    final normalizedLight = lightDirection.normalized();

    // Isometric camera matrix
    final cameraMatrix = Matrix4.identity()
      ..rotateX(-math.atan(1.0 / math.sqrt(2.0)))
      ..rotateY(-math.pi / 4.0);

    // Combined rotation
    final cubeRotation = rotation ?? Matrix4.identity();

    // Define faces with normals and positions
    final faces = <_FaceData>[
      _FaceData(
        name: 'front',
        normal: v.Vector3(0, 0, 1),
        transform: Matrix4.identity()..setTranslationRaw(0.0, 0.0, halfSize),
      ),
      _FaceData(
        name: 'back',
        normal: v.Vector3(0, 0, -1),
        transform: Matrix4.identity()
          ..setTranslationRaw(0.0, 0.0, -halfSize)
          ..rotateY(math.pi),
      ),
      _FaceData(
        name: 'right',
        normal: v.Vector3(1, 0, 0),
        transform: Matrix4.identity()
          ..setTranslationRaw(halfSize, 0.0, 0.0)
          ..rotateY(math.pi / 2),
      ),
      _FaceData(
        name: 'left',
        normal: v.Vector3(-1, 0, 0),
        transform: Matrix4.identity()
          ..setTranslationRaw(-halfSize, 0.0, 0.0)
          ..rotateY(-math.pi / 2),
      ),
      _FaceData(
        name: 'top',
        normal: v.Vector3(0, -1, 0),
        transform: Matrix4.identity()
          ..setTranslationRaw(0.0, -halfSize, 0.0)
          ..rotateX(math.pi / 2),
      ),
      _FaceData(
        name: 'bottom',
        normal: v.Vector3(0, 1, 0),
        transform: Matrix4.identity()
          ..setTranslationRaw(0.0, halfSize, 0.0)
          ..rotateX(-math.pi / 2),
      ),
    ];

    // Calculate Z-depth and color for each face
    for (final face in faces) {
      // Transform for depth sorting
      final viewTransform = Matrix4.copy(cameraMatrix)
        ..multiply(cubeRotation)
        ..multiply(face.transform);

      face.zDepth = viewTransform.getTranslation().z;

      // Calculate lighting
      final worldNormal = cubeRotation.transformed3(face.normal);
      final intensity = (worldNormal.dot(normalizedLight) + 1.0) / 2.0;

      // Convert to HSL for proper shading
      final hsl = HSLColor.fromColor(color);
      final adjustedLightness = (hsl.lightness + intensity * 0.3).clamp(0.0, 1.0);
      face.displayColor = hsl.withLightness(adjustedLightness).toColor();
    }

    // Sort by Z-depth (back to front)
    faces.sort((a, b) => a.zDepth.compareTo(b.zDepth));

    // Combine camera and object rotation for final render transform
    final renderTransform = Matrix4.copy(cameraMatrix)..multiply(cubeRotation);

    // Build widget tree
    return Transform(
      alignment: Alignment.center,
      transform: renderTransform,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: faces.map((face) {
            return Positioned.fill(
              child: Center(
                child: Transform(
                  transform: face.transform,
                  alignment: Alignment.center,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: face.displayColor,
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1),
                    ),
                    child: faceChildren != null && faceChildren!.containsKey(face.name)
                        ? faceChildren![face.name]
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FaceData {
  final String name;
  final v.Vector3 normal;
  final Matrix4 transform;
  double zDepth = 0;
  Color displayColor = Colors.white;

  _FaceData({required this.name, required this.normal, required this.transform});
}

/// Extension to transform Vector3 by Matrix4
extension Matrix4Vector3Ext on Matrix4 {
  v.Vector3 transformed3(v.Vector3 vec) {
    final v4 = v.Vector4(vec.x, vec.y, vec.z, 0.0);
    final result = this * v4;
    return v.Vector3(result.x, result.y, result.z);
  }
}
