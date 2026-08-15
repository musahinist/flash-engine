import 'dart:ui';
import 'f_grid.dart';

/// Orientation of the isometric grid.
enum IsometricOrientation {
  /// Diamond shape with point at top (most common)
  diamond,

  /// Staggered rows (Zelda-style top-down)
  staggered,
}

/// An isometric grid for 2.5D games.
///
/// Isometric grids create a pseudo-3D effect by rotating and skewing
/// a square grid. Used in games like:
/// - Diablo, Path of Exile
/// - SimCity, Cities: Skylines
/// - Age of Empires, StarCraft
/// - Cube Roller (our game!)
class FIsometricGrid extends FGrid {
  /// The tile height ratio (typically 0.5 for true isometric)
  final double heightRatio;

  /// Grid orientation
  final IsometricOrientation orientation;

  const FIsometricGrid({
    required super.cellWidth,
    this.heightRatio = 0.5,
    this.orientation = IsometricOrientation.diamond,
  }) : super(cellHeight: null);

  /// Effective tile height based on ratio
  double get tileHeight => cellWidth * heightRatio;

  @override
  Offset gridToLocal(int x, int y) {
    switch (orientation) {
      case IsometricOrientation.diamond:
        // Diamond isometric: rotate 45 degrees
        final isoX = (x - y) * (cellWidth / 2);
        final isoY = (x + y) * (tileHeight / 2);
        return Offset(isoX, isoY);

      case IsometricOrientation.staggered:
        // Staggered rows: offset every other row
        final offsetX = (y % 2 == 0) ? 0.0 : cellWidth / 2;
        return Offset(x * cellWidth + offsetX, y * tileHeight);
    }
  }

  @override
  ({int x, int y}) localToGrid(double localX, double localY) {
    switch (orientation) {
      case IsometricOrientation.diamond:
        // Inverse of diamond transformation
        final halfWidth = cellWidth / 2;
        final halfHeight = tileHeight / 2;

        final gridX = ((localX / halfWidth) + (localY / halfHeight)) / 2;
        final gridY = ((localY / halfHeight) - (localX / halfWidth)) / 2;

        return (x: gridX.floor(), y: gridY.floor());

      case IsometricOrientation.staggered:
        final roughY = (localY / tileHeight).floor();
        final offsetX = (roughY % 2 == 0) ? 0.0 : cellWidth / 2;
        final roughX = ((localX - offsetX) / cellWidth).floor();

        return (x: roughX, y: roughY);
    }
  }

  @override
  Offset getCellCenter(int x, int y) {
    final topLeft = gridToLocal(x, y);
    switch (orientation) {
      case IsometricOrientation.diamond:
        // Diamond center is at the visual center of the diamond
        return Offset(topLeft.dx, topLeft.dy + tileHeight / 2);
      case IsometricOrientation.staggered:
        return Offset(topLeft.dx + cellWidth / 2, topLeft.dy + tileHeight / 2);
    }
  }

  @override
  List<({int x, int y})> getNeighbors(int x, int y) {
    // Isometric grids typically have 4 neighbors (diamond directions)
    return [
      (x: x + 1, y: y), // East
      (x: x - 1, y: y), // West
      (x: x, y: y + 1), // South
      (x: x, y: y - 1), // North
    ];
  }

  @override
  double distance(int x1, int y1, int x2, int y2) {
    // Manhattan distance on isometric grid
    return ((x2 - x1).abs() + (y2 - y1).abs()).toDouble();
  }

  /// Get the screen bounds of a cell (for rendering/hit testing).
  List<Offset> getCellPolygon(int x, int y) {
    final center = getCellCenter(x, y);
    final halfW = cellWidth / 2;
    final halfH = tileHeight / 2;

    switch (orientation) {
      case IsometricOrientation.diamond:
        return [
          Offset(center.dx, center.dy - halfH), // Top
          Offset(center.dx + halfW, center.dy), // Right
          Offset(center.dx, center.dy + halfH), // Bottom
          Offset(center.dx - halfW, center.dy), // Left
        ];
      case IsometricOrientation.staggered:
        final topLeft = gridToLocal(x, y);
        return [
          topLeft,
          Offset(topLeft.dx + cellWidth, topLeft.dy),
          Offset(topLeft.dx + cellWidth, topLeft.dy + tileHeight),
          Offset(topLeft.dx, topLeft.dy + tileHeight),
        ];
    }
  }

  /// Check if a point is inside a cell (for precise hit testing).
  bool isPointInCell(double localX, double localY, int cellX, int cellY) {
    final polygon = getCellPolygon(cellX, cellY);
    return _pointInPolygon(Offset(localX, localY), polygon);
  }

  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy) &&
          point.dx <
              (polygon[j].dx - polygon[i].dx) * (point.dy - polygon[i].dy) / (polygon[j].dy - polygon[i].dy) +
                  polygon[i].dx) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Lattice position for *fractional* cell coordinates.
  ///
  /// [gridToLocal] only accepts whole cells; this is the continuous version,
  /// used for smooth movement between cells. Both return the same flat lattice
  /// space, where `dx` is world X and `dy` is world Z.
  ///
  /// This replaces the old `project(Vector3)`, which folded a screen-space
  /// assumption (`dy - worldPos.y`, i.e. Y-down) into what is otherwise a
  /// pure lattice transform, and disagreed with [gridToLocal] as a result.
  /// Turning world space into screen space is the camera's job.
  Offset continuousToLocal(double x, double y) {
    switch (orientation) {
      case IsometricOrientation.diamond:
        // x, y are continuous grid coordinates
        final isoX = (x - y) * (cellWidth / 2);
        final isoY = (x + y) * (tileHeight / 2);
        return Offset(isoX, isoY);

      case IsometricOrientation.staggered:
        // continuous staggered is complex, approximated
        return Offset(x * cellWidth, y * tileHeight);
    }
  }
}
