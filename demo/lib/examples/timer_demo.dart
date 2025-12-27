import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Timer Demo showcasing FTimer functionality.
/// - A repeating timer spawns circles.
/// - A one-shot timer changes color.
/// - Visual countdown display.
class TimerDemo extends StatefulWidget {
  const TimerDemo({super.key});

  @override
  State<TimerDemo> createState() => _TimerDemoState();
}

class _TimerDemoState extends State<TimerDemo> {
  final List<_SpawnedCircle> _circles = [];
  final Random _rnd = Random();

  // Timer references
  FTimer? _spawnTimer;
  FTimer? _flashTimer;

  // State for UI
  final ValueNotifier<double> spawnTimerProgress = ValueNotifier(0.0);
  final ValueNotifier<int> spawnCount = ValueNotifier(0);
  final ValueNotifier<Color> flashColor = ValueNotifier(Colors.cyanAccent);
  final ValueNotifier<String> flashStatus = ValueNotifier("Waiting...");

  @override
  void initState() {
    super.initState();
    FEngine.init();
  }

  @override
  void dispose() {
    spawnTimerProgress.dispose();
    spawnCount.dispose();
    flashColor.dispose();
    flashStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: FScene(
        autoUpdate: true,
        onReady: _setupScene,
        // Flash scene (Z-sorted automatically)
        scene: [
          FCamera(position: v.Vector3(0, 0, 500), fov: 60),
          ..._circles.map((c) => FCircle(position: c.position.clone(), radius: c.radius, color: c.color)),
        ],
        // Flutter UI overlay
        overlay: [
          // HUD
          Positioned(
            top: 60,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⏱️ Timer Demo',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Spawn Timer Progress
                  ValueListenableBuilder<double>(
                    valueListenable: spawnTimerProgress,
                    builder: (_, progress, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spawn Timer: ${(progress * 100).toInt()}%',
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 150,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: spawnCount,
                    builder: (_, count, __) =>
                        Text('Spawned: $count circles', style: const TextStyle(color: Colors.white70)),
                  ),

                  const SizedBox(height: 16),
                  const Text('One-Shot Timer:', style: TextStyle(color: Colors.cyanAccent)),
                  ValueListenableBuilder<String>(
                    valueListenable: flashStatus,
                    builder: (_, status, __) => Text(status, style: const TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),

          // Flash indicator
          Positioned(
            top: 60,
            right: 20,
            child: ValueListenableBuilder<Color>(
              valueListenable: flashColor,
              builder: (_, color, __) => Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)],
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            bottom: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Restart button
          Positioned(
            bottom: 40,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _restartTimers,
              icon: const Icon(Icons.refresh),
              label: const Text('Restart'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _setupScene(FEngine engine) {
    // 1. Repeating Spawn Timer (every 1.5 seconds)
    _spawnTimer = FTimer(name: 'SpawnTimer', waitTime: 1.5, oneShot: false, autoStart: true);

    _spawnTimer!.timeout.connect((_) {
      // Spawn a random circle
      final circle = _SpawnedCircle(
        position: v.Vector3((_rnd.nextDouble() - 0.5) * 300, (_rnd.nextDouble() - 0.5) * 200, 0),
        radius: 10 + _rnd.nextDouble() * 20,
        color: Color.fromARGB(255, _rnd.nextInt(256), _rnd.nextInt(256), _rnd.nextInt(256)),
      );

      setState(() {
        _circles.add(circle);
        spawnCount.value++;

        // Keep max 20 circles
        if (_circles.length > 20) {
          _circles.removeAt(0);
        }
      });
    });

    engine.scene.addChild(_spawnTimer!);

    // 2. One-Shot Flash Timer (3 seconds)
    _flashTimer = FTimer(name: 'FlashTimer', waitTime: 3.0, oneShot: true, autoStart: true);

    _flashTimer!.timeout.connect((_) {
      flashColor.value = Colors.greenAccent;
      flashStatus.value = "✓ Completed!";
    });

    engine.scene.addChild(_flashTimer!);

    // Update progress in engine loop
    engine.onUpdate = () {
      if (_spawnTimer != null && _spawnTimer!.isRunning) {
        spawnTimerProgress.value = 1.0 - (_spawnTimer!.timeLeft / _spawnTimer!.waitTime);
      }

      if (_flashTimer != null && _flashTimer!.isRunning) {
        flashStatus.value = "⏳ ${_flashTimer!.timeLeft.toStringAsFixed(1)}s remaining";
      }
    };
  }

  void _restartTimers() {
    setState(() {
      _circles.clear();
      spawnCount.value = 0;
      flashColor.value = Colors.cyanAccent;
      flashStatus.value = "Waiting...";
    });

    _spawnTimer?.start();
    _flashTimer?.start();
  }
}

class _SpawnedCircle {
  final v.Vector3 position;
  final double radius;
  final Color color;

  _SpawnedCircle({required this.position, required this.radius, required this.color});
}
