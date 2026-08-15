import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';

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
    return DemoPage(
      title: 'Tween System',
      subtitle: 'FTweenManager driving node transforms imperatively.',
      controls: [
        Builder(
          builder: (context) => DemoButton(
            label: _isMoving ? 'Animating…' : 'Animate all',
            icon: _isMoving ? Icons.hourglass_empty_rounded : Icons.play_arrow_rounded,
            onPressed: _isMoving ? null : () => _animateAll(context),
          ),
        ),
        DemoButton(label: 'Reset', icon: Icons.refresh_rounded, onPressed: _resetScene),
        DemoPanel(
          title: 'Easing',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in _easings.keys)
                  DemoButton(
                    label: name,
                    selected: name == _selectedEasing,
                    onPressed: () => setState(() => _selectedEasing = name),
                  ),
              ],
            ),
          ],
        ),
      ],
      readouts: [DemoStat(label: 'Easing', value: _selectedEasing)],
      hint: 'Nine cubes tweened at once. The declarative equivalent is Tween Widgets.',
      scene: FScene(
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
                    color: Colors.cyan.withValues(alpha: 0.05),
                  ),
                  // Vertical lines
                  FBox(
                    position: v.Vector3(i * 100.0, 0, 0),
                    width: 1,
                    height: 1000,
                    color: Colors.cyan.withValues(alpha: 0.05),
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
      ),
    );
  }
}
