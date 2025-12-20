import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';

class DepthDioramaExample extends StatefulWidget {
  const DepthDioramaExample({super.key});

  @override
  State<DepthDioramaExample> createState() => _DepthDioramaExampleState();
}

class _DepthDioramaExampleState extends State<DepthDioramaExample> with SingleTickerProviderStateMixin {
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
      appBar: AppBar(
        title: const Text('2.5D Diorama (Declarative)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Flash(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * pi;
            return Stack(
              children: [
                // Background Layer
                for (int i = 0; i < 5; i++)
                  FlashTriangle(
                    position: v.Vector3((i - 2) * 400, -150, -500),
                    size: 400,
                    color: const Color(0xFF1a3c5a),
                  ),

                // Midground Layer
                for (int i = 0; i < 8; i++)
                  FlashTriangle(
                    position: v.Vector3((i - 3.5) * 200, -200, 0),
                    size: 250,
                    color: const Color(0xFF2d5a27),
                  ),

                // Player Orbiting
                FlashCircle(
                  position: v.Vector3(sin(t) * 400, 0, cos(t * 0.7) * 700),
                  radius: 30,
                  color: Colors.cyanAccent,
                  rotation: v.Vector3(0, 0, t),
                ),

                // Foreground Layer
                for (int i = 0; i < 12; i++)
                  FlashTriangle(
                    position: v.Vector3((i - 5.5) * 150, -250, 500),
                    size: 150,
                    color: const Color(0xFF4a4a4a),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
