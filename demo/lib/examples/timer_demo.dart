import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FTimer]: a node that counts down and emits a signal.
///
/// Being a node is the point — a timer is driven by the same `dt` as everything
/// else, so it stops when the tree is paused and scales with slow motion,
/// unlike a `dart:async` Timer.
///
/// One timer here repeats and spawns; the other is one-shot.
class TimerDemo extends StatefulWidget {
  const TimerDemo({super.key});

  @override
  State<TimerDemo> createState() => _TimerDemoState();
}

class _TimerDemoState extends State<TimerDemo> {
  static const int _maxCircles = 20;

  final List<_SpawnedCircle> _circles = [];
  final Random _random = Random(19);

  FTimer? _spawnTimer;
  FTimer? _oneShotTimer;
  FEngine? _engine;

  // Per-frame readouts go through notifiers rather than setState, so a
  // countdown ticking at 60 Hz does not rebuild the scene with it.
  final ValueNotifier<double> _spawnProgress = ValueNotifier(0);
  final ValueNotifier<String> _oneShotStatus = ValueNotifier('waiting');
  final ValueNotifier<bool> _oneShotDone = ValueNotifier(false);

  int _spawned = 0;
  bool _paused = false;

  @override
  void dispose() {
    _spawnProgress.dispose();
    _oneShotStatus.dispose();
    _oneShotDone.dispose();
    super.dispose();
  }

  void _setup(FEngine engine) {
    if (_engine != null) return;
    _engine = engine;

    _spawnTimer = FTimer(name: 'SpawnTimer', waitTime: 1.5, oneShot: false, autoStart: true)
      ..timeout.connect((_) => _spawn());
    engine.scene.addChild(_spawnTimer!);

    _oneShotTimer = FTimer(name: 'OneShot', waitTime: 3.0, oneShot: true, autoStart: true)
      ..timeout.connect((_) {
        _oneShotDone.value = true;
        _oneShotStatus.value = 'fired';
      });
    engine.scene.addChild(_oneShotTimer!);

    // Registered once, from onReady. Doing this from build() would add a
    // listener per rebuild.
    engine.addUpdateListener((dt) {
      final spawn = _spawnTimer;
      if (spawn != null && spawn.isRunning) {
        _spawnProgress.value = 1.0 - (spawn.timeLeft / spawn.waitTime);
      }
      final once = _oneShotTimer;
      if (once != null && once.isRunning) {
        _oneShotStatus.value = '${once.timeLeft.toStringAsFixed(1)}s left';
      }
    });
  }

  void _spawn() {
    if (!mounted) return;
    setState(() {
      if (_circles.length >= _maxCircles) _circles.removeAt(0);
      _circles.add(
        _SpawnedCircle(
          position: v.Vector3(
            (_random.nextDouble() - 0.5) * 500,
            (_random.nextDouble() - 0.5) * 320,
            0,
          ),
          radius: 10 + _random.nextDouble() * 20,
          color: HSLColor.fromAHSL(1, _random.nextDouble() * 360, 0.7, 0.6).toColor(),
        ),
      );
      _spawned++;
    });
  }

  void _restart() {
    setState(() {
      _circles.clear();
      _spawned = 0;
    });
    _oneShotDone.value = false;
    _oneShotStatus.value = 'waiting';
    _spawnTimer?.start();
    _oneShotTimer?.start();
  }

  @override
  Widget build(BuildContext context) {
    _engine?.tree.paused = _paused;

    return DemoPage(
      title: 'Timers',
      subtitle: 'FTimer is a node, so it runs on the frame loop.',
      controls: [
        DemoButton(label: 'Restart both', icon: Icons.replay_rounded, onPressed: _restart),
        DemoToggle(
          label: 'Pause the tree',
          value: _paused,
          tint: DemoTheme.warning,
          onChanged: (value) => setState(() => _paused = value),
        ),
        DemoPanel(
          title: 'Repeating timer',
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _spawnProgress,
              builder: (context, progress, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('every 1.5 s', style: DemoTheme.body),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(DemoTheme.accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        DemoPanel(
          title: 'One-shot timer',
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _oneShotDone,
              builder: (context, done, _) => ValueListenableBuilder<String>(
                valueListenable: _oneShotStatus,
                builder: (context, status, _) => Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? DemoTheme.positive : DemoTheme.warning,
                      ),
                    ),
                    const SizedBox(width: DemoTheme.gap),
                    Text(status, style: DemoTheme.body),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
      readouts: [DemoStat(label: 'Spawned', value: '$_spawned')],
      hint: 'Pause the tree: both timers stop, because dt stops.',
      scene: FScene(
        onReady: _setup,
        scene: [
          FCamera(position: v.Vector3(0, 0, 500), fov: 60),
          for (final circle in _circles)
            FCircle(position: circle.position, radius: circle.radius, color: circle.color),
        ],
      ),
    );
  }
}

class _SpawnedCircle {
  const _SpawnedCircle({required this.position, required this.radius, required this.color});

  final v.Vector3 position;
  final double radius;
  final Color color;
}
