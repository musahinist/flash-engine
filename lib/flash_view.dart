import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'src/core/systems/engine.dart';
import 'src/core/rendering/painter.dart';
import 'src/core/systems/physics.dart';
import 'src/core/graph/node.dart';
import 'src/widgets/framework.dart';

class FView extends StatefulWidget {
  final Widget child;
  final FPhysicsSystem? physicsWorld;
  final bool showDebugOverlay;

  /// If false, Flash will not capture pointer/keyboard input,
  /// allowing Flutter's native gesture system (GestureDetector) to work
  final bool enableInputCapture;

  final VoidCallback? onUpdate;

  /// Called once when the engine is ready, before the first frame.
  /// Use this for one-time scene setup like adding timers, spawners, etc.
  ///
  /// Example:
  /// ```dart
  /// FView(
  ///   onReady: (engine) {
  ///     engine.scene.addChild(FTimer(waitTime: 2.0, autoStart: true));
  ///   },
  ///   child: ...
  /// )
  /// ```
  final void Function(FEngine engine)? onReady;

  /// If true, Flash will automatically trigger a rebuild of its child
  /// on every engine tick (60 FPS). Useful for simple declarative animations
  /// without needing an AnimationController or setState manually.
  final bool autoUpdate;

  const FView({
    super.key,
    required this.child,
    this.physicsWorld,
    this.showDebugOverlay = true,
    this.enableInputCapture = true,
    this.onUpdate,
    this.onReady,
    this.autoUpdate = true,
  });

  @override
  State<FView> createState() => _FViewState();
}

class _FViewState extends State<FView> {
  late final FEngine engine;
  final ValueNotifier<String> _debugInfo = ValueNotifier('');
  double _lastDebugUpdate = 0;

  @override
  void initState() {
    super.initState();
    engine = FEngine();
    engine.physicsWorld = widget.physicsWorld;
    engine.onUpdate = () {
      widget.onUpdate?.call();
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      if (now - _lastDebugUpdate > 0.5) {
        int totalNodes = _countNodes(engine.scene);
        _debugInfo.value = '${engine.fps.toStringAsFixed(1)} FPS | $totalNodes Nodes';
        _lastDebugUpdate = now;
      }
    };
    engine.start();

    // Call onReady callback for one-time scene setup
    widget.onReady?.call(engine);
  }

  int _countNodes(FNode node) {
    int count = 1;
    for (final child in node.children) {
      count += _countNodes(child);
    }
    return count;
  }

  @override
  void didUpdateWidget(FView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.physicsWorld != oldWidget.physicsWorld) {
      engine.physicsWorld = widget.physicsWorld;
    }
    if (widget.onUpdate != oldWidget.onUpdate) {
      engine.onUpdate = () {
        widget.onUpdate?.call();
        final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
        if (now - _lastDebugUpdate > 0.5) {
          int totalNodes = _countNodes(engine.scene);
          _debugInfo.value = '${engine.fps.toStringAsFixed(1)} FPS | $totalNodes Nodes';
          _lastDebugUpdate = now;
        }
      };
    }
  }

  @override
  void dispose() {
    engine.stop();
    engine.dispose();
    _debugInfo.dispose();
    super.dispose();
  }

  Widget _buildContent(BuildContext context, BoxConstraints constraints) {
    // Update engine viewport size
    engine.viewportSize.setValues(constraints.maxWidth, constraints.maxHeight);

    // Core content with painting
    Widget content = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        SizedBox.expand(
          child: RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              painter: FPainter(engine: engine, camera: engine.activeCamera, repaint: engine),
              child: widget.child,
            ),
          ),
        ),
        // Debug Overlay
        if (widget.showDebugOverlay)
          Positioned(
            right: 20,
            top: 40,
            child: ValueListenableBuilder<String>(
              valueListenable: _debugInfo,
              builder: (context, info, _) {
                if (info.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    info,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );

    // Conditionally wrap with input handling
    if (widget.enableInputCapture) {
      content = Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          engine.input.handleKeyEvent(event);
          return KeyEventResult.handled;
        },
        child: Listener(
          onPointerDown: engine.input.onPointerDown,
          onPointerUp: engine.input.onPointerUp,
          onPointerMove: engine.input.onPointerMove,
          onPointerHover: engine.input.onPointerHover,
          onPointerCancel: engine.input.onPointerCancel,
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              engine.input.onPointerScroll(event);
            }
          },
          child: content,
        ),
      );
    }

    return InheritedFNode(node: engine.scene, engine: engine, child: content);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.autoUpdate) {
          return ListenableBuilder(listenable: engine, builder: (context, _) => _buildContent(context, constraints));
        }
        return _buildContent(context, constraints);
      },
    );
  }
}
