import 'dart:math' as math;

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FProceduralGenerator]: deterministic content from coordinates alone.
///
/// There is no stored world here and no random number generator carrying state.
/// Every query is a hash of (x, y, seed), so the same cell always answers the
/// same way — which is what makes an infinite map possible: you can ask about a
/// cell you have never visited, in any order, and get a consistent answer.
///
/// Move the camera and note that the terrain you leave is identical when you
/// come back. That is the property, not a coincidence.
class ProceduralDemo extends StatefulWidget {
  const ProceduralDemo({super.key});

  @override
  State<ProceduralDemo> createState() => _ProceduralDemoState();
}

class _ProceduralDemoState extends State<ProceduralDemo> {
  static const double _cellSize = 40;
  static const FSquareGrid _grid = FSquareGrid(cellWidth: _cellSize);

  int _seed = 1337;
  double _density = 0.35;
  double _safeRadius = 4;
  int _originX = 0;
  int _originY = 0;

  FProceduralGenerator get _generator => FProceduralGenerator(seed: _seed);

  @override
  Widget build(BuildContext context) {
    final generator = _generator;
    // A safe zone: a predicate that vetoes features near the origin, so a
    // player never spawns inside a wall.
    final safe = FSafeZone.circular(_safeRadius.round());
    final centre = _grid.gridToWorld(_originX, _originY);

    return DemoPage(
      title: 'Procedural',
      subtitle: 'FProceduralGenerator: a hash of position, not a stored map.',
      accent: DemoTheme.positive,
      controls: [
        DemoPanel(
          tint: DemoTheme.positive,
          children: [
            DemoSlider(
              label: 'Density',
              value: _density,
              min: 0.02,
              max: 0.8,
              fractionDigits: 2,
              tint: DemoTheme.positive,
              onChanged: (value) => setState(() => _density = value),
            ),
            DemoSlider(
              label: 'Safe radius',
              value: _safeRadius,
              min: 0,
              max: 12,
              fractionDigits: 0,
              suffix: ' cells',
              tint: DemoTheme.positive,
              onChanged: (value) => setState(() => _safeRadius = value),
            ),
          ],
        ),
        DemoButton(
          label: 'New seed',
          icon: Icons.casino_rounded,
          tint: DemoTheme.positive,
          onPressed: () => setState(() => _seed = (_seed * 1103515245 + 12345) % 2147483647),
        ),
        DemoPanel(
          title: 'Pan',
          tint: DemoTheme.positive,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DemoButton(
                  label: '',
                  icon: Icons.keyboard_arrow_left_rounded,
                  onPressed: () => setState(() => _originX -= 4),
                ),
                const SizedBox(width: 4),
                DemoButton(
                  label: '',
                  icon: Icons.keyboard_arrow_right_rounded,
                  onPressed: () => setState(() => _originX += 4),
                ),
                const SizedBox(width: 4),
                DemoButton(
                  label: 'Home',
                  onPressed: () => setState(() {
                    _originX = 0;
                    _originY = 0;
                  }),
                ),
              ],
            ),
          ],
        ),
      ],
      readouts: [
        DemoStat(label: 'Seed', value: '$_seed'),
        DemoStat(label: 'Centre cell', value: '$_originX, $_originY'),
      ],
      hint: 'Pan away and back: the same cells come back identical. No map is stored.',
      scene: FView(
        autoUpdate: false,
        child: Stack(
          children: [
            FCamera(position: v.Vector3(centre.x, 1000, centre.z), fov: 60),
            FGridView(
              grid: _grid,
              children: [
                // Terrain height as a continuous value per cell.
                FTileMap(
                  name: 'Terrain',
                  sortLayer: -3,
                  tilePainter: (canvas, cellCentre, size, x, y) {
                    final value = generator.getValue(x, y);
                    canvas.drawRect(
                      Rect.fromCenter(
                        center: cellCentre,
                        width: size.width,
                        height: size.height,
                      ),
                      Paint()
                        ..color = Color.lerp(
                          const Color(0xFF0B1220),
                          const Color(0xFF1D3B4F),
                          value,
                        )!,
                    );
                  },
                ),

                // Features as a boolean per cell, with the safe zone vetoing
                // anything too close to the origin.
                FTileMap(
                  name: 'Features',
                  sortLayer: -2,
                  tilePainter: (canvas, cellCentre, size, x, y) {
                    if (safe(x, y)) return;
                    if (!generator.hasFeature(x, y, _density, layer: 1)) return;

                    // A third layer decides which kind, from the same cell.
                    final kind = generator.getInt(x, y, 0, 3, layer: 2);
                    final paint = Paint()
                      ..color = switch (kind) {
                        0 => DemoTheme.positive,
                        1 => DemoTheme.accent,
                        _ => DemoTheme.warning,
                      };
                    final r = size.width * 0.28;
                    if (kind == 0) {
                      canvas.drawCircle(cellCentre, r, paint);
                    } else {
                      canvas.drawRect(
                        Rect.fromCenter(center: cellCentre, width: r * 2, height: r * 2),
                        paint,
                      );
                    }
                  },
                ),

                // The safe zone made visible. Rotated onto the grid plane:
                // primitives are drawn in their local XY, and grids are XZ, so
                // without this quarter turn it would be edge-on to a camera
                // looking down.
                FCircle(
                  position: v.Vector3(0, 2, 0),
                  rotation: v.Vector3(math.pi / 2, 0, 0),
                  radius: _safeRadius * _cellSize,
                  color: DemoTheme.positive.withValues(alpha: 0.08),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
