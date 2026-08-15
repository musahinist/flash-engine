import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FLineRenderer] and [FTrailRenderer].
///
/// The wavy line is drawn once from a fixed point list; the static bodies
/// underneath it are separate, because a line renderer draws and does not
/// collide. The trail is the interesting one: it records world positions as its
/// parent moves, so it is attached to a physics body and left alone.
class RenderingDemoExample extends StatefulWidget {
  const RenderingDemoExample({super.key});

  @override
  State<RenderingDemoExample> createState() => _RenderingDemoExampleState();
}

class _RenderingDemoExampleState extends State<RenderingDemoExample> {
  late final FPhysicsSystem _physicsWorld;
  final List<v.Vector3> _pathPoints = [];

  double _trailLifetime = 1.5;
  bool _glow = true;
  int _resetKey = 0;

  @override
  void initState() {
    super.initState();
    _physicsWorld = FPhysicsSystem(gravity: FPhysics.standardGravity);
    for (int i = 0; i < 40; i++) {
      _pathPoints.add(v.Vector3((i - 20) * 50.0, sin(i * 0.4) * 80.0 - 350.0, 0));
    }
  }

  @override
  void dispose() {
    // There was a dispose() here that called super and nothing else, so the
    // native world — body pool, broadphase tree, solver scratch — leaked every
    // time this demo was opened.
    _physicsWorld.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Renderers',
      subtitle: 'FLineRenderer draws a path; FTrailRenderer records one.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Trail lifetime',
              value: _trailLifetime,
              min: 0.2,
              max: 4,
              fractionDigits: 2,
              suffix: 's',
              onChanged: (value) => setState(() => _trailLifetime = value),
            ),
          ],
        ),
        DemoToggle(label: 'Glow', value: _glow, onChanged: (v) => setState(() => _glow = v)),
        DemoButton(
          label: 'Relaunch ball',
          icon: Icons.replay_rounded,
          onPressed: () => setState(() => _resetKey++),
        ),
        DemoPanel(
          title: 'Legend',
          children: [
            DemoLegend(
              entries: const [
                (color: DemoTheme.accentAlt, label: 'line renderer, gradient'),
                (color: Colors.white24, label: 'line renderer, looped'),
                (color: DemoTheme.warning, label: 'trail renderer on a body'),
              ],
            ),
          ],
        ),
      ],
      hint: 'The wavy line is drawn; the collision under it is separate static bodies.',
      scene: FView(
        physicsWorld: _physicsWorld,
        child: FAnimated(
          builder: (context, elapsed) {
            // Was DateTime.now().millisecondsSinceEpoch, which ignores both the
            // tree being paused and any time scaling. The engine's own elapsed
            // time is right here.
            final orbit = elapsed * 1.5;

            return FNodes(
              children: [
                FCamera(position: v.Vector3(0, 0, 1800), fov: 60, far: 5000),

                FLineRenderer(
                  name: 'WavyPath',
                  points: _pathPoints,
                  width: 15,
                  glow: _glow,
                  gradient: const LinearGradient(
                    colors: [DemoTheme.accentAlt, DemoTheme.accent, DemoTheme.accentAlt],
                  ),
                ),
                ..._collisionSegments(),

                FNodeGroup(
                  position: v.Vector3(0, 200, 0),
                  rotation: v.Vector3(0, 0, orbit),
                  scale: v.Vector3.all(0.8 + sin(orbit) * 0.2),
                  child: FLineRenderer(
                    name: 'CirclePath',
                    points: _circlePoints(150, 4),
                    isLoop: true,
                    width: 12,
                    color: Colors.white24,
                  ),
                ),

                FRigidBody.circle(
                  key: ValueKey('ball_$_resetKey'),
                  name: 'TrailBall',
                  position: v.Vector3(-300, 500, 0),
                  initialVelocity: v.Vector2(400, -200),
                  radius: 30,
                  child: FNodes(
                    children: [
                      const FCircle(radius: 30, color: DemoTheme.warning),
                      FTrailRenderer(
                        lifetime: _trailLifetime,
                        startWidth: 25,
                        endWidth: 0,
                        startColor: DemoTheme.warning,
                        endColor: Colors.transparent,
                      ),
                    ],
                  ),
                ),

                FRigidBody.square(
                  key: ValueKey('obstacle_$_resetKey'),
                  name: 'DynamicObstacle',
                  position: v.Vector3(-150, 200, 0),
                  size: 60,
                  initialVelocity: v.Vector2(100, 0),
                  child: const FBox(width: 60, height: 60, color: DemoTheme.danger),
                ),

                FStaticBody(
                  name: 'LeftWall',
                  position: v.Vector3(-600, 0, 0),
                  width: 40,
                  height: 2000,
                  child: FBox(width: 40, height: 2000, color: DemoTheme.accent.withValues(alpha: 0.1)),
                ),
                FStaticBody(
                  name: 'RightWall',
                  position: v.Vector3(600, 0, 0),
                  width: 40,
                  height: 2000,
                  child: FBox(width: 40, height: 2000, color: DemoTheme.accent.withValues(alpha: 0.1)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Static bodies following the drawn path. A line renderer is only geometry;
  /// nothing collides with it.
  List<Widget> _collisionSegments() {
    return [
      for (int i = 0; i < _pathPoints.length - 1; i++)
        () {
          final p1 = _pathPoints[i];
          final p2 = _pathPoints[i + 1];
          final dx = p2.x - p1.x;
          final dy = p2.y - p1.y;
          return FStaticBody(
            name: 'Segment_$i',
            position: v.Vector3((p1.x + p2.x) / 2, (p1.y + p2.y) / 2, 0),
            rotation: v.Vector3(0, 0, atan2(dy, dx)),
            width: sqrt(dx * dx + dy * dy),
            height: 10,
          );
        }(),
    ];
  }

  List<v.Vector3> _circlePoints(double radius, int segments) {
    return List.generate(segments, (i) {
      final angle = (i / segments) * pi * 2;
      return v.Vector3(cos(angle) * radius, sin(angle) * radius, 0);
    });
  }
}
