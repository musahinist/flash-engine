import 'dart:math';
import 'dart:ui' as ui;

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FSprite]: a `dart:ui` image drawn as a node.
///
/// The demo has no image assets, so it draws one at startup with a
/// `PictureRecorder` — which is also the answer to "how do I get a `ui.Image`
/// into a sprite when it did not come from an asset". `FSprite.fromAsset` is
/// the usual route and is a one-liner.
class SpriteDemo extends StatefulWidget {
  const SpriteDemo({super.key});

  @override
  State<SpriteDemo> createState() => _SpriteDemoState();
}

class _SpriteDemoState extends State<SpriteDemo> {
  ui.Image? _sheet;
  double _scale = 1;
  bool _spin = true;

  @override
  void initState() {
    super.initState();
    _buildSheet();
  }

  @override
  void dispose() {
    // A ui.Image holds GPU-side memory and is not collected for you.
    _sheet?.dispose();
    super.dispose();
  }

  /// Paints a four-frame sheet, 64x64 per frame, and rasterises it.
  Future<void> _buildSheet() async {
    const frame = 64.0;
    const frames = 4;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const palette = [
      DemoTheme.accent,
      DemoTheme.accentAlt,
      DemoTheme.positive,
      DemoTheme.warning,
    ];

    for (int i = 0; i < frames; i++) {
      final origin = Offset(i * frame, 0);
      final centre = origin + const Offset(frame / 2, frame / 2);
      final paint = Paint()..color = palette[i];

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: centre, width: frame - 8, height: frame - 8),
          const Radius.circular(10),
        ),
        Paint()..color = palette[i].withValues(alpha: 0.28),
      );

      // A wedge that rotates a quarter turn per frame, so a flipbook reads as
      // motion rather than as four unrelated pictures.
      final sweep = Path()
        ..moveTo(centre.dx, centre.dy)
        ..arcTo(
          Rect.fromCircle(center: centre, radius: frame / 2 - 10),
          i * pi / 2,
          pi / 2,
          false,
        )
        ..close();
      canvas.drawPath(sweep, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage((frame * frames).round(), frame.round());
    picture.dispose();

    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _sheet = image);
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;

    return DemoPage(
      title: 'Sprites',
      subtitle: 'FSprite draws a ui.Image as a node in the scene graph.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Scale',
              value: _scale,
              min: 0.4,
              max: 2.5,
              fractionDigits: 2,
              onChanged: (value) => setState(() => _scale = value),
            ),
          ],
        ),
        DemoToggle(label: 'Spin', value: _spin, onChanged: (v) => setState(() => _spin = v)),
      ],
      readouts: [
        DemoStat(
          label: 'Sheet',
          value: sheet == null ? 'building…' : '${sheet.width}x${sheet.height}',
        ),
      ],
      hint: 'The sheet is drawn at runtime with a PictureRecorder — no asset needed.',
      scene: FView(
        child: sheet == null
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  FCamera(position: v.Vector3(0, 0, 900)),

                  // The whole sheet, unscaled, so the frames are visible as
                  // what they are.
                  FSprite(
                    image: sheet,
                    width: 512,
                    height: 128,
                    position: v.Vector3(0, 250, 0),
                  ),
                  FLabel(
                    text: 'the sheet',
                    position: v.Vector3(0, 155, 0),
                    style: const TextStyle(color: DemoTheme.textMuted, fontSize: 13),
                  ),

                  // Sprites are nodes: they take a transform like anything
                  // else, and FAnimated is enough to drive one.
                  FAnimated(
                    builder: (context, elapsed) => FNodes(
                      children: [
                        for (int i = 0; i < 5; i++)
                          FSprite(
                            image: sheet,
                            width: 128 * _scale,
                            height: 128 * _scale,
                            position: v.Vector3(
                              -320 + i * 160.0,
                              -80 + sin(elapsed * 1.8 + i) * 40,
                              0,
                            ),
                            rotation: v.Vector3(0, 0, _spin ? elapsed * (i.isEven ? 1 : -1) : 0),
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
