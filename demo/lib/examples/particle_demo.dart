import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// The bundled [ParticleEmitterConfig] presets.
///
/// Every one of these is a plain config object — nothing is special-cased in
/// the engine. Read `ParticleEmitterConfig.fire` and you have the whole recipe:
/// lifetimes, a velocity box, gravity, a size range and a colour ramp.
class ParticleDemoExample extends StatefulWidget {
  const ParticleDemoExample({super.key});

  @override
  State<ParticleDemoExample> createState() => _ParticleDemoExampleState();
}

class _ParticleDemoExampleState extends State<ParticleDemoExample> {
  static final Map<String, ParticleEmitterConfig> _presets = {
    'Fire': ParticleEmitterConfig.fire,
    'Smoke': ParticleEmitterConfig.smoke,
    'Sparkle': ParticleEmitterConfig.sparkle,
    'Snow': ParticleEmitterConfig.snow,
    'Rain': ParticleEmitterConfig.rain,
    'Explosion': ParticleEmitterConfig.explosion,
    'Confetti': ParticleEmitterConfig.confetti,
    'Magic': ParticleEmitterConfig.magic,
    'Bubbles': ParticleEmitterConfig.bubbles,
    'Dust': ParticleEmitterConfig.dust,
    'Fireflies': ParticleEmitterConfig.fireflies,
    'Meteor': ParticleEmitterConfig.meteor,
    'Heal': ParticleEmitterConfig.heal,
    'Electric': ParticleEmitterConfig.electric,
    'Blood': ParticleEmitterConfig.blood,
    'Lava': ParticleEmitterConfig.lava,
    'Poison': ParticleEmitterConfig.poison,
    'Steam': ParticleEmitterConfig.steam,
  };

  String _selected = 'Fire';

  @override
  Widget build(BuildContext context) {
    final config = _presets[_selected]!;

    return DemoPage(
      title: 'Particle Presets',
      subtitle: 'Eighteen bundled configs. None of them is special-cased.',
      accent: DemoTheme.warning,
      controls: [
        DemoPanel(
          title: 'Preset',
          tint: DemoTheme.warning,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in _presets.keys)
                  DemoButton(
                    label: name,
                    tint: DemoTheme.warning,
                    selected: name == _selected,
                    onPressed: () => setState(() => _selected = name),
                  ),
              ],
            ),
          ],
        ),
      ],
      readouts: [
        DemoStat(label: 'Rate', value: '${config.emissionRate.round()}/s'),
        DemoStat(label: 'Capacity', value: '${config.maxParticles}'),
        DemoStat(
          label: 'Lifetime',
          value: '${config.lifetimeMin.toStringAsFixed(1)}'
              '–${config.lifetimeMax.toStringAsFixed(1)}s',
        ),
        DemoStat(label: 'Shape', value: _shapeName(config.shapeType)),
      ],
      hint: 'The readout on the right is read straight off the selected config.',
      scene: FView(
        child: Stack(
          children: [
            FCamera(position: v.Vector3(0, 0, 500), fov: 60),
            FParticles(
              // A new key restarts the emitter rather than mutating a running
              // one, which is what makes switching preset look clean.
              key: ValueKey(_selected),
              initialPosition: v.Vector3(0, -50, 0),
              config: config,
            ),
          ],
        ),
      ),
    );
  }

  static String _shapeName(int shapeType) => switch (shapeType) {
    1 => 'hexagon',
    2 => 'octagon',
    3 => 'round',
    4 => 'triangle',
    _ => 'quad',
  };
}
