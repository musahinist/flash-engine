import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';

class DeclarativeDemoExample extends StatefulWidget {
  const DeclarativeDemoExample({super.key});

  @override
  State<DeclarativeDemoExample> createState() => _DeclarativeDemoExampleState();
}

class _DeclarativeDemoExampleState extends State<DeclarativeDemoExample> with SingleTickerProviderStateMixin {
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
      appBar: AppBar(title: const Text('Declarative API Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Flash(
        showDebugOverlay: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * pi;
            return FlashNodes(
              children: [
                // Background Layer
                FlashBox(position: v.Vector3(0, 0, -500), width: 2000, height: 2000, color: const Color(0xFF0A0A1A)),

                // Rotating Parent "System"
                FlashBox(
                  rotation: v.Vector3(0, 0, t * 0.2),
                  width: 0,
                  height: 0, // Pivot only
                  child: FlashNodes(
                    children: [
                      // Central "Sun"
                      FlashBox(width: 100, height: 100, color: Colors.orange, rotation: v.Vector3(0, 0, -t)),

                      // Orbiting "Planet"
                      FlashBox(
                        position: v.Vector3(300, 0, 0),
                        width: 50,
                        height: 50,
                        color: Colors.blue,
                        rotation: v.Vector3(0, t, 0), // Rotate on Y axis while orbiting
                        child: FlashBox(
                          position: v.Vector3(80, 0, 0),
                          width: 20,
                          height: 20,
                          color: Colors.grey,
                          rotation: v.Vector3(t * 2, 0, 0),
                        ),
                      ),
                    ],
                  ),
                ),

                // Random Floaties
                for (int i = 0; i < 5; i++)
                  FlashBox(
                    position: v.Vector3(sin(t + i) * 500, cos(t * 0.5 + i) * 300, 200),
                    width: 30,
                    height: 30,
                    color: Colors.cyanAccent.withValues(alpha: 0.5),
                    rotation: v.Vector3(t, t, t),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
