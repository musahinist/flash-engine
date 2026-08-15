import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// Collision callbacks from the native solver triggering audio.
///
/// Two bodies slide into each other and off the walls; every impact the solver
/// reports plays a sound, rate-limited so a resting contact does not machine-gun
/// the mixer.
class AudioDemo extends StatefulWidget {
  const AudioDemo({super.key});

  @override
  State<AudioDemo> createState() => _AudioDemoState();
}

class _AudioDemoState extends State<AudioDemo> {
  late final FPhysicsSystem _physicsWorld;

  // One controller per body, created once. These used to be constructed inside
  // the build method, so every rebuild made a fresh controller and a fresh
  // cooldown timestamp — the collision callback kept a reference to whichever
  // one happened to exist when the body was created, and the rate limit reset
  // itself on every frame that rebuilt.
  late final _Slider _left;
  late final _Slider _right;

  int _impacts = 0;

  @override
  void initState() {
    super.initState();
    _physicsWorld = FPhysicsSystem(gravity: FPhysics.standardGravity);
    _left = _Slider(
      position: v.Vector3(-200, -170, 0),
      velocity: v.Vector2(300, 0),
      color: DemoTheme.accent,
      onImpact: _countImpact,
    );
    _right = _Slider(
      position: v.Vector3(200, -170, 0),
      velocity: v.Vector2(-300, 0),
      color: DemoTheme.danger,
      onImpact: _countImpact,
    );
  }

  @override
  void dispose() {
    // The world owns native memory: a body pool, a broadphase tree and the
    // solver scratch. Leaving the demo used to leak all of it.
    _physicsWorld.dispose();
    super.dispose();
  }

  void _countImpact() {
    if (!mounted) return;
    setState(() => _impacts++);
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Physics Audio',
      subtitle: 'Impacts reported by the native solver drive playback.',
      readouts: [DemoStat(label: 'Impacts', value: '$_impacts')],
      hint: 'Sounds play on impact, rate-limited to one every 100 ms per body.',
      scene: FView(
        physicsWorld: _physicsWorld,
        child: Stack(
          children: [
            FCamera(position: v.Vector3(0, 0, 800), fov: 60),
            FStaticBody(
              name: 'Floor',
              position: v.Vector3(0, -350, 0),
              width: 1200,
              height: 40,
              child: FBox(width: 1200, height: 40, color: Colors.white10),
            ),
            FStaticBody(
              name: 'LeftWall',
              position: v.Vector3(-450, 0, 0),
              width: 40,
              height: 800,
              child: FBox(width: 40, height: 800, color: Colors.white10),
            ),
            FStaticBody(
              name: 'RightWall',
              position: v.Vector3(450, 0, 0),
              width: 40,
              height: 800,
              child: FBox(width: 40, height: 800, color: Colors.white10),
            ),
            _left.build(),
            _right.build(),
          ],
        ),
      ),
    );
  }
}

/// A body that plays a sound when the solver reports a contact.
class _Slider {
  _Slider({
    required this.position,
    required this.velocity,
    required this.color,
    required this.onImpact,
  });

  final v.Vector3 position;
  final v.Vector2 velocity;
  final Color color;
  final VoidCallback onImpact;

  final FAudioController _audio = FAudioController();

  /// A resting body reports a contact every frame, so without this the mixer
  /// would be asked for a new voice 120 times a second.
  static const Duration _cooldown = Duration(milliseconds: 100);
  Duration _lastPlayed = Duration.zero;
  final Stopwatch _clock = Stopwatch()..start();

  Widget build() {
    return FRigidBody.square(
      position: position,
      initialVelocity: velocity,
      size: 40,
      onCollision: (_) {
        final now = _clock.elapsed;
        if (now - _lastPlayed < _cooldown) return;
        _lastPlayed = now;
        _audio.play();
        onImpact();
      },
      child: Stack(
        children: [
          FBox(width: 40, height: 40, color: color),
          FAudioPlayer(
            assetPath: 'asset/demo.mp3',
            controller: _audio,
            autoplay: false,
            is3D: false,
          ),
        ],
      ),
    );
  }
}
