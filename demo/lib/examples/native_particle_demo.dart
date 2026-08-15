import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

class NativeParticleDemo extends StatefulWidget {
  const NativeParticleDemo({super.key});

  @override
  State<NativeParticleDemo> createState() => _NativeParticleDemoState();
}

class _NativeParticleDemoState extends State<NativeParticleDemo> {
  int _currentShape = 0;
  final List<String> _shapeNames = ['Quad', 'Hexagon', 'Octagon', 'Round (12 sides)', 'Triangle (1M+)'];

  bool _showPresets = false;
  int _activePresetIdx = 0;

  late final List<ParticleEmitterConfig> _presets = [
    ParticleEmitterConfig.fire,
    ParticleEmitterConfig.smoke,
    ParticleEmitterConfig.bubbles,
    ParticleEmitterConfig.rain,
    ParticleEmitterConfig.snow,
    ParticleEmitterConfig.magic,
    ParticleEmitterConfig.electric,
  ];

  late final List<String> _presetNames = [
    'Fire (Hexagon)',
    'Smoke (Round)',
    'Bubbles (Round)',
    'Rain (Triangle)',
    'Snow (Octagon)',
    'Magic (Octagon)',
    'Electric (Triangle)',
  ];

  @override
  Widget build(BuildContext context) {
    // Current configuration based on selection
    final config = _showPresets ? _presets[_activePresetIdx] : _getStressConfig();

    return DemoPage(
      title: 'Million Particles',
      subtitle: 'The native vertex builder at full stretch.',
      accent: DemoTheme.warning,
      controlsWidth: 250,
      controls: [
        DemoButton(
          label: 'Shape: ${_shapeNames[_currentShape]}',
          icon: Icons.category_rounded,
          tint: DemoTheme.warning,
          selected: !_showPresets,
          width: 226,
          onPressed: _cycleShape,
        ),
        DemoButton(
          label: _showPresets ? 'Preset: ${_presetNames[_activePresetIdx]}' : 'Switch to presets',
          icon: Icons.auto_awesome_rounded,
          tint: DemoTheme.accent,
          selected: _showPresets,
          width: 226,
          onPressed: _cyclePreset,
        ),
      ],
      readouts: [
        Builder(
          builder: (context) {
            final engine = context.flash;
            if (engine == null) return const SizedBox.shrink();
            // The count changes every frame, so only this panel listens —
            // rebuilding the scene to report on it would be self-defeating.
            return ListenableBuilder(
              listenable: engine,
              builder: (context, _) {
                final active = engine.emitters.isEmpty ? 0 : engine.emitters.first.activeCount;
                return DemoStat(
                  label: 'Active',
                  value: _grouped(active),
                  tint: _currentShape == 4 ? DemoTheme.warning : DemoTheme.accent,
                );
              },
            );
          },
        ),
      ],
      hint: 'Triangle mode reaches 1,000,000; the other shapes cap at 500,000.',
      scene: FScene(
        sceneBuilder: (ctx, elapsed) {
          // Slow zoom out animation (Starts at 400, ends at 1000 over 40 seconds)
          final zoomZ = 400.0 + (elapsed * 15.0).clamp(0, 600);

          return [
            FCamera(position: v.Vector3(0, 0, zoomZ), fov: 60),

            // Declarative Particle Widget
            if (_showPresets)
              FParticles(
                key: ValueKey('preset_$_activePresetIdx'),
                config: ParticleEmitterConfig(
                  emissionRate: config.emissionRate * 10,
                  lifetimeMin: config.lifetimeMin,
                  lifetimeMax: config.lifetimeMax,
                  velocityMin: config.velocityMin,
                  velocityMax: config.velocityMax,
                  gravity: config.gravity,
                  sizeMin: config.sizeMin,
                  sizeMax: config.sizeMax,
                  startColor: config.startColor,
                  endColor: config.endColor,
                  spreadAngle: config.spreadAngle,
                  shapeType: config.shapeType,
                  maxParticles: 50000,
                ),
              )
            else
              FParticles(key: ValueKey('stress_$_currentShape'), config: _getStressConfig()),
          ];
        },
      ),
    );
  }

  ParticleEmitterConfig _getStressConfig() {
    final isTriangleMode = _currentShape == 4;
    return ParticleEmitterConfig(
      maxParticles: isTriangleMode ? 1000000 : 500000,
      emissionRate: isTriangleMode ? 500000 : 100000,
      lifetimeMin: isTriangleMode ? 1.0 : 1.0,
      lifetimeMax: isTriangleMode ? 5.0 : 3.0,
      velocityMin: v.Vector3(-300, -300, -300),
      velocityMax: v.Vector3(300, 300, 300),
      gravity: v.Vector3(0, 40, 0),
      sizeMin: isTriangleMode ? 2.0 : 4.0,
      sizeMax: isTriangleMode ? 4.0 : 8.0,
      startColor: Colors.cyanAccent,
      endColor: Colors.purpleAccent.withValues(alpha: 0),
      spreadAngle: 3.14159,
      shapeType: _currentShape,
    );
  }

  void _cycleShape() {
    setState(() {
      _currentShape = (_currentShape + 1) % 5;
      _showPresets = false;
    });
  }

  void _cyclePreset() {
    setState(() {
      if (!_showPresets) {
        _showPresets = true;
      } else {
        _activePresetIdx = (_activePresetIdx + 1) % _presets.length;
      }
    });
  }

  /// Thousands separators, so a seven-digit readout stays legible.
  static String _grouped(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}
