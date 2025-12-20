import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';

class ThreeDDemo extends StatefulWidget {
  const ThreeDDemo({super.key});

  @override
  State<ThreeDDemo> createState() => _ThreeDDemoState();
}

class _ThreeDDemoState extends State<ThreeDDemo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('3D Primitives Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Flash(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * pi;
            return FlashNodes(
              position: v.Vector3(0, 0, 0),
              children: [
                // Rotating Cube 1
                FlashCube(
                  size: 150,
                  color: Colors.cyanAccent,
                  position: v.Vector3(-200, 0, 0),
                  rotation: v.Vector3(t, t * 0.5, 0),
                ),

                // Rotating Cube 2 (Opposite direction)
                FlashCube(
                  size: 100,
                  color: Colors.purpleAccent,
                  position: v.Vector3(200, 100, -100),
                  rotation: v.Vector3(-t * 0.7, t, t * 0.3),
                ),

                // Floating Sphere 1
                FlashSphere(
                  radius: 60,
                  color: Colors.orangeAccent,
                  position: v.Vector3(0, 150 + sin(t) * 50, 50),
                  name: 'Ball1',
                ),

                // Floating Sphere 2
                FlashSphere(
                  radius: 40,
                  color: Colors.pinkAccent,
                  position: v.Vector3(150 * cos(t), -200, 150 * sin(t)),
                  name: 'Ball2',
                ),

                // Ground Plane (using nodes)
                FlashBox(
                  position: v.Vector3(0, -300, 0),
                  rotation: v.Vector3(pi / 2, 0, 0),
                  width: 1000,
                  height: 1000,
                  color: Colors.white10,
                ),

                // Some depth reference labels
                FlashLabel(
                  text: 'FRONT',
                  position: v.Vector3(0, 0, 200),
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
                FlashLabel(
                  text: 'BACK',
                  position: v.Vector3(0, 0, -200),
                  style: const TextStyle(color: Colors.white54, fontSize: 24),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
