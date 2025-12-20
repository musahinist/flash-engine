import 'package:flutter/material.dart';
import '../../core/rendering/camera.dart';
import '../../core/systems/engine.dart';
import '../framework.dart';

class FlashCameraWidget extends FlashNodeWidget {
  final double fov;
  final double near;
  final double far;

  const FlashCameraWidget({
    super.key,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
    this.fov = 60.0,
    this.near = 0.1,
    this.far = 2000.0,
  });

  @override
  State<FlashCameraWidget> createState() => _FlashCameraWidgetState();
}

class _FlashCameraWidgetState extends FlashNodeWidgetState<FlashCameraWidget, FlashCamera> {
  FlashEngine? _engine; // Cache engine reference for safe disposal

  @override
  FlashCamera createNode() => FlashCamera()
    ..fov = widget.fov
    ..near = widget.near
    ..far = widget.far;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache engine reference and register camera
    _engine = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>()?.engine;
    _engine?.registerCamera(node);
  }

  @override
  void dispose() {
    // Use cached engine reference (safe during disposal)
    _engine?.unregisterCamera(node);
    super.dispose();
  }

  @override
  void applyProperties() {
    super.applyProperties();
    node.fov = widget.fov;
    node.near = widget.near;
    node.far = widget.far;
  }
}
