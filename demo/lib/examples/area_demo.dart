import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FArea]: a body that reports when something touches it.
///
/// Two zones sit in the path of falling bodies and light up while occupied.
/// Note what an area is *not* — see the hint. The solver has no sensor
/// handling, so an area still blocks what enters it.
class AreaDemo extends StatefulWidget {
  const AreaDemo({super.key});

  @override
  State<AreaDemo> createState() => _AreaDemoState();
}

class _AreaDemoState extends State<AreaDemo> {
  final List<({Key key, v.Vector3 position, Color color})> _drops = [];
  final Random _random = Random(3);

  bool _leftOccupied = false;
  bool _rightOccupied = false;
  int _leftEntries = 0;
  int _rightEntries = 0;

  static const int _maxDrops = 40;

  void _drop({double? x}) {
    setState(() {
      if (_drops.length >= _maxDrops) _drops.removeAt(0);
      _drops.add((
        key: UniqueKey(),
        position: v.Vector3(x ?? (_random.nextDouble() - 0.5) * 500, 380, 0),
        color: _random.nextBool() ? DemoTheme.accent : DemoTheme.accentAlt,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Trigger Areas',
      subtitle: 'FArea reports overlap without you polling for it.',
      accent: DemoTheme.positive,
      controls: [
        DemoButton(
          label: 'Drop into left',
          icon: Icons.west_rounded,
          tint: DemoTheme.accent,
          onPressed: () => _drop(x: -180),
        ),
        DemoButton(
          label: 'Drop into right',
          icon: Icons.east_rounded,
          tint: DemoTheme.accentAlt,
          onPressed: () => _drop(x: 180),
        ),
        DemoButton(label: 'Drop anywhere', icon: Icons.casino_rounded, onPressed: _drop),
        DemoButton(
          label: 'Clear',
          icon: Icons.refresh_rounded,
          tint: DemoTheme.danger,
          onPressed: () => setState(_drops.clear),
        ),
      ],
      readouts: [
        DemoStat(
          label: 'Left zone',
          value: _leftOccupied ? 'OCCUPIED' : 'empty',
          tint: _leftOccupied ? DemoTheme.accent : DemoTheme.textMuted,
        ),
        DemoStat(label: 'Left entries', value: '$_leftEntries'),
        DemoStat(
          label: 'Right zone',
          value: _rightOccupied ? 'OCCUPIED' : 'empty',
          tint: _rightOccupied ? DemoTheme.accentAlt : DemoTheme.textMuted,
        ),
        DemoStat(label: 'Right entries', value: '$_rightEntries'),
      ],
      hint: 'An area is not a sensor yet: it still blocks what lands on it.',
      scene: FView(
        autoUpdate: false,
        child: Stack(
          children: [
            FCamera(position: v.Vector3(0, 0, 1100)),

            FStaticBody(
              name: 'Floor',
              position: v.Vector3(0, -400, 0),
              width: 1000,
              height: 40,
              color: Colors.white10,
              debugDraw: true,
            ),

            // The zones. Each is a static body that happens to tell you when
            // something is resting on it.
            FArea(
              name: 'LeftZone',
              shapeType: FPhysics.box,
              width: 220,
              height: 40,
              position: v.Vector3(-180, -120, 0),
              onCollisionStart: () => setState(() {
                _leftOccupied = true;
                _leftEntries++;
              }),
              onCollisionEnd: () => setState(() => _leftOccupied = false),
              child: FBox(
                width: 220,
                height: 40,
                color: _leftOccupied
                    ? DemoTheme.accent.withValues(alpha: 0.55)
                    : DemoTheme.accent.withValues(alpha: 0.14),
              ),
            ),
            FArea(
              name: 'RightZone',
              shapeType: FPhysics.box,
              width: 220,
              height: 40,
              position: v.Vector3(180, 40, 0),
              onCollisionStart: () => setState(() {
                _rightOccupied = true;
                _rightEntries++;
              }),
              onCollisionEnd: () => setState(() => _rightOccupied = false),
              child: FBox(
                width: 220,
                height: 40,
                color: _rightOccupied
                    ? DemoTheme.accentAlt.withValues(alpha: 0.55)
                    : DemoTheme.accentAlt.withValues(alpha: 0.14),
              ),
            ),

            for (final drop in _drops)
              FRigidBody.circle(
                key: drop.key,
                position: drop.position,
                radius: 16,
                color: drop.color,
                debugDraw: true,
              ),
          ],
        ),
      ),
    );
  }
}
