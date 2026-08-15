import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// The declarative half of the animation API.
///
/// [FTweenBuilder] runs one value from A to B and rebuilds with it.
/// [FAnimated] hands you `engine.elapsed` and gets out of the way — for
/// anything you would rather write as a function of time than as a tween.
///
/// The imperative side, [FTweenManager], has its own example.
class TweenBuilderDemo extends StatefulWidget {
  const TweenBuilderDemo({super.key});

  @override
  State<TweenBuilderDemo> createState() => _TweenBuilderDemoState();
}

class _TweenBuilderDemoState extends State<TweenBuilderDemo> {
  static const List<({String name, EasingFunction fn})> _easings = [
    (name: 'linear', fn: FEasing.linear),
    (name: 'easeInOutQuad', fn: FEasing.easeInOutQuad),
    (name: 'easeOutCubic', fn: FEasing.easeOutCubic),
    (name: 'easeInCubic', fn: FEasing.easeInCubic),
  ];

  int _easingIndex = 1;
  bool _yoyo = true;

  /// Changing the key restarts the tween, which is how you replay one.
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final easing = _easings[_easingIndex];

    return DemoPage(
      title: 'Tween Widgets',
      subtitle: 'FTweenBuilder and FAnimated, without touching a manager.',
      controls: [
        DemoPanel(
          title: 'Easing',
          children: [
            for (int i = 0; i < _easings.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DemoButton(
                  label: _easings[i].name,
                  selected: i == _easingIndex,
                  width: 200,
                  onPressed: () => setState(() {
                    _easingIndex = i;
                    _generation++;
                  }),
                ),
              ),
          ],
        ),
        DemoToggle(
          label: 'Yoyo',
          value: _yoyo,
          onChanged: (value) => setState(() {
            _yoyo = value;
            _generation++;
          }),
        ),
        DemoButton(
          label: 'Replay',
          icon: Icons.replay_rounded,
          onPressed: () => setState(() => _generation++),
        ),
      ],
      hint: 'Top row: one FTweenBuilder each. Bottom: FAnimated, a function of elapsed time.',
      scene: FView(
        child: Stack(
          children: [
            FCamera(position: v.Vector3(0, 0, 950)),

            // FTweenBuilder over a double, driving position.
            FTweenBuilder<double>(
              key: ValueKey('x_$_generation$_easingIndex$_yoyo'),
              from: -320,
              to: 320,
              duration: const Duration(milliseconds: 1800),
              easing: easing.fn,
              repeat: -1,
              yoyo: _yoyo,
              builder: (context, x) => FSphere(
                position: v.Vector3(x, 190, 0),
                radius: 34,
                color: DemoTheme.accent,
              ),
            ),

            // The same tween driving a different property. A tween is over a
            // value, not over a node.
            FTweenBuilder<double>(
              key: ValueKey('scale_$_generation$_easingIndex$_yoyo'),
              from: 0.4,
              to: 1.6,
              duration: const Duration(milliseconds: 1800),
              easing: easing.fn,
              repeat: -1,
              yoyo: _yoyo,
              builder: (context, scale) => FBox(
                position: v.Vector3(0, 40, 0),
                width: 90 * scale,
                height: 90 * scale,
                color: DemoTheme.accentAlt,
              ),
            ),

            // A custom type needs a lerp; without one FTweenBuilder cannot
            // know how to get between the two values.
            FTweenBuilder<Color>(
              key: ValueKey('color_$_generation$_easingIndex$_yoyo'),
              from: DemoTheme.positive,
              to: DemoTheme.danger,
              duration: const Duration(milliseconds: 1800),
              easing: easing.fn,
              repeat: -1,
              yoyo: _yoyo,
              lerp: (a, b, t) => Color.lerp(a, b, t)!,
              builder: (context, color) => FCircle(
                position: v.Vector3(0, -110, 0),
                radius: 46,
                color: color,
              ),
            ),

            // FAnimated: no tween at all, just a function of elapsed time.
            // Better than a tween whenever the motion is periodic.
            FAnimated(
              builder: (context, elapsed) => FNodes(
                children: [
                  for (int i = 0; i < 7; i++)
                    FCircle(
                      position: v.Vector3(
                        -270 + i * 90.0,
                        -260 + sin(elapsed * 2.4 + i * 0.7) * 46,
                        0,
                      ),
                      radius: 13,
                      color: DemoTheme.warning,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
