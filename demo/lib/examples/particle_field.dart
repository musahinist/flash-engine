import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// Emitters attached to moving nodes.
///
/// An [FParticles] emitter is a node, so parenting it to something that moves
/// is all it takes to leave a trail — the emission origin follows the parent's
/// world transform and nothing has to push positions at it.
///
/// This demo used to be two hundred `FBox` nodes moved by hand from an
/// `AnimationController` whose value wrapped every second, so the whole field
/// snapped back to the origin once a second. It now uses the particle system it
/// is named after.
class ParticleFieldExample extends StatefulWidget {
  const ParticleFieldExample({super.key});

  @override
  State<ParticleFieldExample> createState() => _ParticleFieldExampleState();
}

class _ParticleFieldExampleState extends State<ParticleFieldExample> {
  static const List<({String name, Color colour})> _emitters = [
    (name: 'A', colour: DemoTheme.accent),
    (name: 'B', colour: DemoTheme.accentAlt),
    (name: 'C', colour: DemoTheme.warning),
  ];

  double _rate = 900;
  double _speed = 1;
  bool _showPaths = true;

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Particle Field',
      subtitle: 'Emitters parented to moving nodes; the trail follows for free.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Emission rate',
              value: _rate,
              min: 100,
              max: 4000,
              fractionDigits: 0,
              suffix: '/s',
              onChanged: (value) => setState(() => _rate = value),
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
          label: 'Show emitters',
          value: _showPaths,
          onChanged: (value) => setState(() => _showPaths = value),
        ),
      ],
      readouts: [
        DemoStat(label: 'Emitters', value: '${_emitters.length}'),
        DemoStat(label: 'Combined rate', value: '${(_rate * _emitters.length).round()}/s'),
      ],
      hint: 'Each emitter is a child of its orbiting node — it is never told where it is.',
      scene: FView(
        child: FAnimated(
          builder: (context, elapsed) {
            final t = elapsed * _speed;

            return FNodes(
              children: [
                FCamera(position: v.Vector3(0, 0, 900), fov: 60),

                for (int i = 0; i < _emitters.length; i++)
                  FNodes(
                    position: v.Vector3(
                      cos(t * (0.6 + i * 0.25) + i * 2.1) * (200 + i * 90),
                      sin(t * (0.8 - i * 0.15) + i * 1.3) * (150 + i * 60),
                      sin(t * 0.4 + i) * 120,
                    ),
                    children: [
                      if (_showPaths)
                        FCircle(radius: 9, color: _emitters[i].colour),

                      // A child of the node above: its emission origin is that
                      // node's world position, updated by the scene graph.
                      FParticles(
                        config: ParticleEmitterConfig(
                          maxParticles: 4000,
                          emissionRate: _rate,
                          lifetimeMin: 0.8,
                          lifetimeMax: 1.6,
                          velocityMin: v.Vector3(-40, -40, -20),
                          velocityMax: v.Vector3(40, 40, 20),
                          gravity: v.Vector3(0, -30, 0),
                          sizeMin: 2,
                          sizeMax: 6,
                          startColor: _emitters[i].colour,
                          endColor: _emitters[i].colour.withValues(alpha: 0),
                          spreadAngle: 0.9,
                          shapeType: 1,
                        ),
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
