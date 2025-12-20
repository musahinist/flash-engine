import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

class FlashTransform {
  VoidCallback? onChanged;

  Vector3 _position = Vector3.all(0);
  Vector3 _rotation = Vector3.all(0); // Euler angles in radians
  Vector3 _scale = Vector3.all(1.0);

  bool _dirty = true;
  final Matrix4 _cachedMatrix = Matrix4.identity();

  Vector3 get position => _position;
  set position(Vector3 value) {
    _position = value;
    _dirty = true;
    onChanged?.call();
  }

  Vector3 get rotation => _rotation;
  set rotation(Vector3 value) {
    _rotation = value;
    _dirty = true;
    onChanged?.call();
  }

  Vector3 get scale => _scale;
  set scale(Vector3 value) {
    _scale = value;
    _dirty = true;
    onChanged?.call();
  }

  bool get isDirty => _dirty;

  void translate(double x, double y, [double z = 0]) {
    _position.x += x;
    _position.y += y;
    _position.z += z;
    _dirty = true;
    onChanged?.call();
  }

  void rotateX(double angle) {
    _rotation.x += angle;
    _dirty = true;
    onChanged?.call();
  }

  void rotateY(double angle) {
    _rotation.y += angle;
    _dirty = true;
    onChanged?.call();
  }

  void rotateZ(double angle) {
    _rotation.z += angle;
    _dirty = true;
    onChanged?.call();
  }

  void setScale(double s) {
    _scale.setValues(s, s, s);
    _dirty = true;
    onChanged?.call();
  }

  Matrix4 get matrix {
    if (_dirty) {
      _cachedMatrix.setFromTranslationRotationScale(
        _position,
        Quaternion.fromRotation(
          Matrix3.rotationX(_rotation.x) * Matrix3.rotationY(_rotation.y) * Matrix3.rotationZ(_rotation.z),
        ),
        _scale,
      );
      _dirty = false;
    }
    return _cachedMatrix;
  }

  FlashTransform copy() {
    return FlashTransform()
      ..position = _position.clone()
      ..rotation = _rotation.clone()
      ..scale = _scale.clone();
  }
}
