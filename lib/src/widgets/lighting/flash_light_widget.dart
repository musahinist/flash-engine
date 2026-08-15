import 'package:flutter/material.dart';
import '../../core/rendering/light.dart';
import '../framework.dart';

class FLight extends FNodeWidget {
  final Color color;
  final double intensity;

  /// Point, directional or ambient. Directional lights are aimed by this
  /// widget's `rotation`.
  final FLightType type;

  /// Distance at which a point light falls to nothing.
  final double range;

  const FLight({
    super.key,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    this.color = Colors.white,
    this.intensity = 1.0,
    this.type = FLightType.point,
    this.range = 1000,
  });

  @override
  State<FLight> createState() => _FLightState();
}

class _FLightState extends FNodeWidgetState<FLight, FLightNode> {
  @override
  FLightNode createNode() =>
      FLightNode(type: widget.type, color: widget.color, intensity: widget.intensity, range: widget.range);

  @override
  void applyProperties([FLight? oldWidget]) {
    super.applyProperties(oldWidget);
    node.color = widget.color;
    node.intensity = widget.intensity;
    node.type = widget.type;
    node.range = widget.range;
  }
}
