import 'dart:math' as math;

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';

/// Pressure soft bodies solved in C++.
///
/// A ring of points held together by distance constraints, with an area
/// constraint pushing outward — the "pressure" control is that target area.
/// Stiffness is how hard the distance constraints pull per iteration.
///
/// Drag a point: `setSoftBodyPoint` moves it and zeroes its velocity, which is
/// what stops a drag from launching the whole body.
class NativeSoftBodyDemo extends StatefulWidget {
  const NativeSoftBodyDemo({super.key});

  @override
  State<NativeSoftBodyDemo> createState() => _NativeSoftBodyDemoState();
}

class _NativeSoftBodyDemoState extends State<NativeSoftBodyDemo> {
  double pressure = 8.0;
  double stiffness = 0.9;

  late FPhysicsSystem _physics;
  late final List<Offset> _initialPoints;

  // Dragging state
  int? _draggedPointIndex;

  @override
  void initState() {
    super.initState();
    _physics = FPhysicsSystem(gravity: v.Vector2(0, -900));

    // Create Physical Ground
    const int pointCount = 32;
    const double radius = 80.0;
    _initialPoints = List.generate(pointCount, (i) {
      final angle = (i / pointCount) * 2 * math.pi;
      return Offset(math.cos(angle) * radius, math.sin(angle) * radius + 200);
    });
  }

  @override
  void dispose() {
    _physics.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details, BoxConstraints constraints) {
    // Convert screen to world
    final cx = constraints.maxWidth / 2;
    final cy = constraints.maxHeight / 2;
    final wx = details.localPosition.dx - cx;
    final wy = -(details.localPosition.dy - cy); // Y-Up

    // Find closest point
    double minDst = double.infinity;
    int closest = -1;

    // Check points using clean helper API
    const int count = 32;
    for (int i = 0; i < count; i++) {
      final point = FPhysicsSystem.getSoftBodyPointPos(_physics.world, 0, i);
      final dist = (wx - point.dx) * (wx - point.dx) + (wy - point.dy) * (wy - point.dy);

      if (dist < minDst) {
        minDst = dist;
        closest = i;
      }
    }

    if (closest != -1 && minDst < 2500) {
      // 50 pixels tolerance squared
      _draggedPointIndex = closest;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_draggedPointIndex == null) return;

    final cx = constraints.maxWidth / 2;
    final cy = constraints.maxHeight / 2;
    final wx = details.localPosition.dx - cx;
    final wy = -(details.localPosition.dy - cy);

    FPhysicsSystem.setSoftBodyPoint(_physics.world, 0, _draggedPointIndex!, wx, wy);
  }

  void _handlePanEnd(DragEndDetails details) {
    _draggedPointIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Native Soft Body',
      subtitle: 'A pressure-constrained point ring, solved by the C++ core.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Pressure',
              value: pressure,
              min: 1,
              max: 20,
              onChanged: (value) => setState(() => pressure = value),
            ),
            DemoSlider(
              label: 'Stiffness',
              value: stiffness,
              min: 0.1,
              max: 1,
              fractionDigits: 2,
              onChanged: (value) => setState(() => stiffness = value),
            ),
          ],
        ),
      ],
      readouts: const [DemoStat(label: 'Points', value: '32')],
      hint: 'Drag any point on the blob.',
      scene: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanStart: (d) => _handlePanStart(d, constraints),
            onPanUpdate: (d) => _handlePanUpdate(d, constraints),
            onPanEnd: _handlePanEnd,
            child: FScene(
              physicsWorld: _physics,
              autoUpdate: true,
              sceneBuilder: (context, elapsed) {
                return [
                  FNodes(
                    children: [
                      // Declarative Soft Body Widget
                      FSoftBodyWidget(
                        world: _physics.world,
                        initialPoints: _initialPoints,
                        pressure: pressure,
                        stiffness: stiffness,
                      ),

                      FStaticBody(
                        position: v.Vector3(0, -500, 0),
                        width: 2000,
                        height: 20,
                        color: Colors.grey[800]!,
                        debugDraw: true,
                      ),
                    ],
                  ),
                ];
              },
            ),
          );
        },
      ),
    );
  }
}
