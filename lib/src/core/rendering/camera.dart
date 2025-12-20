import 'package:vector_math/vector_math_64.dart';
import '../graph/node.dart';

class FlashCamera extends FlashNode {
  double fov = 60.0;
  double near = 0.1;
  double far = 2000.0;

  FlashCamera({super.name = 'Camera'}) {
    // Default position back
    transform.position.setValues(0, 0, 1000);
  }

  Matrix4 getProjectionMatrix(double width, double height) {
    if (width <= 0 || height <= 0) return Matrix4.identity();
    final aspect = width / height;
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
}
