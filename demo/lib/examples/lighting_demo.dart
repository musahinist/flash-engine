import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FLight]: a point light the shaded primitives respond to.
///
/// Lighting here is per-primitive, not a render pass — each node decides how to
/// use the lights it is given. `FSphere` builds a radial gradient offset toward
/// the light; the flat primitives tint. That is why a sphere reads as round and
/// a box does not.
class LightingDemo extends StatefulWidget {
  const LightingDemo({super.key});

  @override
  State<LightingDemo> createState() => _LightingDemoState();
}

class _LightingDemoState extends State<LightingDemo> {
  double _intensity = 1.5;
  double _orbit = 400;
  bool _moving = true;
  Color _colour = Colors.white;

  static const List<({String name, Color colour})> _colours = [
    (name: 'white', colour: Colors.white),
    (name: 'warm', colour: Color(0xFFFFB870)),
    (name: 'cyan', colour: DemoTheme.accent),
    (name: 'violet', colour: DemoTheme.accentAlt),
  ];

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Dynamic Light',
      subtitle: 'FLight drives the shaded primitives; each one shades itself.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Intensity',
              value: _intensity,
              min: 0,
              max: 4,
              fractionDigits: 2,
              onChanged: (value) => setState(() => _intensity = value),
            ),
            DemoSlider(
              label: 'Orbit radius',
              value: _orbit,
              min: 100,
              max: 800,
              fractionDigits: 0,
              onChanged: (value) => setState(() => _orbit = value),
            ),
          ],
        ),
        DemoToggle(
          label: 'Orbit',
          value: _moving,
          onChanged: (value) => setState(() => _moving = value),
        ),
        DemoPanel(
          title: 'Colour',
          children: [
            for (final entry in _colours)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DemoButton(
                  label: entry.name,
                  tint: entry.colour,
                  selected: _colour == entry.colour,
                  width: 190,
                  onPressed: () => setState(() => _colour = entry.colour),
                ),
              ),
          ],
        ),
      ],
      hint: 'The sphere shades; the cube tints. Lighting is per-primitive.',
      scene: FView(
        child: FAnimated(
          builder: (context, elapsed) {
            final t = _moving ? elapsed : 0.0;
            final lightPos = v.Vector3(
              sin(t) * _orbit,
              sin(t * 0.5) * 200,
              cos(t) * _orbit,
            );

            return FNodes(
              children: [
                FLight(
                  name: 'PointLight',
                  position: lightPos,
                  intensity: _intensity,
                  color: _colour,
                ),

                // Where the light is, so the shading has a visible cause.
                FCircle(position: lightPos, radius: 10, color: _colour, name: 'LightViz'),

                FCube(
                  size: 150,
                  color: Colors.blue,
                  position: v.Vector3(-150, 0, 0),
                  rotation: v.Vector3(t * 0.2, t * 0.3, 0),
                ),
                FSphere(
                  radius: 80,
                  color: Colors.purple,
                  position: v.Vector3(150, 0, 0),
                  name: 'ShadedBall',
                ),
                FBox(
                  position: v.Vector3(0, -250, 0),
                  rotation: v.Vector3(pi / 2, 0, 0),
                  width: 1200,
                  height: 1200,
                  color: Colors.grey[900]!,
                  name: 'Floor',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
