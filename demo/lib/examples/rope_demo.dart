import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FRope]: a verlet chain, solved in Dart.
///
/// The rope is a widget rather than a node: it owns its simulation, reports
/// positions through `onUpdate`, and leaves drawing to a painter you supply.
/// That is the right shape for it — a rope is a strand of points, not something
/// the scene graph needs a transform for.
///
/// Constraint iterations are the interesting control. One pass leaves the rope
/// stretchy; more passes make it behave like a cord, at linear cost.
class RopeDemo extends StatefulWidget {
  const RopeDemo({super.key});

  @override
  State<RopeDemo> createState() => _RopeDemoState();
}

class _RopeDemoState extends State<RopeDemo> {
  double _segments = 22;
  double _length = 420;
  double _iterations = 6;
  double _damping = 0.98;
  Offset? _anchor;

  int _points = 0;

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Rope',
      subtitle: 'FRope: verlet integration with a constraint pass per frame.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Segments',
              value: _segments,
              min: 4,
              max: 60,
              fractionDigits: 0,
              onChanged: (value) => setState(() => _segments = value),
            ),
            DemoSlider(
              label: 'Length',
              value: _length,
              min: 100,
              max: 800,
              fractionDigits: 0,
              onChanged: (value) => setState(() => _length = value),
            ),
            DemoSlider(
              label: 'Constraint passes',
              value: _iterations,
              min: 1,
              max: 20,
              fractionDigits: 0,
              onChanged: (value) => setState(() => _iterations = value),
            ),
            DemoSlider(
              label: 'Damping',
              value: _damping,
              min: 0.85,
              max: 1,
              fractionDigits: 3,
              onChanged: (value) => setState(() => _damping = value),
            ),
          ],
        ),
        DemoButton(
          label: 'Recentre',
          icon: Icons.center_focus_strong_rounded,
          onPressed: () => setState(() => _anchor = null),
        ),
      ],
      readouts: [
        DemoStat(label: 'Points', value: '$_points'),
        DemoStat(label: 'Passes', value: '${_iterations.round()}'),
      ],
      hint: 'Drag to move the anchor. One pass is stretchy; more makes it a cord.',
      scene: LayoutBuilder(
        builder: (context, constraints) {
          final centre = Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.22);
          final anchor = _anchor ?? centre;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) => setState(() => _anchor = details.localPosition),
            onPanUpdate: (details) => setState(() => _anchor = details.localPosition),
            child: FView(
              // The rope drives its own repaint; nothing here needs the whole
              // tree rebuilt every frame.
              autoUpdate: false,
              enableInputCapture: false,
              child: Stack(
                children: [
                  FCamera(position: v.Vector3(0, 0, 900)),
                  FRope(
                    // Rebuilding on a parameter change is how the rope picks
                    // up a new segment count.
                    key: ValueKey('${_segments.round()}_${_length.round()}'),
                    anchorPosition: v.Vector3(
                      anchor.dx - constraints.maxWidth / 2,
                      constraints.maxHeight / 2 - anchor.dy,
                      0,
                    ),
                    segments: _segments.round(),
                    length: _length,
                    damping: _damping,
                    constraintIterations: _iterations.round(),
                    onUpdate: (positions) {
                      if (positions.length != _points) {
                        // Reported outside the build phase; the rope calls this
                        // from its own tick.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _points = positions.length);
                        });
                      }
                    },
                    painter: (positions) => _RopePainter(positions),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RopePainter extends CustomPainter {
  _RopePainter(this.positions);

  final List<v.Vector3> positions;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;
    final centre = Offset(size.width / 2, size.height / 2);

    Offset toScreen(v.Vector3 p) => centre + Offset(p.x, -p.y);

    final path = Path()..moveTo(toScreen(positions.first).dx, toScreen(positions.first).dy);
    for (int i = 1; i < positions.length; i++) {
      final p = toScreen(positions[i]);
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = DemoTheme.accent.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = DemoTheme.accent,
    );

    // The anchor, and the free end.
    canvas.drawCircle(toScreen(positions.first), 8, Paint()..color = DemoTheme.textPrimary);
    canvas.drawCircle(toScreen(positions.last), 11, Paint()..color = DemoTheme.accentAlt);
  }

  @override
  bool shouldRepaint(_RopePainter oldDelegate) => true;
}
