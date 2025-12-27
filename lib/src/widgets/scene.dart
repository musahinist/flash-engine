import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../core/systems/engine.dart';
import '../core/systems/physics.dart';
import 'framework.dart';
import '../../flash_view.dart';

/// FScene - A clean separation between Flash 3D scene and Flutter UI overlay.
///
/// Use either `scene` (static) or `sceneBuilder` (dynamic with elapsed time).
///
/// The `onInit` callback is called once with viewport size for initial setup.
///
/// Example:
/// ```dart
/// FScene(
///   onInit: (engine, viewport) {
///     // Generate initial data using viewport size
///     _shapes = generateShapes(viewport);
///   },
///   sceneBuilder: (context, elapsed) => [
///     FCamera(...),
///     for (final shape in _shapes) _buildShape(shape, elapsed),
///   ],
///   overlay: [Positioned(...)],
/// )
/// ```
class FScene extends StatefulWidget {
  /// Static Flash scene widgets (Z-sorted automatically).
  /// Use this OR [sceneBuilder], not both.
  final List<Widget>? scene;

  /// Dynamic scene builder with elapsed time (in seconds).
  /// Use this OR [scene], not both.
  final List<Widget> Function(BuildContext context, double elapsed)? sceneBuilder;

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
  /// Use for adding timers, spawners, etc. to the scene tree.
  final void Function(FEngine engine)? onReady;

  /// Called once when viewport size is available.
  /// Use for generating initial objects with viewport-relative positions.
  ///
  /// Example:
  /// ```dart
  /// onInit: (engine, viewport) {
  ///   final worldWidth = viewport.x * 0.5;
  ///   _shapes = List.generate(10, (i) => Shape(x: rnd.nextDouble() * worldWidth));
  /// }
  /// ```
  final void Function(FEngine engine, v.Vector2 viewport)? onInit;

  /// Called every frame.
  final VoidCallback? onUpdate;

  const FScene({
    super.key,
    this.scene,
    this.sceneBuilder,
    this.overlay = const [],
    this.physicsWorld,
    this.autoUpdate = true,
    this.showDebugOverlay = true,
    this.enableInputCapture = true,
    this.onReady,
    this.onInit,
    this.onUpdate,
  }) : assert(scene != null || sceneBuilder != null, 'Either scene or sceneBuilder must be provided');

  @override
  State<FScene> createState() => _FSceneState();
}

class _FSceneState extends State<FScene> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    // Pre-build overlay once (static Flutter UI)
    final overlayStack = widget.overlay.isNotEmpty ? SizedBox.expand(child: Stack(children: widget.overlay)) : null;

    return FView(
      physicsWorld: widget.physicsWorld,
      autoUpdate: widget.autoUpdate,
      showDebugOverlay: widget.showDebugOverlay,
      enableInputCapture: widget.enableInputCapture,
      onReady: widget.onReady,
      onUpdate: widget.onUpdate,
      child: Builder(
        builder: (innerContext) {
          final engine = innerContext.flash;
          if (engine == null) {
            return Stack(
              children: [
                SizedBox.expand(child: Stack(children: widget.scene ?? const [])),
                if (overlayStack != null) overlayStack,
              ],
            );
          }

          // Call onInit once when viewport is available
          if (!_initialized && widget.onInit != null) {
            final viewport = engine.viewportSize;
            if (viewport.x > 0 && viewport.y > 0) {
              widget.onInit!(engine, viewport);
              _initialized = true;
            }
          }

          // If using sceneBuilder, wrap in ListenableBuilder to rebuild every frame
          if (widget.sceneBuilder != null) {
            return Stack(
              children: [
                // Scene layer - rebuilds every frame, fills space
                SizedBox.expand(
                  child: ListenableBuilder(
                    listenable: engine,
                    builder: (ctx, _) {
                      return Stack(children: widget.sceneBuilder!(ctx, engine.elapsed));
                    },
                  ),
                ),
                // Overlay layer - static, doesn't rebuild
                if (overlayStack != null) overlayStack,
              ],
            );
          }

          // Static scene - no need to listen
          return Stack(
            children: [
              SizedBox.expand(child: Stack(children: widget.scene ?? const [])),
              if (overlayStack != null) overlayStack,
            ],
          );
        },
      ),
    );
  }
}
