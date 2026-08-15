import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

class FTransform {
  VoidCallback? onChanged;

  Vector3 _position = Vector3.all(0);
  Vector3 _rotation = Vector3.all(0); // Euler angles in radians
  Vector3 _scale = Vector3.all(1.0);

  bool _dirty = true;
  final Matrix4 _cachedMatrix = Matrix4.identity();

  Vector3 get position => _position;
  set position(Vector3 value) {
    if (_position == value) return;
    _position = value;
    _dirty = true;
    onChanged?.call();
  }

  Vector3 get rotation => _rotation;
  set rotation(Vector3 value) {
    if (_rotation == value) return;
    _rotation = value;
    _dirty = true;
    onChanged?.call();
  }

  Vector3 get scale => _scale;
  set scale(Vector3 value) {
    if (_scale == value) return;
    _scale = value;
    _dirty = true;
    onChanged?.call();
  }

  bool get isDirty => _dirty;

  // Snapshot of the values last folded into [_cachedMatrix]. The getters hand
  // out the live Vector3s, so `node.transform.position.x += 5` mutates state
  // without going through a setter and without firing [onChanged]. Comparing
  // against this snapshot catches that; it costs nine double compares on the
  // frames where a node is actually synced.
  final Vector3 _syncedPosition = Vector3.all(double.nan);
  final Vector3 _syncedRotation = Vector3.all(double.nan);
  final Vector3 _syncedScale = Vector3.all(double.nan);

  /// Picks up in-place edits to the vectors returned by [position], [rotation]
  /// and [scale], marking the transform dirty and notifying [onChanged].
  ///
  /// Prefer the setters or [translate]/[rotateX]/[rotateY]/[rotateZ], which
  /// notify immediately. This is the safety net for direct field writes.
  void syncExternalMutations() {
    if (_position == _syncedPosition && _rotation == _syncedRotation && _scale == _syncedScale) {
      return;
    }
    _syncedPosition.setFrom(_position);
    _syncedRotation.setFrom(_rotation);
    _syncedScale.setFrom(_scale);
    _dirty = true;
    // Always notify, even if _dirty was already set. _dirty tracks the matrix
    // cache and is only cleared by the `matrix` getter, which the native
    // transform path never calls — gating the callback on it would swallow
    // every in-place edit on a node backed by a native slot.
    onChanged?.call();
  }

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

  FTransform copy() {
    return FTransform()
      ..position = _position.clone()
      ..rotation = _rotation.clone()
      ..scale = _scale.clone();
  }
}
