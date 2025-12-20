import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';

class ParticleFieldExample extends StatefulWidget {
  const ParticleFieldExample({super.key});

  @override
  State<ParticleFieldExample> createState() => _ParticleFieldExampleState();
}

class _ParticleFieldExampleState extends State<ParticleFieldExample> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ParticleData> particles = [];
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

    for (int i = 0; i < 200; i++) {
      particles.add(
        _ParticleData(
          position: v.Vector3.zero(),
          velocity: v.Vector3(
            (random.nextDouble() - 0.5) * 10,
            (random.nextDouble() - 0.5) * 10,
            (random.nextDouble() - 0.5) * 5,
          ),
          color: Colors.cyanAccent.withValues(alpha: random.nextDouble() * 0.5 + 0.2),
          size: 2.0 + random.nextDouble() * 4.0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Particle Field (Declarative)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        color: Colors.black,
        child: Flash(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return FlashNodes(
                children: [for (final p in particles) _ParticleWidget(data: p, time: _controller.value)],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ParticleWidget extends StatelessWidget {
  final _ParticleData data;
  final double time;

  const _ParticleWidget({required this.data, required this.time});

  @override
  Widget build(BuildContext context) {
    // We can still use imperative logic for high-performance loops if needed,
    // but here we show how it works with Widgets.
    final pos = data.position + (data.velocity * time * 60);

    // Bounds check and wrap-around
    if (pos.x.abs() > 400) pos.x %= 400;
    if (pos.y.abs() > 400) pos.y %= 400;
    if (pos.z.abs() > 400) pos.z %= 400;

    return FlashBox(position: pos, width: data.size, height: data.size, color: data.color);
  }
}

class _ParticleData {
  v.Vector3 position;
  v.Vector3 velocity;
  final Color color;
  final double size;

  _ParticleData({required this.position, required this.velocity, required this.color, required this.size});
}
