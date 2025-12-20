import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';

class SolarSystemExample extends StatefulWidget {
  const SolarSystemExample({super.key});

  @override
  State<SolarSystemExample> createState() => _SolarSystemExampleState();
}

class _SolarSystemExampleState extends State<SolarSystemExample> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  ui.Image? _sunTexture;
  ui.Image? _earthTexture;
  ui.Image? _marsTexture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _loadTextures();
  }

  Future<void> _loadTextures() async {
    // Paths relative to the artifacts directory
    const artifactsPath = '/Users/mshn/.gemini/antigravity/brain/eeb33d0b-ef05-4a8c-afcd-e85188cc16aa';

    // We use try-catch to avoid crashing if textures are missing or not yet generated
    try {
      if (await File('$artifactsPath/sun_map_1766231524097.png').exists()) {
        _sunTexture = await _loadImage('$artifactsPath/sun_map_1766231524097.png');
      }
      if (await File('$artifactsPath/earth_map_1766231502228.png').exists()) {
        _earthTexture = await _loadImage('$artifactsPath/earth_map_1766231502228.png');
      }
      if (await File('$artifactsPath/mars_map_1766231540084.png').exists()) {
        _marsTexture = await _loadImage('$artifactsPath/mars_map_1766231540084.png');
      }
    } catch (e) {
      debugPrint('Error loading textures: $e');
    }

    if (mounted) setState(() {});
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _cameraPitch = -0.3; // Default look down
  double _cameraYaw = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Solar System (Textured)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // Sensitivity
            _cameraYaw += details.delta.dx * 0.005;
            _cameraPitch += details.delta.dy * 0.005;

            // Clamp pitch to avoid flipping
            _cameraPitch = _cameraPitch.clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
          });
        },
        child: Container(
          color: const Color(0xFF000814),
          child: Flash(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value * 2 * pi;
                return FlashNodes(
                  children: [
                    // Camera Node
                    FlashCameraWidget(
                      name: 'MainCamera',
                      position: v.Vector3(0, 500, 1200),
                      rotation: v.Vector3(_cameraPitch, -_cameraYaw, 0),
                    ),

                    // Point Light at the Sun's position
                    FlashLightWidget(
                      name: 'SunLight',
                      position: v.Vector3(0, 0, 0),
                      intensity: 2.5,
                      color: Colors.white,
                    ),

                    // Star field
                    for (int i = 0; i < 150; i++)
                      FlashBox(
                        position: v.Vector3((sin(i * 1.5) * 2000), (cos(i * 2.1) * 2000), -1500 + (i % 5) * 200),
                        width: 4,
                        height: 4,
                        color: Colors.white24,
                      ),

                    // Sun (Self-rotating)
                    FlashSphere(
                      name: 'Sun',
                      radius: 100,
                      color: Colors.orange,
                      texture: _sunTexture,
                      rotation: v.Vector3(0, t * 0.2, 0), // Axis rotation
                      child: FlashNodes(
                        children: [
                          // Earth Orbit
                          FlashNodeGroup(
                            name: 'EarthOrbit',
                            rotation: v.Vector3(0, t, 0),
                            child: FlashNodes(
                              children: [
                                FlashSphere(
                                  name: 'Earth',
                                  position: v.Vector3(400, 0, 0),
                                  radius: 40,
                                  color: Colors.blue,
                                  texture: _earthTexture,
                                  rotation: v.Vector3(0, t * 3, 0), // Axis rotation (spins faster)
                                  child: FlashNodeGroup(
                                    name: 'MoonOrbit',
                                    rotation: v.Vector3(0, t * 2, 0),
                                    child: FlashSphere(
                                      name: 'Moon',
                                      position: v.Vector3(90, 0, 0),
                                      radius: 14,
                                      color: Colors.grey[400]!,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Mars Orbit
                          FlashNodeGroup(
                            name: 'MarsOrbit',
                            rotation: v.Vector3(0, t * 0.6, 0),
                            child: FlashSphere(
                              name: 'Mars',
                              position: v.Vector3(-650, 30, 0),
                              radius: 30,
                              color: Colors.redAccent,
                              texture: _marsTexture,
                              rotation: v.Vector3(0, t * 2.5, 0), // Axis rotation
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
