import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class NativeParticleDemo extends StatefulWidget {
  const NativeParticleDemo({super.key});

  @override
  State<NativeParticleDemo> createState() => _NativeParticleDemoState();
}

class _NativeParticleDemoState extends State<NativeParticleDemo> {
  bool initialized = false;
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

  void _setupScene(FEngine engine) {
    engine.scene.children.clear();

    if (_showPresets) {
      final config = _presets[_activePresetIdx];
      // Boost presets for visibility in the demo
      final boostedConfig = ParticleEmitterConfig(
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
      );

      final emitter = FParticleEmitter(config: boostedConfig, name: 'PresetEmitter');
      engine.scene.addChild(emitter);
    } else {
      // Mega Stress Test
      final isTriangleMode = _currentShape == 4;
      final maxCount = isTriangleMode ? 1000000 : 500000;
      final rate = isTriangleMode ? 250000 : 100000;

      final emitter = FParticleEmitter(
        config: ParticleEmitterConfig(
          maxParticles: maxCount,
          emissionRate: rate.toDouble(),
          lifetimeMin: 1.0,
          lifetimeMax: 3.0,
          velocityMin: v.Vector3(-300, -300, -300),
          velocityMax: v.Vector3(300, 300, 300),
          gravity: v.Vector3(0, 40, 0),
          sizeMin: isTriangleMode ? 2.0 : 4.0,
          sizeMax: isTriangleMode ? 4.0 : 8.0,
          startColor: Colors.cyanAccent,
          endColor: Colors.purpleAccent.withValues(alpha: 0),
          spreadAngle: 3.14159,
          shapeType: _currentShape,
        ),
        name: 'MegaEmitter',
      );
      engine.scene.addChild(emitter);
    }
  }

  void _cycleShape(FEngine engine) {
    setState(() {
      _currentShape = (_currentShape + 1) % 5;
      _showPresets = false;
    });
    _setupScene(engine);
  }

  void _cyclePreset(FEngine engine) {
    setState(() {
      if (!_showPresets) {
        _showPresets = true;
      } else {
        _activePresetIdx = (_activePresetIdx + 1) % _presets.length;
      }
    });
    _setupScene(engine);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FView(
        autoUpdate: true,
        child: Stack(
          children: [
            Builder(
              builder: (context) {
                final engine = context.dependOnInheritedWidgetOfExactType<InheritedFNode>()?.engine;
                if (engine != null && !initialized) {
                  _setupScene(engine);
                  initialized = true;
                }
                return Container();
              },
            ),
            // UI Overlay
            Positioned(
              top: 50,
              left: 20,
              child: Builder(
                builder: (context) {
                  final engine = context.dependOnInheritedWidgetOfExactType<InheritedFNode>()?.engine;
                  if (engine == null) return const SizedBox.shrink();

                  final activeCount = engine.emitters.fold<int>(0, (sum, e) => sum + e.activeCount);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AKTİF: ${activeCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                        style: TextStyle(
                          color: _showPresets
                              ? Colors.amberAccent
                              : (_currentShape == 4 ? Colors.orangeAccent : Colors.cyanAccent),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Shape Selection
                      GestureDetector(
                        onTap: () => _cycleShape(engine),
                        child: _buildButton(
                          'Stress Mod: ${_shapeNames[_currentShape]}',
                          !_showPresets ? Colors.cyanAccent : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Preset Selection
                      GestureDetector(
                        onTap: () => _cyclePreset(engine),
                        child: _buildButton(
                          'Preset: ${_showPresets ? _presetNames[_activePresetIdx] : "Showcase"}',
                          _showPresets ? Colors.amberAccent : Colors.white24,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Positioned(
              bottom: 40,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Native Particle System',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text('Optimized Per-Type Geometry', style: TextStyle(color: Colors.cyanAccent, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
