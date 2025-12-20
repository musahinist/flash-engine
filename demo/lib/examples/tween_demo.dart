import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class TweenDemoExample extends StatefulWidget {
  const TweenDemoExample({super.key});

  @override
  State<TweenDemoExample> createState() => _TweenDemoExampleState();
}

class _TweenDemoExampleState extends State<TweenDemoExample> {
  String _selectedEasing = 'easeOutQuad';
  final List<FlashTween> _activeTweens = [];

  final Map<String, EasingFunction> _easings = {
    'linear': FlashEasing.linear,
    'easeInQuad': FlashEasing.easeInQuad,
    'easeOutQuad': FlashEasing.easeOutQuad,
    'easeInOutQuad': FlashEasing.easeInOutQuad,
    'easeInCubic': FlashEasing.easeInCubic,
    'easeOutCubic': FlashEasing.easeOutCubic,
    'easeInOutCubic': FlashEasing.easeInOutCubic,
    'easeInBack': FlashEasing.easeInBack,
    'easeOutBack': FlashEasing.easeOutBack,
    'easeInOutBack': FlashEasing.easeInOutBack,
    'easeOutElastic': FlashEasing.easeOutElastic,
    'easeOutBounce': FlashEasing.easeOutBounce,
  };

  double _activeWallX = 150.0;
  v.Vector3 _boxPosition = v.Vector3(-150, 0, 0);
  v.Vector3 _boxScale = v.Vector3(1, 1, 1);
  double _boxRotation = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(title: const Text('Tween Animation Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Flash(
        autoUpdate: true,
        onUpdate: () {
          final dt = 1 / 60.0;
          for (int i = _activeTweens.length - 1; i >= 0; i--) {
            _activeTweens[i].update(dt);
            if (_activeTweens[i].isCompleted) {
              _activeTweens.removeAt(i);
            }
          }
        },
        child: Builder(
          builder: (context) {
            final engineWidget = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>();
            final engine = engineWidget?.engine;

            return Stack(
              children: [
                // Camera
                FlashCamera(position: v.Vector3(0, 0, 800), fov: 60),

                // Responsive range calculator
                ListenableBuilder(
                  listenable: engine ?? ChangeNotifier(),
                  builder: (context, _) {
                    final camera = engine?.activeCamera;
                    if (camera != null && engine != null) {
                      final bounds = camera.getWorldBounds(camera.transform.position.z.abs(), engine.viewportSize);
                      _activeWallX = bounds.x - 60; // Leave margin for box size
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Animated box
                FlashCube(
                  position: _boxPosition,
                  scale: _boxScale,
                  rotation: v.Vector3(0, _boxRotation, 0),
                  size: 60,
                  color: Colors.cyanAccent,
                ),
                // ...
                // (Rest of the controls remain the same, I will just update the animation methods below)

                // Controls
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Easing selector
                        const Text(
                          '🎬 Select Easing',
                          style: TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _easings.keys.map((name) {
                              final isSelected = _selectedEasing == name;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedEasing = name),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.cyanAccent : Colors.white24,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Animation buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildButton('Move', Icons.open_with, _animateMove),
                            _buildButton('Scale', Icons.zoom_out_map, _animateScale),
                            _buildButton('Rotate', Icons.rotate_right, _animateRotate),
                            _buildButton('Combo', Icons.auto_awesome, _animateCombo),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _animateMove() {
    final targetX = _boxPosition.x < 0 ? _activeWallX : -_activeWallX;
    final tween = FlashVector3Tween(
      from: _boxPosition.clone(),
      to: v.Vector3(targetX, 0, 0),
      duration: 1.0,
      easing: _easings[_selectedEasing]!,
      onUpdate: (v) => _boxPosition = v,
    );
    tween.start();
    _activeTweens.add(tween);
  }

  void _animateScale() {
    final targetScale = _boxScale.x > 1.5 ? 1.0 : 2.0;
    final tween = FlashVector3Tween(
      from: _boxScale.clone(),
      to: v.Vector3(targetScale, targetScale, targetScale),
      duration: 0.8,
      easing: _easings[_selectedEasing]!,
      onUpdate: (v) => _boxScale = v,
    );
    tween.start();
    _activeTweens.add(tween);
  }

  void _animateRotate() {
    final tween = FlashDoubleTween(
      from: _boxRotation,
      to: _boxRotation + 3.14159,
      duration: 1.0,
      easing: _easings[_selectedEasing]!,
      onUpdate: (v) => _boxRotation = v,
    );
    tween.start();
    _activeTweens.add(tween);
  }

  void _animateCombo() {
    // Move
    final moveTween = FlashVector3Tween(
      from: _boxPosition.clone(),
      to: v.Vector3(_boxPosition.x < 0 ? _activeWallX : -_activeWallX, 50, 0),
      duration: 1.5,
      easing: _easings[_selectedEasing]!,
      yoyo: true,
      repeatCount: 1,
      onUpdate: (v) => _boxPosition = v,
    );
    moveTween.start();
    _activeTweens.add(moveTween);

    // Scale
    final scaleTween = FlashVector3Tween(
      from: _boxScale.clone(),
      to: v.Vector3(1.5, 1.5, 1.5),
      duration: 0.75,
      easing: _easings[_selectedEasing]!,
      yoyo: true,
      repeatCount: 1,
      onUpdate: (v) => _boxScale = v,
    );
    scaleTween.start();
    _activeTweens.add(scaleTween);

    // Rotate
    final rotateTween = FlashDoubleTween(
      from: _boxRotation,
      to: _boxRotation + 6.28318,
      duration: 1.5,
      easing: FlashEasing.linear,
      onUpdate: (v) => _boxRotation = v,
    );
    rotateTween.start();
    _activeTweens.add(rotateTween);
  }
}
