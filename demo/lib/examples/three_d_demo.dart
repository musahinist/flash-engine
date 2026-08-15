import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';

/// The primitives with real depth: [FCube], [FSphere], [FBox] and [FLabel].
///
/// FRONT and BACK sit either side of the origin, so the painter's-algorithm
/// sort has something visible to get right. Slide the camera back and the
/// perspective divide separates them further.
class ThreeDDemo extends StatefulWidget {
  const ThreeDDemo({super.key});

  @override
  State<ThreeDDemo> createState() => _ThreeDDemoState();
}

class _ThreeDDemoState extends State<ThreeDDemo> {
  double _distance = 800;
  bool _spin = true;

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: '3D Primitives',
      subtitle: 'FCube, FSphere, FBox and FLabel, sorted back to front.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Camera distance',
              value: _distance,
              min: 350,
              max: 2000,
              fractionDigits: 0,
              onChanged: (value) => setState(() => _distance = value),
            ),
          ],
        ),
        DemoToggle(label: 'Rotate', value: _spin, onChanged: (v) => setState(() => _spin = v)),
      ],
      hint: 'FRONT and BACK straddle the origin — that is the sort working.',
      scene: FView(
        // No AnimationController: the engine already has a clock, and FAnimated
        // hands it over. One fewer thing with a lifecycle to get wrong.
        child: FAnimated(
          builder: (context, elapsed) {
            final t = _spin ? elapsed : 0.0;
            return FNodes(
              children: [
                FCamera(position: v.Vector3(0, 0, _distance), fov: 60),
                FCube(
                  size: 150,
                  color: Colors.cyanAccent,
                  position: v.Vector3(-200, 0, 0),
                  rotation: v.Vector3(t, t * 0.5, 0),
                ),
                FCube(
                  size: 100,
                  color: Colors.purpleAccent,
                  position: v.Vector3(200, 100, -100),
                  rotation: v.Vector3(-t * 0.7, t, t * 0.3),
                ),
                FSphere(
                  radius: 60,
                  color: Colors.orangeAccent,
                  position: v.Vector3(0, 150 + sin(t) * 50, 50),
                  name: 'Ball1',
                ),
                FSphere(
                  radius: 40,
                  color: Colors.pinkAccent,
                  position: v.Vector3(150 * cos(t), -200, 150 * sin(t)),
                  name: 'Ball2',
                ),
                FBox(
                  position: v.Vector3(0, -300, 0),
                  rotation: v.Vector3(pi / 2, 0, 0),
                  width: 1000,
                  height: 1000,
                  color: Colors.white10,
                ),
                FLabel(
                  text: 'FRONT',
                  position: v.Vector3(0, 0, 200),
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
                FLabel(
                  text: 'BACK',
                  position: v.Vector3(0, 0, -200),
                  style: const TextStyle(color: Colors.white54, fontSize: 24),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
