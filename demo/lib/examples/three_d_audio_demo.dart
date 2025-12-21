import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';

class ThreeDAudioDemo extends StatefulWidget {
  const ThreeDAudioDemo({super.key});

  @override
  State<ThreeDAudioDemo> createState() => _ThreeDAudioDemoState();
}

class _ThreeDAudioDemoState extends State<ThreeDAudioDemo> {
  double _time = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('3D Audio Demo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Flash(
        autoUpdate: true,
        child: Builder(
          builder: (context) {
            final engineWidget = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>();
            final engine = engineWidget?.engine;

            if (engine != null) {
              engine.onUpdate = () {
                _time += 1 / 60.0; // Assuming 60 FPS
                setState(() {}); // Trigger rebuild to update camera
              };
            }

            // Camera moves in a circle around the origin
            final cameraX = 300 * cos(_time);
            final cameraZ = 300 * sin(_time);
            final cameraY = 100 * sin(_time * 0.5); // Some up-down motion

            return Stack(
              children: [
                FlashCamera(
                  position: v.Vector3(cameraX, cameraY, cameraZ + 400),
                  fov: 60,
                ),

                // Center marker
                FlashSphere(position: v.Vector3(0, 0, 0), radius: 10, color: Colors.white),

                // Audio sources at different positions
                // Front
                _buildAudioSource(v.Vector3(0, 0, -200), Colors.red, 'Front'),
                // Back
                _buildAudioSource(v.Vector3(0, 0, 200), Colors.blue, 'Back'),
                // Left
                _buildAudioSource(v.Vector3(-200, 0, 0), Colors.green, 'Left'),
                // Right
                _buildAudioSource(v.Vector3(200, 0, 0), Colors.yellow, 'Right'),
                // Up
                _buildAudioSource(v.Vector3(0, 200, 0), Colors.purple, 'Up'),
                // Down
                _buildAudioSource(v.Vector3(0, -200, 0), Colors.orange, 'Down'),

                // UI overlay
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '3D Audio Demo',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Camera orbiting center\nListen to spatial audio',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Time: ${_time.toStringAsFixed(1)}s',
                          style: const TextStyle(color: Colors.cyan, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAudioSource(v.Vector3 position, Color color, String label) {
    return Stack(
      children: [
        FlashSphere(position: position, radius: 20, color: color),
        // Add audio player
        Positioned.fill(
          child: FlashAudioPlayer(
            assetPath: 'asset/demo.mp3',
            autoplay: true,
            loop: true,
            is3D: true,
            volume: 1.0,
            minDistance: 50.0,
            maxDistance: 500.0,
            position: position,
          ),
        ),
        // Label
        Positioned(
          left: position.x + 30,
          top: position.y + 30,
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}