import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';

/// Every primitive at once, lit and depth-sorted.
///
/// Uses `FScene.onInit`, which runs once the viewport size is known — the point
/// being that scene layout can be expressed relative to the window rather than
/// in hard-coded world units.
class BasicSceneExample extends StatefulWidget {
  const BasicSceneExample({super.key});

  @override
  State<BasicSceneExample> createState() => _BasicSceneExampleState();
}

class _BasicSceneExampleState extends State<BasicSceneExample> {
  // These belong to the State, not the widget. They used to live on a
  // StatelessWidget and be filled in by onInit, which happens to survive only
  // because Flutter reused that widget instance — rebuild the parent and the
  // scene would silently regenerate.
  final Random _random = Random(42);
  final List<_ShapeData> _shapes = [];

  bool _lit = true;
  bool _spin = true;

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Basic Scene',
      subtitle: 'All five primitives, Z-sorted, under one moving light.',
      controls: [
        DemoToggle(label: 'Light', value: _lit, onChanged: (v) => setState(() => _lit = v)),
        DemoToggle(label: 'Rotate', value: _spin, onChanged: (v) => setState(() => _spin = v)),
        DemoButton(
          label: 'Rebuild scene',
          icon: Icons.casino_rounded,
          onPressed: () => setState(_shapes.clear),
        ),
      ],
      readouts: [DemoStat(label: 'Shapes', value: '${_shapes.length}')],
      hint: 'Shapes are placed relative to the viewport, from FScene.onInit.',
      scene: FScene(
        // Runs once the viewport is measured. Clearing _shapes makes it run
        // again, which is how the rebuild button works.
        onInit: (engine, viewport) {
          if (_shapes.isNotEmpty) return;

          final worldWidth = viewport.x * 0.5;
          final worldHeight = viewport.y * 0.4;

          for (int i = 0; i < 15; i++) {
            _shapes.add(
              _ShapeData(
                type: i % 5,
                color: HSLColor.fromAHSL(1, i * 24.0, 0.7, 0.58).toColor(),
                size: 20.0 + _random.nextDouble() * 25.0,
                position: v.Vector3(
                  (_random.nextDouble() - 0.5) * worldWidth,
                  (_random.nextDouble() - 0.5) * worldHeight,
                  (_random.nextDouble() - 0.5) * 150,
                ),
              ),
            );
          }
        },
        sceneBuilder: (context, elapsed) {
          if (_shapes.isEmpty) return const [];
          final viewport = context.flash?.viewportSize ?? v.Vector2(400, 300);

          return [
            FCamera(position: v.Vector3(0, 0, 500), fov: 60),
            if (_lit)
              FLight(
                position: v.Vector3(
                  cos(elapsed * 0.5) * viewport.x * 0.2,
                  sin(elapsed * 0.3) * viewport.y * 0.15,
                  100,
                ),
                color: Colors.white,
                intensity: 1.5,
              ),
            for (final shape in _shapes) _buildShape(shape, _spin ? elapsed : 0),
          ];
        },
      ),
    );
  }

  Widget _buildShape(_ShapeData shape, double elapsed) {
    final rotation = v.Vector3(
      elapsed * 0.3 + shape.position.x * 0.01,
      elapsed * 0.5 + shape.position.y * 0.01,
      elapsed * 0.2,
    );

    return switch (shape.type) {
      0 => FSphere(position: shape.position, radius: shape.size / 2, color: shape.color),
      1 => FBox(
        position: shape.position,
        rotation: rotation,
        width: shape.size,
        height: shape.size * 0.6,
        color: shape.color,
      ),
      2 => FCube(
        position: shape.position,
        rotation: rotation,
        size: shape.size * 0.8,
        color: shape.color,
      ),
      3 => FCircle(
        position: shape.position,
        rotation: rotation,
        radius: shape.size / 2,
        color: shape.color,
      ),
      _ => FTriangle(
        position: shape.position,
        rotation: rotation,
        size: shape.size,
        color: shape.color,
      ),
    };
  }
}

class _ShapeData {
  const _ShapeData({
    required this.type,
    required this.color,
    required this.size,
    required this.position,
  });

  final int type;
  final Color color;
  final double size;
  final v.Vector3 position;
}
