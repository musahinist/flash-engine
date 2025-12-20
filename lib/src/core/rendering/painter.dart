import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import '../graph/node.dart';
import '../systems/particle.dart';
import '../systems/engine.dart';
import 'camera.dart';
import 'light.dart';

class FlashPainter extends CustomPainter {
  final FlashEngine engine;
  final FlashCameraNode? camera;

  FlashPainter({required this.engine, required this.camera, super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // Clip content to viewport bounds to prevent bleeding during transitions
    canvas.clipRect(Offset.zero & size);

    // Viewport Matrix: Map NDC [-1, 1] to Screen [0, width], [0, height]
    final viewportMatrix = Matrix4.identity()
      ..setTranslationRaw(size.width / 2, size.height / 2, 0.0)
      ..scaleByVector3(Vector3(size.width / 2, -size.height / 2, 1.0));

    // Use active camera or fallback
    final activeCam = camera ?? FlashCameraNode(name: 'PainterFallback');
    final projectionMatrix = activeCam.getProjectionMatrix(size.width, size.height);
    final viewMatrix = activeCam.getViewMatrix();
    final cameraMatrix = viewportMatrix * projectionMatrix * viewMatrix;

    final List<FlashNode> flatList = [];
    final List<FlashLightNode> lights = [];
    final List<FlashParticleEmitter> emitters = [];
    _collectNodes(engine.scene, flatList, lights, emitters);

    // Z-Sorting (Painter's Algorithm)
    flatList.sort((a, b) {
      final az = a.worldPosition.z;
      final bz = b.worldPosition.z;
      return bz.compareTo(az);
    });

    for (final node in flatList) {
      node.renderSelf(canvas, cameraMatrix, lights);
    }

    // Render particles (after regular nodes for proper layering)
    for (final emitter in emitters) {
      _renderParticles(canvas, cameraMatrix, emitter);
    }
  }

  void _collectNodes(
    FlashNode node,
    List<FlashNode> list,
    List<FlashLightNode> lights,
    List<FlashParticleEmitter> emitters,
  ) {
    if (node != engine.scene) {
      if (node is FlashLightNode) {
        lights.add(node);
      } else if (node is FlashParticleEmitter) {
        emitters.add(node);
      } else {
        list.add(node);
      }
    }
    for (final child in node.children) {
      _collectNodes(child, list, lights, emitters);
    }
  }

  void _renderParticles(Canvas canvas, Matrix4 cameraMatrix, FlashParticleEmitter emitter) {
    final paint = Paint();

    for (final particle in emitter.particles) {
      // Transform particle position
      final worldPos = particle.position.clone();
      worldPos.applyMatrix4(cameraMatrix);

      // Check if behind camera (w < 0 after perspective)
      if (worldPos.z < 0) continue;

      // Calculate screen position
      final screenX = worldPos.x / worldPos.z;
      final screenY = worldPos.y / worldPos.z;
      final screenSize = particle.currentSize / worldPos.z * 500; // Scale by distance

      // Skip if too small
      if (screenSize < 0.5) continue;

      // Draw particle as circle with gradient
      paint.color = particle.currentColor;
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, screenSize * 0.3);

      canvas.drawCircle(Offset(screenX, screenY), screenSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FlashPainter oldDelegate) => true;
}
