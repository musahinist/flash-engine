import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import '../graph/node.dart';

class FCameraNode extends FNode {
  double fov = 60.0;
  double near = 0.1;
  double far = 2000.0;
  bool isOrthographic = false;
  double orthographicSize = 400.0; // Half-height in ortho mode

  FCameraNode({super.name = 'Camera'}) {
    // Default position back
    transform.position.setValues(0, 0, 1000);
  }

  Matrix4 getProjectionMatrix(double width, double height) {
    if (width <= 0 || height <= 0) return Matrix4.identity();
    final aspect = width / height;

    if (isOrthographic) {
      final halfH = orthographicSize;
      final halfW = halfH * aspect;
      return makeOrthographicMatrix(-halfW, halfW, -halfH, halfH, near, far);
    }

    return makePerspectiveMatrix(radians(fov), aspect, near, far);
  }

  Matrix4 getViewMatrix() {
    // The view matrix is the inverse of the camera's world matrix.
    // However, fast inversion for rigid body transforms (rotation + translation) is often preferred.
    // For now, full matrix inversion is safe and correct.
    final matrix = Matrix4.copy(worldMatrix);
    matrix.invert();
    return matrix;
  }

  /// Calculates the visible world size at a given distance from the camera
  /// Returns half-width and half-height as a Vector2
  Vector2 getWorldBounds(double distance, Vector2 viewportSize) {
    if (viewportSize.x <= 0 || viewportSize.y <= 0) return Vector2.zero();

    final aspect = viewportSize.x / viewportSize.y;
    final halfHeight = distance * tan(radians(fov / 2));
    final halfWidth = halfHeight * aspect;

    return Vector2(halfWidth, halfHeight);
  }
}
