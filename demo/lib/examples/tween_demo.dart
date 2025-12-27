import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class TweenDemoExample extends StatefulWidget {
  const TweenDemoExample({super.key});

  @override
  State<TweenDemoExample> createState() => _TweenDemoExampleState();
}

class _TweenDemoExampleState extends State<TweenDemoExample> {
  String _selectedEasing = 'easeOutBack';
  bool _isMoving = false;

  final Map<String, EasingFunction> _easings = {
    'easeOutQuad': FEasing.easeOutQuad,
    'easeInOutQuad': FEasing.easeInOutQuad,
    'easeOutCubic': FEasing.easeOutCubic,
    'easeOutExpo': FEasing.easeOutExpo,
    'easeOutBack': FEasing.easeOutBack,
    'easeInOutBack': FEasing.easeInOutBack,
    'easeOutElastic': FEasing.easeOutElastic,
    'easeOutBounce': FEasing.easeOutBounce,
  };

  // State for animated objects
  final List<v.Vector3> _cubePositions = List.generate(
    9,
    (i) => v.Vector3((i % 3 - 1) * 120.0, (i ~/ 3 - 1) * 120.0, 0),
  );

  final List<v.Vector3> _cubeScales = List.generate(9, (_) => v.Vector3(1, 1, 1));
  final List<v.Vector3> _cubeRotations = List.generate(9, (_) => v.Vector3.zero());
  final List<Color> _cubeColors = List.generate(9, (i) => HSLColor.fromAHSL(1, i * 40.0, 0.8, 0.6).toColor());

  void _animateAll(BuildContext context) {
    if (_isMoving) return;
    _isMoving = true;

    final engine = context.flash;
    if (engine == null) return;

    final easing = _easings[_selectedEasing]!;

    for (int i = 0; i < 9; i++) {
      final delay = i * 0.05; // Staggered start

      // Position animation
      final originalPos = _cubePositions[i].clone();
      final targetPos = originalPos + v.Vector3(0, 0, 150);

      engine.tweenManager.add(
        FVector3Tween(
          from: originalPos,
          to: targetPos,
          duration: 1.0,
          delay: delay,
          easing: easing,
          yoyo: true,
          repeatCount: 1,
          onUpdate: (val) => setState(() => _cubePositions[i] = val),
        ),
      );

      // Scale animation
      engine.tweenManager.add(
        FVector3Tween(
          from: v.Vector3(1, 1, 1),
          to: v.Vector3(1.5, 1.5, 1.5),
          duration: 0.8,
          delay: delay,
          easing: FEasing.easeOutExpo,
          yoyo: true,
          repeatCount: 1,
          onUpdate: (val) => setState(() => _cubeScales[i] = val),
        ),
      );

      // Rotation animation
      engine.tweenManager.add(
        FVector3Tween(
          from: v.Vector3.zero(),
          to: v.Vector3(pi, (i % 2 == 0) ? pi : -pi, 0),
          duration: 1.2,
          delay: delay,
          easing: easing,
          onUpdate: (val) => setState(() => _cubeRotations[i] = val),
          onComplete: i == 8 ? () => setState(() => _isMoving = false) : null,
        ),
      );
    }
  }

  void _resetScene() {
    setState(() {
      for (int i = 0; i < 9; i++) {
        _cubePositions[i] = v.Vector3((i % 3 - 1) * 120.0, (i ~/ 3 - 1) * 120.0, 0);
        _cubeScales[i] = v.Vector3(1, 1, 1);
        _cubeRotations[i] = v.Vector3.zero();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030308),
      body: FScene(
        sceneBuilder: (ctx, elapsed) {
          // Calculate orbiting light position
          final lightOrbitRadius = 400.0;
          final lightX = cos(elapsed * 1.5) * lightOrbitRadius;
          final lightY = sin(elapsed * 1.5) * 200.0;
          final lightZ = sin(elapsed * 1.5) * lightOrbitRadius;
          final lightPos = v.Vector3(lightX, lightY, lightZ);

          return [
            // Kinetic Camera
            FCamera(position: v.Vector3(sin(elapsed * 0.1) * 100, cos(elapsed * 0.15) * 50, 850), fov: 60),

            // Dynamic Point Light
            FLight(position: lightPos, intensity: 1.5, color: Colors.white),

            // Light Source Visual (A small glowing orb)
            FNodes(
              position: lightPos,
              children: [FSphere(radius: 10, color: Colors.white)],
            ),

            // Subtle Ground Grid
            FNodes(
              position: v.Vector3(0, -300, 0),
              rotation: v.Vector3(-pi / 2, 0, 0),
              children: [
                for (int i = -5; i <= 5; i++) ...[
                  // Horizontal lines
                  FBox(
                    position: v.Vector3(0, i * 100.0, 0),
                    width: 1000,
                    height: 1,
                    color: Colors.cyan.withOpacity(0.05),
                  ),
                  // Vertical lines
                  FBox(
                    position: v.Vector3(i * 100.0, 0, 0),
                    width: 1,
                    height: 1000,
                    color: Colors.cyan.withOpacity(0.05),
                  ),
                ],
              ],
            ),

            // Neon Cube Grid
            for (int i = 0; i < 9; i++)
              FCube(
                position: _cubePositions[i],
                rotation: _cubeRotations[i],
                scale: _cubeScales[i],
                size: 60,
                color: _cubeColors[i],
              ),
          ];
        },
        overlay: [
          // Header
          Positioned(
            top: 60,
            left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '3D LIGHTING & TWEEN',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                Text(
                  'DYNAMIC POINT LIGHT SHADOWS',
                  style: TextStyle(
                    color: Colors.amberAccent.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Easing Selector Sidebar
          Positioned(
            right: 20,
            top: 100,
            bottom: 120,
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: _easings.keys.map((name) {
                    final isSelected = _selectedEasing == name;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEasing = name),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.cyanAccent.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.transparent),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? Colors.cyanAccent : Colors.white60,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Row(
              children: [
                // Back Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white54),
                ),
                const Spacer(),
                // Main Action Button
                Builder(
                  builder: (context) => GestureDetector(
                    onTap: () => _animateAll(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)]),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: Colors.amberAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: -5),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_isMoving ? Icons.hourglass_empty : Icons.lightbulb_outline, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            _isMoving ? 'ANIMATING...' : 'LIGHT & TWEEN',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Reset Button
                IconButton(
                  onPressed: _resetScene,
                  icon: const Icon(Icons.refresh, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
