import 'package:flutter/widgets.dart';
import '../graph/node.dart';
import '../graph/scene.dart';
import 'camera.dart';
import 'light.dart';

class FlashPainter extends CustomPainter {
  final FlashScene scene;
  final FlashCamera? camera;

  FlashPainter({required this.scene, required this.camera, super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // Viewport Matrix: Map NDC [-1, 1] to Screen [0, width], [0, height]
    final viewportMatrix = Matrix4.identity()
      ..translate(size.width / 2, size.height / 2)
      ..scale(size.width / 2, -size.height / 2, 1.0);

    // Use active camera or fallback
    final activeCam = camera ?? FlashCamera(name: 'PainterFallback');
    final projectionMatrix = activeCam.getProjectionMatrix(size.width, size.height);
    final viewMatrix = activeCam.getViewMatrix();
    final cameraMatrix = viewportMatrix * projectionMatrix * viewMatrix;

    final List<FlashNode> flatList = [];
    final List<FlashLight> lights = [];
    _collectNodes(scene, flatList, lights);

    // Z-Sorting (Painter's Algorithm)
    flatList.sort((a, b) {
      final az = a.worldPosition.z;
      final bz = b.worldPosition.z;
      return bz.compareTo(az);
    });

    for (final node in flatList) {
      node.renderSelf(canvas, cameraMatrix, lights);
    }
  }

  void _collectNodes(FlashNode node, List<FlashNode> list, List<FlashLight> lights) {
    if (node != scene) {
      if (node is FlashLight) {
        lights.add(node);
      } else {
        list.add(node);
      }
    }
    for (final child in node.children) {
      _collectNodes(child, list, lights);
    }
  }

  @override
  bool shouldRepaint(covariant FlashPainter oldDelegate) => true;
}
