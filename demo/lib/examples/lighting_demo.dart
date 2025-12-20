import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';

class LightingDemo extends StatefulWidget {
  const LightingDemo({super.key});

  @override
  State<LightingDemo> createState() => _LightingDemoState();
}

class _LightingDemoState extends State<LightingDemo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(title: const Text('Dynamic Lighting Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Flash(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * pi;
            // Orbiting light position
            final lightX = sin(t) * 400;
            final lightZ = cos(t) * 400;
            final lightY = sin(t * 0.5) * 200;

            return FlashNodes(
              children: [
                // The Light Source (Visible as a small white circle for reference)
                FlashLightWidget(
                  name: 'PointLight',
                  position: v.Vector3(lightX, lightY, lightZ),
                  intensity: 1.5,
                  color: Colors.white,
                ),

                // Visual feedback for light position
                FlashCircle(
                  position: v.Vector3(lightX, lightY, lightZ),
                  radius: 10,
                  color: Colors.white,
                  name: 'LightViz',
                ),

                // Center Cube
                FlashCube(
                  size: 150,
                  color: Colors.blue,
                  position: v.Vector3(-150, 0, 0),
                  rotation: v.Vector3(t * 0.2, t * 0.3, 0),
                ),

                // Center Sphere
                FlashSphere(radius: 80, color: Colors.purple, position: v.Vector3(150, 0, 0), name: 'ShadedBall'),

                // Floor Plane (reacts to light)
                FlashBox(
                  position: v.Vector3(0, -250, 0),
                  rotation: v.Vector3(pi / 2, 0, 0),
                  width: 1200,
                  height: 1200,
                  color: Colors.grey[900]!,
                  name: 'Floor',
                ),

                // Ambient labels
                FlashLabel(
                  text: 'Dinamik Işıklandırma Sistemi',
                  position: v.Vector3(0, 300, 0),
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
