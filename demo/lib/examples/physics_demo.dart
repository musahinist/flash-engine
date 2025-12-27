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
  // Spawner state
  bool _autoSpawn = false;
  int _spawnCount = 0;

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
                _spawnCount = 0;
                _autoSpawn = false;
              });
            },
          ),
        ],
      ),
      body: Flash(
        autoUpdate: true,
        child: Stack(
          children: [
            FlashCamera(position: v.Vector3(0, 0, 1000)),

            // --- Static World Geometry (Walls & Pegs) ---

            // Floor (Y is Negative, so Bottom is ~ -400)
            FlashStaticBody(
              name: 'Floor',
              position: v.Vector3(0, -400, 0),
              width: 800,
              height: 40,
              color: Colors.grey[800]!,
            ),

            // Left Wall
            FlashStaticBody(
              name: 'LeftWall',
              position: v.Vector3(-380, 0, 0),
              width: 40,
              height: 800,
              color: Colors.grey[800]!,
            ),

            // Right Wall
            FlashStaticBody(
              name: 'RightWall',
              position: v.Vector3(380, 0, 0),
              width: 40,
              height: 800,
              color: Colors.grey[800]!,
            ),

            // Pachinko Pegs (Static) - Staggered Grid
            for (int row = 0; row < 6; row++)
              for (int col = -4; col <= 4; col++)
                if ((row % 2 == 0 && col % 2 == 0) || (row % 2 != 0 && col % 2 != 0))
                  FlashStaticBody(
                    name: 'Peg_${row}_$col',
                    position: v.Vector3(col * 60.0, 200.0 - row * 70.0, 0),
                    width: 20,
                    height: 20,
                    color: Colors.blueGrey,
                  ),

            // --- Dynamic Spawner Logic ---
            if (_autoSpawn)
              _Spawner(
                interval: const Duration(milliseconds: 300),
                onTick: () {
                  setState(() {
                    _spawnCount++;
                  });
                },
              ),

            // Dynamic Balls List
            for (int i = 0; i < _spawnCount; i++)
              FlashRigidBody.circle(
                key: ValueKey('ball_$i'),
                name: 'Ball_$i',
                // Spawn at top center with slight random X jitter
                position: v.Vector3((Random().nextDouble() - 0.5) * 40, 350, 0),
                radius: 12,
                color: Colors.accents[i % Colors.accents.length],
                debugDraw: true,
              ),
          ],
        ),
      ),
    );
  }
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
