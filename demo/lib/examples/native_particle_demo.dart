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
  int particleCount = 20000;

  void _setupScene(FlashEngine engine) {
    engine.scene.children.clear();

    // Add a native emitter with high particle count
    final emitter = FlashParticleEmitter(
      config: ParticleEmitterConfig(
        maxParticles: 500000,
        emissionRate: 100000, // Balanced for 500k
        lifetimeMin: 1.0,
        lifetimeMax: 4.0,
        velocityMin: v.Vector3(-400, -400, -400),
        velocityMax: v.Vector3(400, 400, 400),
        gravity: v.Vector3(0, 50, 0), // Slight drift
        sizeMin: 2,
        sizeMax: 5, // Larger to see the quads
        startColor: Colors.cyanAccent,
        endColor: Colors.purpleAccent.withValues(alpha: 0),
        spreadAngle: 3.14159,
      ),
      name: 'MegaStressEmitter',
    );

    engine.scene.addChild(emitter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Flash(
        autoUpdate: true,
        child: Stack(
          children: [
            Builder(
              builder: (context) {
                final engine = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>()?.engine;
                if (engine != null && !initialized) {
                  _setupScene(engine);
                  initialized = true;
                }
                return Container();
              },
            ),
            // Simple particle count in top-left
            Positioned(
              top: 50,
              left: 20,
              child: Builder(
                builder: (context) {
                  final engine = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>()?.engine;
                  if (engine == null) return const SizedBox.shrink();

                  final activeCount = engine.emitters.fold<int>(0, (sum, e) => sum + e.activeCount);

                  return Text(
                    'Aktif Parçacık: ${activeCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    style: const TextStyle(
                      color: Color(0xFF00FFFF),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
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
                    'Native FFI Particle Demo',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Physics running in C++, Rendering in Flutter',
                    style: TextStyle(color: Colors.cyanAccent, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
