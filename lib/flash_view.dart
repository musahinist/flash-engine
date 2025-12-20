import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'src/core/systems/engine.dart';
import 'src/core/rendering/painter.dart';
import 'src/core/systems/physics.dart';
import 'src/core/graph/node.dart';
import 'src/widgets/framework.dart';

class Flash extends StatefulWidget {
  final Widget child;
  final FlashPhysicsSystem? physicsWorld;
  final bool showDebugOverlay;

  /// If false, Flash will not capture pointer/keyboard input,
  /// allowing Flutter's native gesture system (GestureDetector) to work
  final bool enableInputCapture;

  final VoidCallback? onUpdate;

  const Flash({
    super.key,
    required this.child,
    this.physicsWorld,
    this.showDebugOverlay = true,
    this.enableInputCapture = true,
    this.onUpdate,
  });

  @override
  State<Flash> createState() => _FlashState();
}

class _FlashState extends State<Flash> {
  late final FlashEngine engine;
  final ValueNotifier<String> _debugInfo = ValueNotifier('');
  double _lastDebugUpdate = 0;

  @override
  void initState() {
    super.initState();
    engine = FlashEngine();
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
  }

  int _countNodes(FlashNode node) {
    int count = 1;
    for (final child in node.children) {
      count += _countNodes(child);
    }
    return count;
  }

  @override
  void didUpdateWidget(Flash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.physicsWorld != oldWidget.physicsWorld) {
      engine.physicsWorld = widget.physicsWorld;
    }
  }

  @override
  void dispose() {
    engine.stop();
    engine.dispose();
    _debugInfo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Update engine viewport size before building children
        engine.viewportSize.setValues(constraints.maxWidth, constraints.maxHeight);

        // Core content with painting
        Widget content = Stack(
          children: [
            SizedBox.expand(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: FlashPainter(engine: engine, camera: engine.activeCamera, repaint: engine),
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

        return InheritedFlashNode(node: engine.scene, engine: engine, child: content);
      },
    );
  }
}
