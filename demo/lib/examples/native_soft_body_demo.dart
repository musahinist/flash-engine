import 'dart:math' as math;
import 'dart:ffi'; // Add FFI import
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
// import 'package:flash/src/widgets/physics/flash_soft_body_widget.dart'; // Removed unnecessary import
// import 'package:flash/src/core/native/particles_ffi.dart'; // Removed unused import
import 'package:vector_math/vector_math_64.dart' as v;

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
  final Pointer<Float> _tempX = calloc<Float>();
  final Pointer<Float> _tempY = calloc<Float>();

  @override
  void initState() {
    super.initState();
    _physics = FPhysicsSystem(gravity: v.Vector2(0, -900));

    // Generate points once
    const int pointCount = 32;
    const double radius = 80.0;
    _initialPoints = List.generate(pointCount, (i) {
      final angle = (i / pointCount) * 2 * math.pi;
      return Offset(math.cos(angle) * radius, math.sin(angle) * radius + 200);
    });
  }

  @override
  void dispose() {
    calloc.free(_tempX);
    calloc.free(_tempY);
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

    // Check points
    const int count = 32;
    for (int i = 0; i < count; i++) {
      FPhysicsSystem.getSoftBodyPoint(_physics.world, 0, i, _tempX, _tempY);
      final px = _tempX.value;
      final py = _tempY.value;
      final dist = (wx - px) * (wx - px) + (wy - py) * (wy - py);
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
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

                      FLight(
                        position: v.Vector3(math.sin(elapsed) * 300, math.cos(elapsed) * 300, 200),
                        color: Colors.cyan,
                        intensity: 1.5,
                      ),
                    ],
                  ),
                ];
              },
              overlay: [_buildUI()],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUI() {
    return Positioned(
      top: 60,
      left: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BIO-SOFT C++ CORE',
            style: TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          const Text('High-Performance Native Elasticity', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 24),
          _buildSlider('Pressure', pressure, 1.0, 20.0, (v) => setState(() => pressure = v)),
          _buildSlider('Stiffness', stiffness, 0.1, 1.0, (v) => setState(() => stiffness = v)),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          Slider(value: value, min: min, max: max, activeColor: Colors.cyanAccent, onChanged: onChanged),
        ],
      ),
    );
  }
}
