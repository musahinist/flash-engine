import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FProfiler]: where the frame actually goes.
///
/// `FEngine.fps` only reports how often the ticker fires, which on a 60 Hz
/// display is 60 whether the frame used 2 ms of its budget or 15. The profiler
/// times each section of the loop instead, so you can see which part grows as
/// you add load.
///
/// It is off by default — the timing calls are cheap but not free.
class ProfilerDemo extends StatefulWidget {
  const ProfilerDemo({super.key});

  @override
  State<ProfilerDemo> createState() => _ProfilerDemoState();
}

class _ProfilerDemoState extends State<ProfilerDemo> {
  static const double _budgetMs = 1000 / 60;

  int _spinners = 200;
  int _bodies = 0;
  bool _particles = false;

  FEngine? _engine;
  final Random _random = Random(5);

  /// Enables the profiler on whichever engine `FView` built for us, once.
  void _attach(FEngine engine) {
    if (identical(_engine, engine)) return;
    _engine = engine;
    engine.profiler.enabled = true;
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Profiler',
      subtitle: 'FProfiler times each phase of the frame, not just the tick rate.',
      accent: DemoTheme.warning,
      controlsWidth: 250,
      controls: [
        DemoPanel(
          title: 'Load',
          tint: DemoTheme.warning,
          children: [
            DemoSlider(
              label: 'Spinning nodes',
              value: _spinners.toDouble(),
              min: 0,
              max: 1500,
              fractionDigits: 0,
              tint: DemoTheme.warning,
              onChanged: (value) => setState(() => _spinners = value.round()),
            ),
            DemoSlider(
              label: 'Rigid bodies',
              value: _bodies.toDouble(),
              min: 0,
              max: 300,
              fractionDigits: 0,
              tint: DemoTheme.warning,
              onChanged: (value) => setState(() => _bodies = value.round()),
            ),
          ],
        ),
        DemoToggle(
          label: 'Particles',
          value: _particles,
          tint: DemoTheme.warning,
          onChanged: (value) => setState(() => _particles = value),
        ),
        DemoButton(
          label: 'Reset samples',
          icon: Icons.restart_alt_rounded,
          onPressed: () => _engine?.profiler.reset(),
        ),
      ],
      hint: 'Drag the sliders and watch which row moves. That is the whole point of it.',
      scene: FView(
        child: Stack(
          children: [
            FCamera(position: v.Vector3(0, 0, 1400)),

            FAnimated(
              builder: (context, elapsed) {
                final engine = context.flash;
                if (engine != null) _attach(engine);

                return FNodes(
                  children: [
                    for (int i = 0; i < _spinners; i++)
                      FBox(
                        position: v.Vector3(
                          cos(i * 2.399 + elapsed * 0.25) * (80 + i % 420),
                          sin(i * 2.399 + elapsed * 0.25) * (80 + i % 420),
                          0,
                        ),
                        width: 14,
                        height: 14,
                        rotation: v.Vector3(0, 0, elapsed + i.toDouble()),
                        color: Color.lerp(DemoTheme.accent, DemoTheme.accentAlt, (i % 60) / 60)!,
                      ),
                  ],
                );
              },
            ),

            if (_bodies > 0) ...[
              FStaticBody(
                name: 'ProfilerFloor',
                position: v.Vector3(0, -500, 0),
                width: 1400,
                height: 40,
                color: Colors.white10,
                debugDraw: true,
              ),
              for (int i = 0; i < _bodies; i++)
                FRigidBody.circle(
                  key: ValueKey('body_$i'),
                  position: v.Vector3(
                    (_random.nextDouble() - 0.5) * 900,
                    -420 + (i ~/ 30) * 34.0,
                    0,
                  ),
                  radius: 14,
                  color: DemoTheme.positive,
                  debugDraw: true,
                ),
            ],

            if (_particles)
              FParticles(
                config: ParticleEmitterConfig(
                  maxParticles: 60000,
                  emissionRate: 30000,
                  lifetimeMin: 1,
                  lifetimeMax: 2,
                  velocityMin: v.Vector3(-260, -260, -60),
                  velocityMax: v.Vector3(260, 260, 60),
                  gravity: v.Vector3(0, -60, 0),
                  sizeMin: 2,
                  sizeMax: 5,
                  startColor: DemoTheme.warning,
                  shapeType: 4,
                ),
              ),
          ],
        ),
      ),
      overlays: [
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(DemoTheme.edgeInset),
            child: _ProfilerReadout(budgetMs: _budgetMs),
          ),
        ),
      ],
    );
  }
}

/// Reads the profiler once per engine notification rather than per frame, and
/// only rebuilds this panel — profiling a scene is not much use if reporting it
/// rebuilds the scene.
class _ProfilerReadout extends StatelessWidget {
  const _ProfilerReadout({required this.budgetMs});

  final double budgetMs;

  @override
  Widget build(BuildContext context) {
    final engine = context.flash;
    if (engine == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final profiler = engine.profiler;
        final avg = profiler.averageFrameMs;
        final p95 = profiler.p95FrameMs;
        final over = avg > budgetMs;

        return DemoPanel(
          title: 'Frame',
          tint: over ? DemoTheme.danger : DemoTheme.warning,
          crossAxisAlignment: CrossAxisAlignment.end,
          width: 240,
          children: [
            DemoStat(
              label: 'Average',
              value: '${avg.toStringAsFixed(3)} ms',
              tint: over ? DemoTheme.danger : DemoTheme.textPrimary,
            ),
            DemoStat(label: 'p95', value: '${p95.toStringAsFixed(3)} ms'),
            DemoStat(label: 'Budget @60', value: '${budgetMs.toStringAsFixed(2)} ms'),
            const SizedBox(height: 4),
            Text(
              'Sections are printed by profiler.report();\nthe benchmark harness uses the same data.',
              textAlign: TextAlign.right,
              style: DemoTheme.body.copyWith(fontSize: 10, color: DemoTheme.textMuted),
            ),
          ],
        );
      },
    );
  }
}
