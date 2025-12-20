import 'package:flutter/material.dart';
import '../../core/rendering/light.dart';
import '../framework.dart';

class FlashLightWidget extends FlashNodeWidget {
  final Color color;
  final double intensity;

  const FlashLightWidget({
    super.key,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    this.color = Colors.white,
    this.intensity = 1.0,
  });

  @override
  State<FlashLightWidget> createState() => _FlashLightWidgetState();
}

class _FlashLightWidgetState extends FlashNodeWidgetState<FlashLightWidget, FlashLight> {
  @override
  FlashLight createNode() => FlashLight(color: widget.color, intensity: widget.intensity);

  @override
  void applyProperties() {
    super.applyProperties();
    node.color = widget.color;
    node.intensity = widget.intensity;
  }
}
