import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Native Physics Performance Demo - using FScene structure
class CollisionLayersDemoExample extends StatefulWidget {
  const CollisionLayersDemoExample({super.key});

  @override
  State<CollisionLayersDemoExample> createState() => _CollisionLayersDemoExampleState();
}

class _CollisionLayersDemoExampleState extends State<CollisionLayersDemoExample> {
  int _resetKey = 0;

  void _reset() => setState(() => _resetKey++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(title: const Text('Native Physics Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: FScene(
        key: ValueKey(_resetKey), // Force rebuild on reset
        // Static scene - physics bodies created once
        scene: [
          FCamera(position: v.Vector3(0, 0, 1000), fov: 60),
          FPhysicsWorld(gravity: FPhysics.standardGravity),

          // Static Floor
          FStaticBody(
            name: 'Ground',
            position: v.Vector3(0, -350, 0),
            width: 800,
            height: 40,
            child: const FBox(width: 800, height: 40, color: Colors.white12),
          ),

          // Blue boxes - diagonal line from top-left
          for (int i = 0; i < 20; i++)
            FRigidBody.square(
              key: ValueKey('blue_$i'),
              name: 'BlueBox',
              position: v.Vector3(-150 + (i * 20), 400 + (i * 60), 0),
              size: 30,
              child: const FBox(width: 30, height: 30, color: Colors.cyanAccent),
            ),

          // Red boxes - diagonal line from top-right
          for (int i = 0; i < 20; i++)
            FRigidBody.square(
              key: ValueKey('red_$i'),
              name: 'RedBox',
              position: v.Vector3(150 - (i * 20), 400 + (i * 60), 0),
              size: 30,
              child: const FBox(width: 30, height: 30, color: Colors.redAccent),
            ),
        ],

        // UI overlay
        overlay: [
          Positioned(
            left: 20,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NATIVE PHYSICS',
                    style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('40 rigid bodies', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _reset, child: const Icon(Icons.refresh)),
    );
  }
}
