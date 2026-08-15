import 'dart:math' as math;

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FGridView] and [FTileMap]: an endless grid drawn as one node.
///
/// The map is infinite and generated on demand by [FProceduralTilemap], and the
/// engine hands the tilemap node only the rectangle the camera can see. The
/// whole thing is a single entry in the render list however far you drive —
/// which is the reason it exists, rather than a node per cell.
///
/// Grids live on the XZ plane with +Y as height, so a cell's world position is
/// (x, height, z).
class TileMapDemo extends StatefulWidget {
  const TileMapDemo({super.key});

  @override
  State<TileMapDemo> createState() => _TileMapDemoState();
}

class _TileMapDemoState extends State<TileMapDemo> {
  static const double _cellSize = 64;
  static const FSquareGrid _grid = FSquareGrid(cellWidth: _cellSize);

  late FProceduralTilemap _map = _buildMap(_seed);

  int _seed = 42;
  double _zoom = 420;
  bool _showCollectibles = true;
  int _collected = 0;

  // Where the camera is looking, in cells.
  int _cellX = 0;
  int _cellY = 0;

  static FProceduralTilemap _buildMap(int seed) {
    return FProceduralTilemap(
      seed: seed,
      generators: {
        'wall': FProceduralTilemap.obstacleGenerator(frequency: 6, clearRadius: 2),
        'gem': FProceduralTilemap.collectibleGenerator(frequency: 17, threshold: 3),
      },
    );
  }

  void _pan(int dx, int dy) => setState(() {
    _cellX += dx;
    _cellY += dy;
  });

  void _collectHere() {
    // A tilemap can have cells removed from it; the generator is the default,
    // not the last word.
    if (!_map.check('gem', _cellX, _cellY)) return;
    setState(() {
      _map.collect('gem', _cellX, _cellY);
      _collected++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final centre = _grid.gridToWorld(_cellX, _cellY);
    final onGem = _map.check('gem', _cellX, _cellY);
    final onWall = _map.check('wall', _cellX, _cellY);

    return DemoPage(
      title: 'Tilemap',
      subtitle: 'FTileMap draws every visible cell in one node.',
      controls: [
        DemoPanel(
          title: 'Pan',
          children: [
            _DPad(onMove: _pan),
            const SizedBox(height: DemoTheme.gap),
            DemoSlider(
              label: 'Zoom',
              value: _zoom,
              min: 150,
              max: 1200,
              fractionDigits: 0,
              onChanged: (value) => setState(() => _zoom = value),
            ),
          ],
        ),
        DemoButton(
          label: onGem ? 'Collect this gem' : 'No gem here',
          icon: Icons.diamond_rounded,
          tint: DemoTheme.positive,
          onPressed: onGem ? _collectHere : null,
        ),
        DemoToggle(
          label: 'Gem layer',
          value: _showCollectibles,
          onChanged: (value) => setState(() => _showCollectibles = value),
        ),
        DemoButton(
          label: 'New seed',
          icon: Icons.casino_rounded,
          onPressed: () => setState(() {
            _seed = (_seed * 31 + 17) % 100000;
            _map = _buildMap(_seed);
            _collected = 0;
          }),
        ),
      ],
      readouts: [
        DemoStat(label: 'Cell', value: '$_cellX, $_cellY'),
        DemoStat(label: 'Seed', value: '$_seed'),
        DemoStat(label: 'Collected', value: '$_collected', tint: DemoTheme.positive),
        DemoStat(
          label: 'Standing on',
          value: onWall
              ? 'wall'
              : onGem
              ? 'gem'
              : 'floor',
        ),
      ],
      hint: 'The map is infinite — pan as far as you like, it stays one render node.',
      scene: FView(
        autoUpdate: false,
        child: Stack(
          children: [
            // Orthographic and pitched straight down. Parking a perspective
            // camera above the plane without rotating it points it along -Z,
            // so the grid is behind the camera and nothing is drawn.
            FCamera(
              position: v.Vector3(centre.x, 1000, centre.z),
              rotation: v.Vector3(-math.pi / 2, 0, 0),
              isOrthographic: true,
              orthographicSize: _zoom,
            ),

            FGridView(
              grid: _grid,
              children: [
                // Floor: every cell, so `layers` is left empty.
                FTileMap(
                  name: 'Floor',
                  sortLayer: -3,
                  tilePainter: (canvas, centre, size, x, y) {
                    final checker = (x + y).isEven;
                    canvas.drawRect(
                      Rect.fromCenter(
                        center: centre,
                        width: size.width - 2,
                        height: size.height - 2,
                      ),
                      Paint()
                        ..color = checker
                            ? const Color(0xFF141A2A)
                            : const Color(0xFF10141F),
                    );
                  },
                ),

                // Walls: only cells the 'wall' generator claims.
                FTileMap(
                  name: 'Walls',
                  sortLayer: -2,
                  procedural: _map,
                  layers: const ['wall'],
                  tilePainter: (canvas, centre, size, x, y) {
                    canvas.drawRRect(
                      RRect.fromRectAndRadius(
                        Rect.fromCenter(
                          center: centre,
                          width: size.width - 8,
                          height: size.height - 8,
                        ),
                        const Radius.circular(6),
                      ),
                      Paint()..color = DemoTheme.accentAlt.withValues(alpha: 0.75),
                    );
                  },
                ),

                if (_showCollectibles)
                  FTileMap(
                    name: 'Gems',
                    sortLayer: -1,
                    procedural: _map,
                    layers: const ['gem'],
                    tilePainter: (canvas, centre, size, x, y) {
                      final path = Path()
                        ..moveTo(centre.dx, centre.dy - 12)
                        ..lineTo(centre.dx + 10, centre.dy)
                        ..lineTo(centre.dx, centre.dy + 12)
                        ..lineTo(centre.dx - 10, centre.dy)
                        ..close();
                      canvas.drawPath(path, Paint()..color = DemoTheme.positive);
                    },
                  ),

                // The cursor. A plain node, positioned by the same grid maths
                // the tilemap uses.
                FBox(
                  position: _grid.gridToWorld(_cellX, _cellY, height: 4),
                  rotation: v.Vector3(math.pi / 2, 0, 0),
                  width: _cellSize,
                  height: _cellSize,
                  color: DemoTheme.accent.withValues(alpha: 0.35),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A four-way pad. Grid demos need one and it is not worth three copies.
class _DPad extends StatelessWidget {
  const _DPad({required this.onMove});

  final void Function(int dx, int dy) onMove;

  @override
  Widget build(BuildContext context) {
    Widget key(IconData icon, int dx, int dy) => Padding(
      padding: const EdgeInsets.all(2),
      child: DemoButton(label: '', icon: icon, onPressed: () => onMove(dx, dy)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        key(Icons.keyboard_arrow_up_rounded, 0, -1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key(Icons.keyboard_arrow_left_rounded, -1, 0),
            key(Icons.keyboard_arrow_down_rounded, 0, 1),
            key(Icons.keyboard_arrow_right_rounded, 1, 0),
          ],
        ),
      ],
    );
  }
}
