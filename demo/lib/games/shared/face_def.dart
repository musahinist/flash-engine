import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// One face of a rendered cube.
///
/// Shared by the cube games, which each carried a near-identical copy — the
/// only difference between them was whether the field was called `id` or
/// `name`.
class FaceDef {
  FaceDef(this.name, this.baseNormal, this.baseTransform);

  final String name;
  final Vector3 baseNormal;
  final Matrix4 baseTransform;

  /// Depth for painter-order sorting, filled in per frame.
  double? zDepth;

  /// Colour after lighting, filled in per frame.
  Color displayColor = Colors.white;
}
