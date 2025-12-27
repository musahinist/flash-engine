import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';

class PhysicsDemoExample extends StatefulWidget {
  const PhysicsDemoExample({super.key});

  @override
  State<PhysicsDemoExample> createState() => _PhysicsDemoExampleState();
}

class _PhysicsDemoExampleState extends State<PhysicsDemoExample> {
  // Persistent data to ensure stable keys and properties
  final List<_BodyData> _bodies = [];
  bool _autoSpawn = false;

  void _spawnBody() {
    final r = Random();
    final isCircle = r.nextBool();
    _bodies.add(
      _BodyData(
        key: UniqueKey(),
        isCircle: isCircle,
        // Random position at top
        position: v.Vector3((r.nextDouble() - 0.5) * 40, 350, 0),
        // Random size
        size: 15.0 + r.nextDouble() * 15.0,
        color: Colors.accents[r.nextInt(Colors.accents.length)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Stable Physics Demo'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(_autoSpawn ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _autoSpawn = !_autoSpawn;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _bodies.clear();
                _autoSpawn = false;
              });
            },
          ),
        ],
      ),
      body: Flash(
        autoUpdate: false, // Fix: Prevent full widget tree rebuild every frame
        child: Stack(
          children: [
            FlashCamera(position: v.Vector3(0, 0, 1000)),

            // --- Static World Geometry ---
            FlashStaticBody(
              name: 'Floor',
              position: v.Vector3(0, -400, 0),
              width: 800,
              height: 40,
              color: Colors.grey[800]!,
              debugDraw: true,
            ),
            FlashStaticBody(
              name: 'LeftWall',
              position: v.Vector3(-380, 0, 0),
              width: 40,
              height: 800,
              color: Colors.grey[800]!,
              debugDraw: true,
            ),
            FlashStaticBody(
              name: 'RightWall',
              position: v.Vector3(380, 0, 0),
              width: 40,
              height: 800,
              color: Colors.grey[800]!,
              debugDraw: true,
            ),

            // Pegs
            for (int row = 0; row < 6; row++)
              for (int col = -4; col <= 4; col++)
                if ((row % 2 == 0 && col % 2 == 0) || (row % 2 != 0 && col % 2 != 0))
                  FlashStaticBody.circle(
                    name: 'Peg_${row}_$col',
                    position: v.Vector3(col * 60.0, 200.0 - row * 70.0, 0),
                    radius: 10,
                    color: Colors.blueGrey,
                    debugDraw: true,
                  ),

            // --- Dynamic Spawner ---
            if (_autoSpawn)
              _Spawner(
                interval: const Duration(milliseconds: 800),
                onTick: () {
                  setState(() {
                    _spawnBody();
                  });
                },
              ),

            // --- Dynamic Bodies ---
            for (final body in _bodies)
              body.isCircle
                  ? FlashRigidBody.circle(
                      key: body.key,
                      name: 'Body_${body.key}',
                      position: body.position,
                      radius: body.size,
                      color: body.color,
                      debugDraw: true,
                    )
                  : FlashRigidBody.square(
                      key: body.key,
                      name: 'Body_${body.key}',
                      position: body.position,
                      size: body.size * 2, // Width = Radius * 2
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
  final Key key;
  final bool isCircle;
  final v.Vector3 position;
  final double size;
  final Color color;

  _BodyData({
    required this.key,
    required this.isCircle,
    required this.position,
    required this.size,
    required this.color,
  });
}

// Logic widget to drive the spawning loop
class _Spawner extends StatefulWidget {
  final Duration interval;
  final VoidCallback onTick;

  const _Spawner({required this.interval, required this.onTick});

  @override
  State<_Spawner> createState() => _SpawnerState();
}

class _SpawnerState extends State<_Spawner> {
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() async {
    while (mounted) {
      await Future.delayed(widget.interval);
      if (mounted) {
        widget.onTick();
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
