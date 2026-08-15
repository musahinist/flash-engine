import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// Positional audio: six sources around a moving listener.
///
/// [FAudioPlayer] with `is3D` attenuates and pans by the distance between the
/// source's world position and the camera, so orbiting the camera is enough to
/// sweep through them.
class ThreeDAudioDemo extends StatefulWidget {
  const ThreeDAudioDemo({super.key});

  @override
  State<ThreeDAudioDemo> createState() => _ThreeDAudioDemoState();
}

class _ThreeDAudioDemoState extends State<ThreeDAudioDemo> {
  double _radius = 300;
  double _speed = 1;
  bool _playing = true;

  @override
  Widget build(BuildContext context) {
    // Built here rather than as a const list because Vector3 is not const.
    final sources = <({v.Vector3 position, Color colour, String label})>[
      (position: v.Vector3(0, 0, -200), colour: DemoTheme.danger, label: 'front'),
      (position: v.Vector3(0, 0, 200), colour: DemoTheme.accent, label: 'back'),
      (position: v.Vector3(-200, 0, 0), colour: DemoTheme.positive, label: 'left'),
      (position: v.Vector3(200, 0, 0), colour: DemoTheme.warning, label: 'right'),
      (position: v.Vector3(0, 200, 0), colour: DemoTheme.accentAlt, label: 'up'),
      (position: v.Vector3(0, -200, 0), colour: const Color(0xFFFF9E64), label: 'down'),
    ];

    return DemoPage(
      title: '3D Audio',
      subtitle: 'Six looping sources; the camera is the listener.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Orbit radius',
              value: _radius,
              min: 80,
              max: 700,
              fractionDigits: 0,
              onChanged: (value) => setState(() => _radius = value),
            ),
            DemoSlider(
              label: 'Orbit speed',
              value: _speed,
              min: 0,
              max: 3,
              fractionDigits: 2,
              suffix: 'x',
              onChanged: (value) => setState(() => _speed = value),
            ),
          ],
        ),
        DemoToggle(
          label: 'Playing',
          value: _playing,
          onChanged: (value) => setState(() => _playing = value),
        ),
        DemoPanel(
          title: 'Sources',
          children: [
            DemoLegend(
              entries: [for (final s in sources) (color: s.colour, label: s.label)],
            ),
          ],
        ),
      ],
      hint: 'Wear headphones. Attenuation runs from 50 to 500 units.',
      scene: FView(
        child: FAnimated(
          builder: (context, elapsed) {
            // The camera is driven from the engine's own clock. This used to
            // register an update listener inside build() that called setState,
            // so every rebuild added another listener and each one triggered
            // the next rebuild — the list grew without bound.
            final t = elapsed * _speed;

            return FNodes(
              children: [
                FCamera(
                  position: v.Vector3(
                    cos(t) * _radius,
                    sin(t * 0.5) * 100,
                    sin(t) * _radius + 400,
                  ),
                  fov: 60,
                ),

                FSphere(position: v.Vector3(0, 0, 0), radius: 10, color: Colors.white),

                for (final source in sources)
                  FNodes(
                    position: source.position,
                    children: [
                      FSphere(radius: 20, color: source.colour),
                      FLabel(
                        text: source.label,
                        position: v.Vector3(0, 36, 0),
                        style: TextStyle(color: source.colour, fontSize: 13),
                      ),
                      if (_playing)
                        FAudioPlayer(
                          assetPath: 'asset/demo.mp3',
                          autoplay: true,
                          loop: true,
                          is3D: true,
                          minDistance: 50,
                          maxDistance: 500,
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
