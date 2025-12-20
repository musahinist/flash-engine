import 'package:flutter/material.dart';
import 'src/core/systems/engine.dart';
import 'src/core/rendering/painter.dart';
import 'src/core/systems/physics.dart'; // For FlashPhysicsWorld
import 'src/widgets/framework.dart';

class Flash extends StatefulWidget {
  final Widget child;
  final FlashPhysicsWorld? physicsWorld;
  final bool showDebugOverlay;

  const Flash({super.key, required this.child, this.physicsWorld, this.showDebugOverlay = true});

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
      // Throttle debug UI updates to 2 times per second
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      if (now - _lastDebugUpdate > 0.5) {
        _debugInfo.value = '${engine.fps.toStringAsFixed(1)} FPS | ${engine.scene.children.length} Nodes';
        _lastDebugUpdate = now;
      }
    };
    engine.start();
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
    return InheritedFlashNode(
      node: engine.scene,
      engine: engine,
      child: Stack(
        children: [
          SizedBox.expand(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: FlashPainter(scene: engine.scene, camera: engine.activeCamera, repaint: engine),
                child: widget.child,
              ),
            ),
          ),
          // Throttled Debug Overlay
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
      ),
    );
  }
}
