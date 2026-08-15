import 'dart:async';
import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// A pachinko board: static pegs and walls, dynamic bodies falling through.
///
/// Shows [FStaticBody] and [FRigidBody] against the native solver, and what
/// stacking and resting contact look like when they are working.
class PhysicsDemoExample extends StatefulWidget {
  const PhysicsDemoExample({super.key});

  @override
  State<PhysicsDemoExample> createState() => _PhysicsDemoExampleState();
}

class _PhysicsDemoExampleState extends State<PhysicsDemoExample> {
  /// A cap so the board stays readable and the solver stays inside a frame;
  /// the oldest body is retired once it is reached. Bodies release their native
  /// slot when their node leaves the tree, so this is about how much is worth
  /// simulating, not about running the pool dry.
  static const int _maxBodies = 120;

  final List<_BodyData> _bodies = [];
  final Random _random = Random(7);
  Timer? _spawnTimer;
  bool _autoSpawn = false;

  @override
  void dispose() {
    _spawnTimer?.cancel();
    super.dispose();
  }

  void _spawnBody() {
    setState(() {
      if (_bodies.length >= _maxBodies) _bodies.removeAt(0);
      final isCircle = _random.nextBool();
      _bodies.add(
        _BodyData(
          key: UniqueKey(),
          isCircle: isCircle,
          position: v.Vector3((_random.nextDouble() - 0.5) * 40, 350, 0),
          size: 15.0 + _random.nextDouble() * 15.0,
          color: Colors.accents[_random.nextInt(Colors.accents.length)],
        ),
      );
    });
  }

  void _setAutoSpawn(bool value) {
    setState(() => _autoSpawn = value);
    _spawnTimer?.cancel();
    if (value) {
      // A Timer, not a `while (mounted) await Future.delayed(...)` loop. The
      // loop version could not be cancelled — it kept a pending future alive
      // past dispose and only noticed on its next tick.
      _spawnTimer = Timer.periodic(const Duration(milliseconds: 600), (_) => _spawnBody());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Native Physics',
      subtitle: 'FRigidBody and FStaticBody on the C++ solver.',
      controls: [
        DemoButton(label: 'Drop one', icon: Icons.south_rounded, onPressed: _spawnBody),
        DemoToggle(label: 'Keep dropping', value: _autoSpawn, onChanged: _setAutoSpawn),
        DemoButton(
          label: 'Clear',
          icon: Icons.refresh_rounded,
          tint: DemoTheme.danger,
          onPressed: () {
            _setAutoSpawn(false);
            setState(_bodies.clear);
          },
        ),
      ],
      readouts: [
        DemoStat(label: 'Bodies', value: '${_bodies.length} / $_maxBodies'),
      ],
      hint: 'Tap "Drop one", or leave it dropping. Oldest retires past $_maxBodies.',
      scene: FView(
        // The scene only changes when a body is added or removed, so there is
        // no reason to rebuild the whole widget tree every frame.
        autoUpdate: false,
        child: Stack(
          children: [
            FCamera(position: v.Vector3(0, 0, 1000)),
            FStaticBody(
              name: 'Floor',
              position: v.Vector3(0, -400, 0),
              width: 800,
              height: 40,
              color: Colors.grey[800]!,
              debugDraw: true,
            ),
            FStaticBody(
              name: 'LeftWall',
              position: v.Vector3(-380, 0, 0),
              width: 40,
              height: 800,
              color: Colors.grey[800]!,
              debugDraw: true,
            ),
            FStaticBody(
              name: 'RightWall',
              position: v.Vector3(380, 0, 0),
              width: 40,
              height: 800,
              color: Colors.grey[800]!,
              debugDraw: true,
            ),
            for (int row = 0; row < 6; row++)
              for (int col = -4; col <= 4; col++)
                if (row.isEven == col.isEven)
                  FStaticBody.circle(
                    name: 'Peg_${row}_$col',
                    position: v.Vector3(col * 60.0, 200.0 - row * 70.0, 0),
                    radius: 10,
                    color: Colors.blueGrey,
                    debugDraw: true,
                  ),
            for (final body in _bodies)
              body.isCircle
                  ? FRigidBody.circle(
                      key: body.key,
                      name: 'Body_${body.key}',
                      position: body.position,
                      radius: body.size,
                      color: body.color,
                      debugDraw: true,
                    )
                  : FRigidBody.square(
                      key: body.key,
                      name: 'Body_${body.key}',
                      position: body.position,
                      size: body.size * 2,
                      color: body.color,
                      debugDraw: true,
                    ),
          ],
        ),
      ),
    );
  }
}

class _BodyData {
  const _BodyData({
    required this.key,
    required this.isCircle,
    required this.position,
    required this.size,
    required this.color,
  });

  final Key key;
  final bool isCircle;
  final v.Vector3 position;
  final double size;
  final Color color;
}
