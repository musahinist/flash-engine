import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';

class BasicSceneExample extends StatefulWidget {
  const BasicSceneExample({super.key});

  @override
  State<BasicSceneExample> createState() => _BasicSceneExampleState();
}

class _BasicSceneExampleState extends State<BasicSceneExample> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random random = Random();
  late final List<_ShapeData> shapes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

    // Pre-generate shape data
    shapes = List.generate(
      15,
      (i) => _ShapeData(
        color: Colors.primaries[random.nextInt(Colors.primaries.length)].withValues(alpha: 0.8),
        size: 40.0 + random.nextDouble() * 60.0,
        position: v.Vector3(
          (random.nextDouble() - 0.5) * 600,
          (random.nextDouble() - 0.5) * 600,
          (random.nextDouble() - 0.5) * 500,
        ),
        rotationSpeed: v.Vector3(0, 0.01, 0.005),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Basic Scene (Declarative)'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Container(
        color: const Color(0xFF1A1A1A),
        child: Flash(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                children: [
                  for (final shape in shapes)
                    FlashBox(
                      position: shape.position,
                      rotation: v.Vector3(
                        0,
                        shape.rotationSpeed.y * _controller.value * 1000,
                        shape.rotationSpeed.z * _controller.value * 1000,
                      ),
                      width: shape.size,
                      height: shape.size,
                      color: shape.color,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShapeData {
  final Color color;
  final double size;
  final v.Vector3 position;
  final v.Vector3 rotationSpeed;

  _ShapeData({required this.color, required this.size, required this.position, required this.rotationSpeed});
}
