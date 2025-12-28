import 'dart:ui';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart';

/// A simple directional light for basic 3D shading.
///
/// Uses dot product between surface normal and light direction
/// to calculate brightness. This creates realistic shading on 3D objects.
class FDirectionalLight {
  /// Light direction (normalized automatically)
  final Vector3 direction;

  /// Ambient light level (0.0 - 1.0)
  /// This is the minimum brightness for surfaces facing away from light.
  final double ambient;

  /// Light intensity multiplier
  final double intensity;

  late final Vector3 _normalizedDir;

  FDirectionalLight({required Vector3 direction, this.ambient = 0.3, this.intensity = 1.0}) : direction = direction {
    _normalizedDir = direction.normalized();
  }

  /// Common light presets

  /// Top-down light (like noon sun)
  static FDirectionalLight get topDown => FDirectionalLight(direction: Vector3(0, -1, 0), ambient: 0.4);

  /// Isometric light (good for isometric games)
  static FDirectionalLight get isometric => FDirectionalLight(direction: Vector3(0.5, -1.0, -0.5), ambient: 0.3);

  /// Front light (flat, minimal shadows)
  static FDirectionalLight get front => FDirectionalLight(direction: Vector3(0, 0, -1), ambient: 0.5);

  /// Calculate the brightness for a surface with given normal.
  ///
  /// [normal] - Surface normal vector (should be normalized)
  /// [objectRotation] - Optional rotation matrix to transform the normal
  ///
  /// Returns a value from [ambient] to 1.0
  double calculateBrightness(Vector3 normal, [Matrix4? objectRotation]) {
    Vector3 worldNormal = normal;

    // Transform normal by object rotation if provided
    if (objectRotation != null) {
      worldNormal = objectRotation.transformed3(normal);
    }

    // Ensure normalized
    worldNormal = worldNormal.normalized();

    // Dot product gives cosine of angle between vectors
    // -1 = facing away, 0 = perpendicular, 1 = facing light
    final dot = worldNormal.dot(_normalizedDir);

    // Map from [-1, 1] to [ambient, 1]
    final brightness = ambient + ((dot + 1) / 2) * (1 - ambient) * intensity;

    return brightness.clamp(0.0, 1.0);
  }

  /// Apply lighting to a base color.
  ///
  /// [baseColor] - The original color of the surface
  /// [normal] - Surface normal vector
  /// [objectRotation] - Optional rotation matrix
  ///
  /// Returns the shaded color.
  Color applyToColor(Color baseColor, Vector3 normal, [Matrix4? objectRotation]) {
    final brightness = calculateBrightness(normal, objectRotation);

    return Color.fromARGB(
      baseColor.a.toInt(),
      (baseColor.r * brightness).round(),
      (baseColor.g * brightness).round(),
      (baseColor.b * brightness).round(),
    );
  }

  /// Apply lighting using HSL (preserves hue, adjusts lightness).
  ///
  /// This often looks better for colorful objects as it doesn't
  /// desaturate colors in shadows.
  Color applyToColorHSL(Color baseColor, Vector3 normal, [Matrix4? objectRotation]) {
    final brightness = calculateBrightness(normal, objectRotation);

    final hsl = HSLColor.fromColor(baseColor);
    final adjustedLightness = hsl.lightness * (0.5 + brightness * 0.5);

    return hsl.withLightness(adjustedLightness.clamp(0.0, 1.0)).toColor();
  }
}

/// Face normals for a standard cube.
///
/// Use these with [FDirectionalLight.applyToColor] to shade cube faces.
class CubeFaceNormals {
  static final Vector3 front = Vector3(0, 0, -1);
  static final Vector3 back = Vector3(0, 0, 1);
  static final Vector3 top = Vector3(0, -1, 0);
  static final Vector3 bottom = Vector3(0, 1, 0);
  static final Vector3 left = Vector3(-1, 0, 0);
  static final Vector3 right = Vector3(1, 0, 0);

  static final List<Vector3> all = [front, back, top, bottom, left, right];
  static final List<String> names = ['front', 'back', 'top', 'bottom', 'left', 'right'];
}
