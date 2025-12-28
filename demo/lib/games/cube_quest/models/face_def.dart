import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// Face definition for 3D cube rendering
class FaceDef {
  final String name;
  final Vector3 baseNormal;
  final Matrix4 baseTransform;
  double? zDepth;
  Color displayColor = Colors.white;

  FaceDef(this.name, this.baseNormal, this.baseTransform);
}
