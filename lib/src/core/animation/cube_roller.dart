import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

/// Direction for cube rolling animation.
enum RollDirection {
  /// Roll towards +X (screen right in isometric)
  east,

  /// Roll towards -X (screen left in isometric)
  west,

  /// Roll towards +Z (screen down-right in isometric)
  south,

  /// Roll towards -Z (screen up-left in isometric)
  north,
}

/// Helper class for cube rolling animation with edge pivot.
///
/// Unlike simple rotation, rolling pivots around the edge of the cube,
/// creating a realistic rolling effect. The cube "tips over" its edge.
class FCubeRoller {
  /// Size of the cube (width = height = depth)
  final double cubeSize;

  const FCubeRoller({required this.cubeSize});

  double get halfSize => cubeSize / 2;

  /// Calculate the transformation matrix for a rolling animation.
  ///
  /// [direction] - Which direction to roll
  /// [progress] - Animation progress (0.0 to 1.0)
  /// [startX], [startZ] - Starting grid position in world units
  ///
  /// Returns the full transformation matrix including translation and rotation.
  Matrix4 getRollTransform({
    required RollDirection direction,
    required double progress,
    required double startX,
    required double startZ,
  }) {
    // Determine axis and angle based on direction
    Vector3 axis;
    Vector3 pivotOffset;
    double angle;

    switch (direction) {
      case RollDirection.east: // +X
        axis = Vector3(0, 0, 1);
        pivotOffset = Vector3(halfSize, halfSize, 0);
        angle = progress * math.pi / 2;
        break;
      case RollDirection.west: // -X
        axis = Vector3(0, 0, 1);
        pivotOffset = Vector3(-halfSize, halfSize, 0);
        angle = -progress * math.pi / 2;
        break;
      case RollDirection.south: // +Z
        axis = Vector3(1, 0, 0);
        pivotOffset = Vector3(0, halfSize, halfSize);
        angle = -progress * math.pi / 2;
        break;
      case RollDirection.north: // -Z
        axis = Vector3(1, 0, 0);
        pivotOffset = Vector3(0, halfSize, -halfSize);
        angle = progress * math.pi / 2;
        break;
    }

    // Create rotation matrix around the pivot point
    final rotMat = Matrix4.identity()..rotate(axis, angle);

    // Calculate new position after rotation around pivot
    final rotatedPivot = rotMat.transformed3(-pivotOffset);
    final newPos = Vector3(startX, -halfSize, startZ) + pivotOffset + rotatedPivot;

    // Build final transform: translate to position, then rotate
    return Matrix4.identity()
      ..setTranslation(newPos)
      ..multiply(rotMat);
  }

  /// Calculate the transformation matrix for a jumping animation.
  ///
  /// [direction] - Which direction to jump
  /// [progress] - Animation progress (0.0 to 1.0)
  /// [startX], [startZ] - Starting grid position in world units
  /// [jumpDistance] - How far to jump (typically 2 * cubeSize)
  /// [jumpHeight] - Peak height of the jump arc
  ///
  /// Returns the full transformation matrix.
  Matrix4 getJumpTransform({
    required RollDirection direction,
    required double progress,
    required double startX,
    required double startZ,
    double? jumpDistance,
    double? jumpHeight,
  }) {
    final dist = jumpDistance ?? cubeSize * 2;
    final height = jumpHeight ?? cubeSize * 1.2;

    // Direction vector
    Vector3 dirVector;
    Vector3 rotAxis;
    double rotAngle;

    switch (direction) {
      case RollDirection.east:
        dirVector = Vector3(1, 0, 0);
        rotAxis = Vector3(0, 0, 1);
        rotAngle = progress * math.pi;
        break;
      case RollDirection.west:
        dirVector = Vector3(-1, 0, 0);
        rotAxis = Vector3(0, 0, 1);
        rotAngle = -progress * math.pi;
        break;
      case RollDirection.south:
        dirVector = Vector3(0, 0, 1);
        rotAxis = Vector3(1, 0, 0);
        rotAngle = -progress * math.pi;
        break;
      case RollDirection.north:
        dirVector = Vector3(0, 0, -1);
        rotAxis = Vector3(1, 0, 0);
        rotAngle = progress * math.pi;
        break;
    }

    // Parabolic arc for Y position
    final yOffset = -math.sin(math.pi * progress) * height;

    // Calculate position
    final pos = Vector3(startX, -halfSize, startZ) + (dirVector * (progress * dist)) + Vector3(0, yOffset, 0);

    // Build transform
    final rotMat = Matrix4.identity()..rotate(rotAxis, rotAngle);

    return Matrix4.identity()
      ..setTranslation(pos)
      ..multiply(rotMat);
  }

  /// Accumulate rotation after a completed roll.
  ///
  /// Call this when a roll animation completes to update the
  /// cube's persistent rotation state.
  Matrix4 accumulateRotation(Matrix4 current, RollDirection direction, {bool isJump = false}) {
    Vector3 axis;
    double angle;

    switch (direction) {
      case RollDirection.east:
        axis = Vector3(0, 0, 1);
        angle = math.pi / 2;
        break;
      case RollDirection.west:
        axis = Vector3(0, 0, 1);
        angle = -math.pi / 2;
        break;
      case RollDirection.south:
        axis = Vector3(1, 0, 0);
        angle = -math.pi / 2;
        break;
      case RollDirection.north:
        axis = Vector3(1, 0, 0);
        angle = math.pi / 2;
        break;
    }

    if (isJump) angle *= 2; // Full rotation for jump

    final rotMat = Matrix4.identity()..rotate(axis, angle);
    return rotMat.multiplied(current);
  }
}
