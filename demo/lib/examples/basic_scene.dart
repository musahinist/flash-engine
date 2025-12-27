import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Basic Scene Demo - showcasing FScene.onInit for viewport-aware initialization
class BasicSceneExample extends StatelessWidget {
  BasicSceneExample({super.key});

  final Random _rnd = Random(42);
  final List<_ShapeData> _shapes = []; // Populated by onInit

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: FScene(
        // Called once when viewport is available
        onInit: (engine, viewport) {
          if (_shapes.isNotEmpty) return; // Already initialized

          // Calculate world bounds from viewport
          final worldWidth = viewport.x * 0.5;
          final worldHeight = viewport.y * 0.4;

          // Generate shapes with viewport-relative positions (all 5 types)
          for (int i = 0; i < 15; i++) {
            _shapes.add(
              _ShapeData(
                type: i % 5, // 0=sphere, 1=box, 2=cube, 3=circle, 4=triangle
                color: HSLColor.fromAHSL(1, i * 24.0, 0.7, 0.5).toColor(),
                size: 20.0 + _rnd.nextDouble() * 25.0,
                position: v.Vector3(
                  (_rnd.nextDouble() - 0.5) * worldWidth,
                  (_rnd.nextDouble() - 0.5) * worldHeight,
                  (_rnd.nextDouble() - 0.5) * 150,
                ),
              ),
            );
          }
        },

        sceneBuilder: (ctx, elapsed) {
          if (_shapes.isEmpty) return const [];

          final engine = ctx.flash;
          final viewport = engine?.viewportSize ?? v.Vector2(400, 300);

          return [
            FCamera(position: v.Vector3(0, 0, 500), fov: 60),

            // Orbiting light (viewport-relative)
            FLight(
              position: v.Vector3(cos(elapsed * 0.5) * viewport.x * 0.2, sin(elapsed * 0.3) * viewport.y * 0.15, 100),
              color: Colors.white,
              intensity: 1.5,
            ),

            // Shapes with rotation
            for (final shape in _shapes) _buildShape(shape, elapsed),
          ];
        },

        overlay: [
          Positioned(
            top: 60,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🎮 Basic Scene',
                    style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('FScene.onInit demo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('✨ Viewport-relative shapes', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShape(_ShapeData shape, double elapsed) {
    final rot = v.Vector3(
      elapsed * 0.3 + shape.position.x * 0.01,
      elapsed * 0.5 + shape.position.y * 0.01,
      elapsed * 0.2,
    );

    switch (shape.type) {
      case 0:
        return FSphere(position: shape.position, radius: shape.size / 2, color: shape.color);
      case 1:
        return FBox(
          position: shape.position,
          rotation: rot,
          width: shape.size,
          height: shape.size * 0.6,
          color: shape.color,
        );
      case 2:
        return FCube(position: shape.position, rotation: rot, size: shape.size * 0.8, color: shape.color);
      case 3:
        return FCircle(position: shape.position, rotation: rot, radius: shape.size / 2, color: shape.color);
      default:
        return FTriangle(position: shape.position, rotation: rot, size: shape.size, color: shape.color);
    }
  }
}

class _ShapeData {
  final int type;
  final Color color;
  final double size;
  final v.Vector3 position;

  _ShapeData({required this.type, required this.color, required this.size, required this.position});
}
