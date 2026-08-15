import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: FScene(
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
        overlay: [
          // Header UI
          Positioned(
            top: 60,
            left: 20,
            child: Builder(
              builder: (context) {
                final engine = context.flash;
                if (engine == null) return const SizedBox.shrink();

                // Wrap in ListenableBuilder to update count every frame
                return ListenableBuilder(
                  listenable: engine,
                  builder: (context, _) {
                    final activeCount = engine.emitters.isEmpty ? 0 : engine.emitters.first.activeCount;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AKTİF: ${activeCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                          style: TextStyle(
                            color: _showPresets
                                ? Colors.amberAccent
                                : (_currentShape == 4 ? Colors.orangeAccent : Colors.cyanAccent),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _cycleShape(),
                          child: _buildButton(
                            'Stress Mod: ${_shapeNames[_currentShape]}',
                            !_showPresets ? Colors.cyanAccent : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _cyclePreset(),
                          child: _buildButton(
                            'Preset: ${_showPresets ? _presetNames[_activePresetIdx] : "Showcase"}',
                            _showPresets ? Colors.amberAccent : Colors.white24,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Info
          const Positioned(
            bottom: 40,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'FSCENE POWERED',
                  style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 4),
                ),
                SizedBox(height: 4),
                Text(
                  'Native Particle Demo',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text('Declarative Scene Management', style: TextStyle(color: Colors.cyanAccent, fontSize: 14)),
              ],
            ),
          ),

          // Back Button
          Positioned(
            bottom: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white54),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
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

  Widget _buildButton(String label, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 1)],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
