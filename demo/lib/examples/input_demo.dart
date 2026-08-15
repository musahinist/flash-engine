import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';
import '../shared/virtual_joystick.dart';

/// [FInputSystem]: keyboard actions and pointer gestures.
///
/// Actions are registered by name, so the same movement code serves WASD, the
/// arrow keys and the on-screen stick. Gestures — double tap, long press,
/// swipe, pinch — are read off the input system rather than wired up with
/// individual Flutter recognisers.
class InputDemoExample extends StatefulWidget {
  const InputDemoExample({super.key});

  @override
  State<InputDemoExample> createState() => _InputDemoExampleState();
}

class _InputDemoExampleState extends State<InputDemoExample> {
  static const double _speed = 300;

  final v.Vector3 _playerPos = v.Vector3.zero();
  final v.Vector2 _stick = v.Vector2.zero();

  FEngine? _engine;
  String _lastGesture = 'none';
  int _touchCount = 0;
  double _pinchScale = 1;

  /// Registers actions and the frame callback exactly once.
  ///
  /// This used to happen inside `build`, and the callback called `setState`
  /// every frame — so each rebuild registered another listener, and each
  /// listener caused the next rebuild. The callback also opened with
  /// `final dt = 1 / 60.0;`, shadowing the real delta it had just been handed.
  void _attach(FEngine engine) {
    if (_engine != null) return;
    _engine = engine;

    engine.input.registerActions([
      FInputAction.moveUp,
      FInputAction.moveDown,
      FInputAction.moveLeft,
      FInputAction.moveRight,
      FInputAction.jump,
    ]);

    engine.addUpdateListener(_step);
  }

  void _step(double dt) {
    final input = _engine!.input;

    // The input system reports screen coordinates: +y is down. The world is
    // Y-up, so y is negated on the way in.
    final movement = input.getMovementVector();
    _playerPos.x += (movement.dx + _stick.x) * _speed * dt;
    _playerPos.y -= (movement.dy + _stick.y) * _speed * dt;

    _playerPos.x = _playerPos.x.clamp(-350, 350);
    _playerPos.y = _playerPos.y.clamp(-200, 200);

    final gesture = _describeGesture(input);
    if (input.isDoubleTap) _playerPos.setValues(0, 0, 0);

    // Only rebuild when something a reader can see has actually changed. The
    // player's position is read straight out of the vector by the scene
    // builder, so movement alone does not need one.
    if (gesture != null || input.touchCount != _touchCount) {
      setState(() {
        _touchCount = input.touchCount;
        _pinchScale = input.pinchScale;
        if (gesture != null) _lastGesture = gesture;
      });
    }
  }

  String? _describeGesture(FInputSystem input) {
    if (input.isDoubleTap) return 'double tap';
    if (input.isLongPressTriggered) return 'long press';
    if (input.swipeDirection != null) return 'swipe ${input.swipeDirection!.name}';
    if (input.isPinching) return 'pinch ${input.pinchScale.toStringAsFixed(2)}x';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Input',
      subtitle: 'Named actions for movement, and gestures off the input system.',
      controls: const [
        DemoPanel(
          title: 'Controls',
          children: [
            DemoLegend(
              entries: [
                (color: DemoTheme.accent, label: 'WASD or arrow keys'),
                (color: DemoTheme.accentAlt, label: 'the stick, bottom left'),
                (color: DemoTheme.warning, label: 'double tap to recentre'),
              ],
            ),
          ],
        ),
      ],
      readouts: [
        DemoStat(label: 'Last gesture', value: _lastGesture, tint: DemoTheme.warning),
        DemoStat(label: 'Touches', value: '$_touchCount'),
        DemoStat(label: 'Pinch', value: '${_pinchScale.toStringAsFixed(2)}x'),
        DemoStat(
          label: 'Position',
          value: '${_playerPos.x.toInt()}, ${_playerPos.y.toInt()}',
        ),
      ],
      hint: 'Swipe, long-press and pinch are all reported by FInputSystem.',
      overlays: [
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: VirtualJoystick(onStickDrag: _stick.setValues),
          ),
        ),
      ],
      scene: FView(
        onReady: _attach,
        child: FAnimated(
          builder: (context, elapsed) => FNodes(
            children: [
              FCamera(position: v.Vector3(0, 0, 500), fov: 60),
              FLight(position: v.Vector3(0, 0, 100), color: Colors.white, intensity: 1.5),
              // clone(), because the node widget stores what it is handed and
              // this vector is mutated in place every frame.
              FSphere(position: _playerPos.clone(), radius: 30, color: DemoTheme.accent),
            ],
          ),
        ),
      ),
    );
  }
}
