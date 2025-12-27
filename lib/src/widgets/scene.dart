import 'package:flutter/widgets.dart';
import '../core/systems/engine.dart';
import '../core/systems/physics.dart';
import '../../flash_view.dart';

/// FScene - A clean separation between Flash 3D scene and Flutter UI overlay.
///
/// The `scene` children are Flash widgets (FCamera, FCircle, FPhysicsBody, etc.)
/// that are automatically Z-sorted by the engine.
///
/// The `overlay` children are regular Flutter widgets (Positioned, Text, etc.)
/// that render on top of the scene.
///
/// Example:
/// ```dart
/// FScene(
///   scene: [
///     FCamera(position: v.Vector3(0, 0, 500)),
///     FCircle(position: v.Vector3(0, 0, 0)),
///   ],
///   overlay: [
///     Positioned(top: 20, left: 20, child: Text('Score: 100')),
///   ],
/// )
/// ```
class FScene extends StatelessWidget {
  /// Flash scene widgets (Z-sorted automatically).
  final List<Widget> scene;

  /// Flutter UI overlay widgets (rendered on top).
  final List<Widget> overlay;

  /// Physics world to use for this scene.
  final FPhysicsSystem? physicsWorld;

  /// If true, auto-updates every frame (60 FPS).
  final bool autoUpdate;

  /// Show FPS and node count debug overlay.
  final bool showDebugOverlay;

  /// Enable keyboard/pointer input capture.
  final bool enableInputCapture;

  /// Called once when the engine is ready for one-time setup.
  final void Function(FEngine engine)? onReady;

  /// Called every frame.
  final VoidCallback? onUpdate;

  const FScene({
    super.key,
    this.scene = const [],
    this.overlay = const [],
    this.physicsWorld,
    this.autoUpdate = true,
    this.showDebugOverlay = true,
    this.enableInputCapture = true,
    this.onReady,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return FView(
      physicsWorld: physicsWorld,
      autoUpdate: autoUpdate,
      showDebugOverlay: showDebugOverlay,
      enableInputCapture: enableInputCapture,
      onReady: onReady,
      onUpdate: onUpdate,
      child: Stack(
        children: [
          // Scene layer - Flash widgets with Z-sorting
          ...scene,
          // Overlay layer - Flutter UI on top
          ...overlay,
        ],
      ),
    );
  }
}
