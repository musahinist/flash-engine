import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

import '../graph/node.dart';

/// What kind of light an [FLightNode] is.
enum FLightType {
  /// Radiates from the node's position, falling off with distance.
  point,

  /// Parallel rays travelling along the node's forward axis. Position is
  /// irrelevant; only rotation matters.
  directional,

  /// Uniform fill applied to every surface regardless of orientation.
  ambient,
}

/// A light in the scene.
///
/// There used to be two unrelated lighting types: this node, which the engine
/// collected but which computed nothing, and a separate FDirectionalLight that
/// computed shading but which the engine knew nothing about. They are one
/// thing now, and a directional light's direction comes from the node's own
/// rotation, so it can be aimed declaratively like any other node.
class FLightNode extends FNode {
  FLightType type;
  Color color;
  double intensity;

  /// Distance at which a point light has fallen to nothing. Ignored by the
  /// other types.
  double range;

  FLightNode({
    super.name = 'Light',
    this.type = FLightType.point,
    this.color = const Color(0xFFFFFFFF),
    this.intensity = 1.0,
    this.range = 1000,
  });

  /// A directional light aimed along [direction].
  factory FLightNode.directional({
    String name = 'DirectionalLight',
    required Vector3 direction,
    Color color = const Color(0xFFFFFFFF),
    double intensity = 1.0,
  }) {
    final light = FLightNode(name: name, type: FLightType.directional, color: color, intensity: intensity);
    light.aimAt(direction);
    return light;
  }

  /// A uniform fill light.
  factory FLightNode.ambient({
    String name = 'AmbientLight',
    Color color = const Color(0xFFFFFFFF),
    double intensity = 0.3,
  }) {
    return FLightNode(name: name, type: FLightType.ambient, color: color, intensity: intensity);
  }

  /// Points a directional light along [direction] by setting the node's
  /// rotation, so the aim and the transform can never disagree.
  void aimAt(Vector3 direction) {
    final d = direction.normalized();
    transform.rotation.setValues(-math.asin(d.y.clamp(-1.0, 1.0)), math.atan2(d.x, d.z), 0);
    transform.syncExternalMutations();
  }

  /// The direction this light travels in, derived from the node's rotation.
  Vector3 get direction => worldMatrix.forward.normalized();
}

/// Shared shading maths.
///
/// Every primitive used to roll its own light loop with its own fallback —
/// FBox started at `lights.isEmpty ? 1.0 : 0.2` and summed dot products,
/// FSphere picked a single brightest light, FDirectionalLight used a
/// half-Lambert term. Three answers to the same question, so a box and a
/// sphere under identical lights did not agree.
abstract final class FLighting {
  /// Brightness multiplier for a surface, in 0..1.
  ///
  /// [worldNormal] must be normalised. [lights] is the list the engine
  /// collected this frame; ambient entries contribute regardless of
  /// orientation.
  static double brightness(Vector3 worldNormal, Vector3 worldPosition, List<FLightNode> lights) {
    if (lights.isEmpty) return 1.0;

    var ambient = 0.0;
    var direct = 0.0;

    for (final light in lights) {
      switch (light.type) {
        case FLightType.ambient:
          ambient += light.intensity;

        case FLightType.directional:
          // Half-Lambert: softer terminator than raw N·L, and surfaces facing
          // away stay readable instead of going pure black.
          final dot = worldNormal.dot(-light.direction);
          direct += ((dot + 1) / 2) * light.intensity;

        case FLightType.point:
          final toLight = light.worldPosition - worldPosition;
          final distance = toLight.length;
          if (distance > light.range) continue;
          final falloff = light.range <= 0 ? 1.0 : (1 - distance / light.range).clamp(0.0, 1.0);
          final dot = worldNormal.dot(toLight.normalized());
          if (dot > 0) direct += dot * light.intensity * falloff;
      }
    }

    return (ambient + direct).clamp(0.0, 1.0);
  }

  /// Applies [brightness] to a colour, preserving its alpha.
  static Color shade(Color base, Vector3 worldNormal, Vector3 worldPosition, List<FLightNode> lights) {
    final b = brightness(worldNormal, worldPosition, lights);
    return Color.from(
      alpha: base.a,
      red: base.r * b,
      green: base.g * b,
      blue: base.b * b,
      colorSpace: base.colorSpace,
    );
  }
}
