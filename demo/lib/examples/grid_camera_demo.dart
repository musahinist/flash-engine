import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// Demo showcasing the new Grid and Camera systems.
class GridCameraDemo extends StatefulWidget {
  const GridCameraDemo({super.key});

  @override
  State<GridCameraDemo> createState() => _GridCameraDemoState();
}

class _GridCameraDemoState extends State<GridCameraDemo> with SingleTickerProviderStateMixin {
  // Grid selection
  int _gridType = 0; // 0: Square, 1: Isometric

  // Camera: an orthographic FCameraNode looking down at the XZ plane. There
  // is no separate 2D grid camera any more.
  late FCameraNode _camera;

  // Player position (grid coordinates)
  int _playerX = 0;
  int _playerY = 0;

  // Animation
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _camera = FCameraNode.topDown(orthographicSize: 300)
      ..followMode = CameraFollowMode.smooth
      ..followSmoothing = 0.12;

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))..addListener(_update);

    _controller.repeat();
  }

  void _update() {
    // Follow normally reads a target node; this demo has no scene graph, so it
    // drives the camera position directly through the same smoothing rule.
    final grid = _getGrid();
    final playerWorld = grid.cellCenterWorld(_playerX, _playerY);
    const dt = 0.016;
    final t = 1 - math.exp(-dt / _camera.followSmoothing);
    final pos = _camera.transform.position;
    pos.x += (playerWorld.x - pos.x) * t;
    pos.z += (playerWorld.z - pos.z) * t;
    _camera.transform.syncExternalMutations();
    _camera.process(dt);
    setState(() {});
  }

  /// Screen pixel -> point on the grid plane (Y = 0).
  ///
  /// Replaces FGridCamera.screenToWorld: inverts the camera's own screen
  /// matrix rather than maintaining a second, parallel transform.
  Offset _screenToGridPlane(Offset screen, Size viewport) {
    final size = v.Vector2(viewport.width, viewport.height);
    final inverse = Matrix4.copy(_camera.getScreenMatrix(size))..invert();
    final near = inverse.perspectiveTransform(v.Vector3(screen.dx, screen.dy, 0));
    final far = inverse.perspectiveTransform(v.Vector3(screen.dx, screen.dy, 1));

    // Intersect the ray with the Y = 0 plane the grid lies on.
    final dy = far.y - near.y;
    final t = dy.abs() < 1e-9 ? 0.0 : -near.y / dy;
    final hit = near + (far - near) * t;
    return Offset(hit.x, hit.z);
  }

  FGrid _getGrid() {
    switch (_gridType) {
      case 0:
        return const FSquareGrid(cellWidth: 64.0);
      case 1:
        return const FIsometricGrid(cellWidth: 64.0);
      default:
        return const FSquareGrid(cellWidth: 64.0);
    }
  }

  void _movePlayer(int dx, int dy) {
    setState(() {
      _playerX += dx;
      _playerY += dy;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Grid & Camera',
      subtitle: 'FSquareGrid and FIsometricGrid, and what the camera does with them.',
      controls: [
        DemoPanel(
          title: 'Grid',
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DemoButton(
                  label: 'Square',
                  selected: _gridType == 0,
                  onPressed: () => setState(() => _gridType = 0),
                ),
                const SizedBox(width: 6),
                DemoButton(
                  label: 'Isometric',
                  selected: _gridType == 1,
                  onPressed: () => setState(() => _gridType = 1),
                ),
              ],
            ),
          ],
        ),
        DemoPanel(
          title: _gridType == 0 ? 'Move' : 'Move (screen directions)',
          children: [_gridType == 0 ? _buildSquareControls() : _buildIsometricControls()],
        ),
        DemoButton(
          label: 'Shake the camera',
          icon: Icons.vibration_rounded,
          tint: DemoTheme.warning,
          onPressed: () => _camera.shake(magnitude: 15, duration: 0.3),
        ),
      ],
      readouts: [DemoStat(label: 'Cell', value: '$_playerX, $_playerY')],
      hint: 'On the isometric grid the arrows are screen directions, not axes.',
      scene: ColoredBox(
        color: DemoTheme.background,
        child: LayoutBuilder(
              builder: (context, constraints) {
                final viewport = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onTapUp: (details) {
                    // Convert tap to grid coordinates
                    final worldPos = _screenToGridPlane(details.localPosition, viewport);
                    final grid = _getGrid();
                    final gridCoord = grid.localToGrid(worldPos.dx, worldPos.dy);

                    setState(() {
                      _playerX = gridCoord.x;
                      _playerY = gridCoord.y;
                    });
                  },
                  child: CustomPaint(
                    size: viewport,
                    painter: _GridPainter(grid: _getGrid(), camera: _camera, playerX: _playerX, playerY: _playerY),
                  ),
                );
          },
        ),
      ),
    );
  }

  /// Standard D-pad for square grid
  Widget _buildSquareControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white),
              onPressed: () => _movePlayer(0, -1),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => _movePlayer(-1, 0),
            ),
            const SizedBox(width: 48),
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () => _movePlayer(1, 0),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_downward, color: Colors.white),
              onPressed: () => _movePlayer(0, 1),
            ),
          ],
        ),
      ],
    );
  }

  /// Diamond D-pad for isometric grid (visual directions match screen)
  Widget _buildIsometricControls() {
    return Column(
      children: [
        // Up-Left and Up-Right (visual top)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.north_west, color: Colors.white),
              onPressed: () => _movePlayer(-1, 0), // Visual NW = grid -X
              tooltip: 'NW (-X)',
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.north_east, color: Colors.white),
              onPressed: () => _movePlayer(0, -1), // Visual NE = grid -Y
              tooltip: 'NE (-Y)',
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Down-Left and Down-Right (visual bottom)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.south_west, color: Colors.white),
              onPressed: () => _movePlayer(0, 1), // Visual SW = grid +Y
              tooltip: 'SW (+Y)',
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.south_east, color: Colors.white),
              onPressed: () => _movePlayer(1, 0), // Visual SE = grid +X
              tooltip: 'SE (+X)',
            ),
          ],
        ),
      ],
    );
  }

}

class _GridPainter extends CustomPainter {
  final FGrid grid;
  final FCameraNode camera;
  final int playerX;
  final int playerY;

  _GridPainter({required this.grid, required this.camera, required this.playerX, required this.playerY});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final playerPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    final originPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    // Get visible cells
    final viewport = v.Vector2(size.width, size.height);
    final visibleRect = camera.getVisibleWorldRect(viewport);

    /// Grid lattice point -> screen pixel. The grid's `dy` is world Z.
    Offset toScreen(Offset lattice) {
      final p = camera.worldToScreen(v.Vector3(lattice.dx, 0, lattice.dy), viewport);
      return Offset(p.x, p.y);
    }

    final topLeft = grid.localToGrid(visibleRect.left, visibleRect.top);
    final bottomRight = grid.localToGrid(visibleRect.right, visibleRect.bottom);

    // Draw grid cells
    for (int y = topLeft.y - 2; y <= bottomRight.y + 2; y++) {
      for (int x = topLeft.x - 2; x <= bottomRight.x + 2; x++) {
        final worldPos = grid.getCellCenter(x, y);
        final screenPos = toScreen(worldPos);

        // Draw cell
        if (grid is FIsometricGrid) {
          final isoGrid = grid as FIsometricGrid;
          final polygon = isoGrid.getCellPolygon(x, y);
          final path = Path();

          final first = toScreen(polygon[0]);
          path.moveTo(first.dx, first.dy);

          for (int i = 1; i < polygon.length; i++) {
            final p = toScreen(polygon[i]);
            path.lineTo(p.dx, p.dy);
          }
          path.close();
          canvas.drawPath(path, gridPaint);
        } else {
          // Square grid
          final cellSize = grid.cellWidth * (size.height / 2) / camera.orthographicSize;
          canvas.drawRect(Rect.fromCenter(center: screenPos, width: cellSize, height: cellSize), gridPaint);
        }

        // Highlight origin
        if (x == 0 && y == 0) {
          canvas.drawCircle(screenPos, 8, originPaint);
        }
      }
    }

    // Draw player
    final playerWorld = grid.getCellCenter(playerX, playerY);
    final playerScreen = toScreen(playerWorld);
    canvas.drawCircle(playerScreen, 20, playerPaint);

    // Draw coordinates text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Player: ($playerX, $playerY)',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 10));
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => true;
}
