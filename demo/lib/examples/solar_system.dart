import 'dart:math';
import 'dart:ui' as ui;

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';

/// Nested [FNodeGroup]s: a child inherits its parent's transform.
///
/// The moon is a child of the earth, which is a child of an orbit group, which
/// is a child of the sun. Nothing computes an orbital position — each level
/// only spins, and the hierarchy composes them. Rotating the sun's group takes
/// everything with it.
///
/// Also shows `FSphere.texture`. The textures are drawn at runtime rather than
/// loaded: this demo used to read PNGs from an absolute path on the original
/// author's machine, so on anyone else's it silently fell back to flat colours,
/// and on a phone `File` would have thrown.
class SolarSystemExample extends StatefulWidget {
  const SolarSystemExample({super.key});

  @override
  State<SolarSystemExample> createState() => _SolarSystemExampleState();
}

class _SolarSystemExampleState extends State<SolarSystemExample> {
  ui.Image? _sun;
  ui.Image? _earth;
  ui.Image? _mars;

  double _pitch = -0.3;
  double _yaw = 0;
  double _speed = 1;
  bool _textured = true;

  @override
  void initState() {
    super.initState();
    _buildTextures();
  }

  @override
  void dispose() {
    _sun?.dispose();
    _earth?.dispose();
    _mars?.dispose();
    super.dispose();
  }

  Future<void> _buildTextures() async {
    final sun = await _bandedTexture(
      const [Color(0xFFFFD16B), Color(0xFFFF8A3D), Color(0xFFFFF0C2)],
      bands: 9,
      seed: 1,
    );
    final earth = await _bandedTexture(
      const [Color(0xFF1D4E89), Color(0xFF2E8B57), Color(0xFF1D4E89), Color(0xFFEFEFEF)],
      bands: 7,
      seed: 2,
    );
    final mars = await _bandedTexture(
      const [Color(0xFF9C4A2A), Color(0xFFC96A3E), Color(0xFF7A3A22)],
      bands: 8,
      seed: 3,
    );
    if (!mounted) {
      sun.dispose();
      earth.dispose();
      mars.dispose();
      return;
    }
    setState(() {
      _sun = sun;
      _earth = earth;
      _mars = mars;
    });
  }

  /// A cheap latitude-banded map, enough to read as a rotating surface.
  static Future<ui.Image> _bandedTexture(
    List<Color> palette, {
    required int bands,
    required int seed,
  }) async {
    const size = 256.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final random = Random(seed);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = palette.first,
    );
    for (int i = 0; i < bands; i++) {
      final y = i * size / bands;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size, size / bands),
        Paint()..color = palette[i % palette.length],
      );
    }
    for (int i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size, random.nextDouble() * size),
        4 + random.nextDouble() * 16,
        Paint()..color = Colors.black.withValues(alpha: 0.06 + random.nextDouble() * 0.12),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.round(), size.round());
    picture.dispose();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Solar System',
      subtitle: 'Nested FNodeGroups: each level only spins, the hierarchy does the rest.',
      controls: [
        DemoPanel(
          children: [
            DemoSlider(
              label: 'Orbit speed',
              value: _speed,
              min: 0,
              max: 3,
              fractionDigits: 2,
              suffix: 'x',
              onChanged: (value) => setState(() => _speed = value),
            ),
          ],
        ),
        DemoToggle(
          label: 'Textures',
          value: _textured,
          onChanged: (value) => setState(() => _textured = value),
        ),
        DemoButton(
          label: 'Reset view',
          icon: Icons.center_focus_strong_rounded,
          onPressed: () => setState(() {
            _pitch = -0.3;
            _yaw = 0;
          }),
        ),
      ],
      hint: 'Drag to orbit the camera. The moon is a grandchild of the sun.',
      scene: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => setState(() {
          _yaw += details.delta.dx * 0.005;
          _pitch = (_pitch + details.delta.dy * 0.005).clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
        }),
        child: ColoredBox(
          color: const Color(0xFF000814),
          child: FView(
            enableInputCapture: false,
            child: FAnimated(
              builder: (context, elapsed) {
                final t = elapsed * _speed;
                return FNodes(
                  children: [
                    FCamera(
                      name: 'MainCamera',
                      position: v.Vector3(0, 500, 1200),
                      rotation: v.Vector3(_pitch, -_yaw, 0),
                    ),
                    FLight(
                      name: 'SunLight',
                      position: v.Vector3(0, 0, 0),
                      intensity: 2.5,
                      color: Colors.white,
                    ),

                    for (int i = 0; i < 150; i++)
                      FBox(
                        position: v.Vector3(
                          sin(i * 1.5) * 2000,
                          cos(i * 2.1) * 2000,
                          -1500 + (i % 5) * 200,
                        ),
                        width: 4,
                        height: 4,
                        color: Colors.white24,
                        billboard: true,
                      ),

                    FSphere(
                      name: 'Sun',
                      radius: 100,
                      color: Colors.orange,
                      texture: _textured ? _sun : null,
                      rotation: v.Vector3(0, t * 0.2, 0),
                      child: FNodes(
                        children: [
                          FNodeGroup(
                            name: 'EarthOrbit',
                            rotation: v.Vector3(0, t, 0),
                            child: FSphere(
                              name: 'Earth',
                              position: v.Vector3(400, 0, 0),
                              radius: 40,
                              color: Colors.blue,
                              texture: _textured ? _earth : null,
                              rotation: v.Vector3(0, t * 3, 0),
                              child: FNodeGroup(
                                name: 'MoonOrbit',
                                rotation: v.Vector3(0, t * 2, 0),
                                child: FSphere(
                                  name: 'Moon',
                                  position: v.Vector3(90, 0, 0),
                                  radius: 14,
                                  color: Colors.grey[400]!,
                                ),
                              ),
                            ),
                          ),
                          FNodeGroup(
                            name: 'MarsOrbit',
                            rotation: v.Vector3(0, t * 0.6, 0),
                            child: FSphere(
                              name: 'Mars',
                              position: v.Vector3(-650, 30, 0),
                              radius: 30,
                              color: Colors.redAccent,
                              texture: _textured ? _mars : null,
                              rotation: v.Vector3(0, t * 2.5, 0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
