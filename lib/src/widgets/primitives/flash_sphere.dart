import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../../core/rendering/light.dart';
import '../framework.dart';

class FSphere extends FNodeWidget {
  final double radius;
  final Color color;
  final ui.Image? texture;

  const FSphere({
    super.key,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
    this.radius = 50,
    this.color = Colors.white,
    this.texture,
    // Spheres are billboarded by default to look 3D
    super.billboard = true,
  });

  @override
  State<FSphere> createState() => _FSphereState();
}

class _FSphereState extends FNodeWidgetState<FSphere, _SphereNode> {
  @override
  _SphereNode createNode() => _SphereNode(radius: widget.radius, color: widget.color, texture: widget.texture);

  @override
  void applyProperties([FSphere? oldWidget]) {
    super.applyProperties(oldWidget);
    node.radius = widget.radius;
    node.color = widget.color;
    node.texture = widget.texture;
  }
}

class _SphereNode extends FNode {
  double radius;
  Color color;
  ui.Image? texture;

  _SphereNode({required this.radius, required this.color, this.texture});

  @override
  void draw(Canvas canvas) {
    Offset lightOffset = Offset(-radius * 0.3, -radius * 0.3);

    if (lights.isNotEmpty) {
      final worldPos = worldPosition;
      FLightNode? bestLight;
      double bestIntensity = -1;

      for (final light in lights) {
        final dist = (light.worldPosition - worldPos).length;
        final intensity = light.intensity / (dist * 0.01 + 1.0);
        if (intensity > bestIntensity) {
          bestIntensity = intensity;
          bestLight = light;
        }
      }

      if (bestLight != null) {
        final lightDirWorld = (bestLight.worldPosition - worldPos)..normalize();
        final invRot = worldMatrix.getRotation()..invert();
        final lightDirLocal = invRot.transform(lightDirWorld);
        lightOffset = Offset(lightDirLocal.x * radius * 0.6, lightDirLocal.y * radius * 0.6);
      }
    }

    // 1. Draw Texture (if available), clipped to circle
    if (texture != null) {
      canvas.save();
      final path = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
      canvas.clipPath(path);

      // Extract rotation for texture "roll" effect
      final rot = worldMatrix.getRotation();
      final angle = atan2(rot.entry(0, 2), rot.entry(0, 0));
      canvas.rotate(angle);

      final double scaleX = (radius * 2) / texture!.width;
      final double scaleY = (radius * 2) / texture!.height;

      canvas.scale(scaleX, scaleY);
      canvas.drawImage(
        texture!,
        Offset(-texture!.width / 2.0, -texture!.height / 2.0),
        Paint()..filterQuality = ui.FilterQuality.medium,
      );

      canvas.restore();
    }

    if (texture == null) {
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          lightOffset,
          radius * 1.5,
          [Colors.white, color, color.withValues(alpha: 0.8), Colors.black87],
          [0.0, 0.4, 0.8, 1.0],
        );
      canvas.drawCircle(Offset.zero, radius, paint);
    } else {
      // Overlay shading for textured sphere
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          lightOffset,
          radius * 1.5,
          [
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.8), // Darker shadow edge
            Colors.black,
          ],
          [0.0, 0.5, 0.9, 1.0],
        );
      canvas.drawCircle(Offset.zero, radius, paint);
    }
  }
}
