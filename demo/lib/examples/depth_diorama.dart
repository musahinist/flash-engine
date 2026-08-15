import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';

/// Parallax out of nothing but Z.
///
/// Six bands of scenery sit at different depths. Nothing here computes a
/// parallax factor — the perspective projection does it, because that is what
/// perspective is. Move the camera sideways and the near trees sweep past while
/// the stars barely shift.
class DepthDioramaExample extends StatefulWidget {
  const DepthDioramaExample({super.key});

  @override
  State<DepthDioramaExample> createState() => _DepthDioramaExampleState();
}

class _DepthDioramaExampleState extends State<DepthDioramaExample> {
  double _pan = 0;
  bool _drift = true;

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: '2.5D Diorama',
      subtitle: 'Six depth bands. The parallax is the projection, not a factor.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Camera X',
              value: _pan,
              min: -400,
              max: 400,
              fractionDigits: 0,
              onChanged: (value) => setState(() {
                _pan = value;
                _drift = false;
              }),
            ),
          ],
        ),
        DemoToggle(
          label: 'Drift',
          value: _drift,
          onChanged: (value) => setState(() => _drift = value),
        ),
      ],
      hint: 'Slide the camera: near trees sweep, distant stars barely move.',
      scene: FView(
        child: FAnimated(
          builder: (context, elapsed) {
            final t = elapsed;
            final cameraX = _drift ? sin(elapsed * 0.25) * 320 : _pan;

            return FNodes(
              children: [
                FCamera(position: v.Vector3(cameraX, 0, 800), fov: 60),
                FLight(position: v.Vector3(300, 400, 600), color: Colors.white, intensity: 1.2),
                FLight(
                  position: v.Vector3(-300, 200, 400),
                  color: Colors.blueAccent,
                  intensity: 0.6,
                ),

                // Sky, z -800..-600
                for (int i = 0; i < 30; i++)
                  FBox(
                    position: v.Vector3(
                      (Random(i).nextDouble() - 0.5) * 2000,
                      (Random(i + 100).nextDouble() - 0.5) * 1000,
                      -800 + Random(i + 200).nextDouble() * 200,
                    ),
                    width: 3,
                    height: 3,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),

                // Mountains, z -350
                for (int i = 0; i < 6; i++)
                  FTriangle(
                    position: v.Vector3((i - 2.5) * 350, -100, -350),
                    size: 400,
                    color: const Color(0xFF1a3c5a),
                  ),

                // Mid trees, z -100
                for (int i = 0; i < 10; i++)
                  _tree(v.Vector3((i - 4.5) * 180, -150, -100 - i * 5.0), const Color(0xFF2d5a27), 120),

                // Subject, orbiting through the middle depths
                FSphere(
                  position: v.Vector3(
                    sin(t) * 350,
                    cos(t * 0.8) * 100 - 50,
                    cos(t * 0.7) * 250 + 150,
                  ),
                  radius: 25,
                  color: Colors.cyanAccent,
                ),

                for (int i = 0; i < 5; i++)
                  FBox(
                    position: v.Vector3(sin(t + i) * 300, cos(t * 0.5 + i) * 80, 100 + i * 40.0),
                    width: 30,
                    height: 30,
                    color: Color.lerp(Colors.purple, Colors.orange, i / 4)!,
                    rotation: v.Vector3(t + i, t * 0.7, t * 0.5),
                  ),

                // Foreground trees, z 400+
                for (int i = 0; i < 8; i++)
                  _tree(v.Vector3((i - 3.5) * 200, -200, 400 + i * 20.0), const Color(0xFF3a6b35), 180),

                for (int i = 0; i < 12; i++)
                  FBox(
                    position: v.Vector3(
                      (i - 5.5) * 130,
                      -230,
                      500 + (Random(i + 500).nextDouble() - 0.5) * 100,
                    ),
                    width: 40 + Random(i + 600).nextDouble() * 30,
                    height: 30 + Random(i + 700).nextDouble() * 20,
                    color: const Color(0xFF4a4a4a),
                    rotation: v.Vector3(0, 0, Random(i + 800).nextDouble() * 0.5),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tree(v.Vector3 position, Color color, double height) {
    return FNodes(
      position: position,
      children: [
        FBox(
          position: v.Vector3(0, -height * 0.3, 0),
          width: height * 0.15,
          height: height * 0.6,
          color: const Color(0xFF3d2817),
        ),
        FTriangle(position: v.Vector3(0, height * 0.2, 0), size: height * 0.8, color: color),
      ],
    );
  }
}
