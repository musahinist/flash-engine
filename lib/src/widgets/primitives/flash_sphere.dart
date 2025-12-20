import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../../core/rendering/light.dart';
import '../framework.dart';

class FlashSphere extends FlashNodeWidget {
  final double radius;
  final Color color;
  final ui.Image? texture;

  const FlashSphere({
    super.key,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
    this.radius = 50,
    this.color = Colors.white,
    this.texture,
  });

  @override
  State<FlashSphere> createState() => _FlashSphereState();
}

class _FlashSphereState extends FlashNodeWidgetState<FlashSphere, _SphereNode> {
  @override
  _SphereNode createNode() => _SphereNode(radius: widget.radius, color: widget.color, texture: widget.texture);

  @override
  void applyProperties() {
    super.applyProperties();
    node.radius = widget.radius;
    node.color = widget.color;
    node.texture = widget.texture;
  }
}

class _SphereNode extends FlashNode {
  double radius;
  Color color;
  ui.Image? texture;

  _SphereNode({required this.radius, required this.color, this.texture});

  @override
  void draw(Canvas canvas) {
    Offset lightOffset = Offset(-radius * 0.3, -radius * 0.3);

    if (lights.isNotEmpty) {
      final worldPos = worldPosition;
      FlashLight? bestLight;
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
        // Calculate light direction in world space
        // This is the direction FROM the sphere TO the light
        // We transform this direction into the sphere's LOCAL space to know where to draw the highlight
        final lightDirWorld = (bestLight.worldPosition - worldPos)..normalize();

        // Invert sphere rotation to bring world direction to local space
        // Matrix3 usage for rotation only
        final invRot = worldMatrix.getRotation()..invert();
        final lightDirLocal = invRot.transform(lightDirWorld);

        // Map normalized local direction to screen offset on the 2D circle
        // The Y axis in 3D is -Y in 2D canvas usually (up is -y), but here +Y is down in 2D.
        // lightDirLocal.y is +1.0 for UP in 3D? Standard 3D: Y is Up. Screen: Y is Down.
        // We just project x and y.
        // Flip Y if needed based on coordinate system agreement.
        // Assuming standard Flutter canvas (Y down).
        // If light is at (0, 1, 0) up, we want highlight at top (0, -r).
        // So we negate Y.

        lightOffset = Offset(lightDirLocal.x * radius * 0.6, -lightDirLocal.y * radius * 0.6);
      }
    } else {
      // Fallback ambient logic to prevent pitch black if lights exist but none active,
      // OR to just show original shading if scene has no lighting at all.
      // If lights.isEmpty is true for the whole scene...
      // But _SphereNode only knows about lights passed to it in renderSelf.
      // We'll stick to default lightOffset logic if no lights affect this sphere.
    }

    // 1. Draw Texture (if available), clipped to circle
    if (texture != null) {
      canvas.save();
      final path = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
      canvas.clipPath(path);
      // Determine scale to fit texture? For now just center and scale to cover?
      // Or map spherical? Spherical mapping is hard in 2D canvas.
      // We will just draw the texture centered, scaled to diameter.
      final double scaleX = (radius * 2) / texture!.width;
      final double scaleY = (radius * 2) / texture!.height;
      // Simple planar map (looks okay-ish for front view)
      canvas.scale(scaleX, scaleY);
      // Flip Y if image is upside down due to coordinate system match
      // Texture coordinates usually 0,0 top-left.
      // Canvas 0,0 is center of sphere.
      canvas.drawImage(
        texture!,
        Offset(-texture!.width / 2.0, -texture!.height / 2.0),
        Paint()..filterQuality = ui.FilterQuality.medium,
      );

      canvas.restore();
    }

    // 2. Draw Shading (Gradient) over the texture
    // If no texture, we draw the colored circle with gradient.
    // If texture, we draw gradient with blend mode multiply or just alpha to add shadow volume.

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
      // Overlay shading
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          lightOffset, // Dynamic light source offset
          radius * 1.5,
          [
            Colors.white.withValues(alpha: 0.0), // Highlight transparent
            Colors.black.withValues(alpha: 0.1), // Mid
            Colors.black.withValues(alpha: 0.6), // Shadow edge
            Colors.black87, // Darkest shadow
          ],
          [0.0, 0.5, 0.85, 1.0],
        );
      canvas.drawCircle(Offset.zero, radius, paint);
    }
  }
}
