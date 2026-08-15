import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

/// Abstract base class for all grid systems in Flash Engine.
///
/// A grid provides coordinate transformation between grid coordinates (integers)
/// and world/local coordinates (doubles). Different grid types (Square, Isometric, Hex)
/// implement their own transformation logic.
///
/// ## Which plane a grid lives on
///
/// Grids lie on the **XZ plane**, not XY: a cell maps to world `(x, 0, z)` and
/// `+Y` is height above the grid. That is what lets the grid coexist with the
/// rest of the engine, which is Y-up (see `FPhysics.standardGravity`, and the
/// Y flip baked into `FPainter`'s viewport matrix).
///
/// The 2D helpers below ([gridToLocal], [localToGrid], [getCellCenter]) work in
/// a flat lattice space where `dx` is world **X** and `dy` is world **Z**. Use
/// [gridToWorld] / [worldToGrid] / [cellCenterWorld] to cross into the scene
/// graph — they are the only place that mapping is written down, so it cannot
/// drift the way the hand-rolled copies in the games did.
abstract class FGrid {
  /// Width of each cell in world units
  final double cellWidth;

  /// Height of each cell in world units (defaults to cellWidth for square cells)
  final double cellHeight;

  const FGrid({required this.cellWidth, double? cellHeight}) : cellHeight = cellHeight ?? cellWidth;

  /// Convert grid coordinates to local (world) coordinates.
  /// Returns the top-left corner of the cell.
  Offset gridToLocal(int x, int y);

  /// Convert local (world) coordinates to grid coordinates.
  /// Returns the cell that contains the given point.
  ({int x, int y}) localToGrid(double x, double y);

  /// Get the center position of a cell in local coordinates.
  Offset getCellCenter(int x, int y) {
    final topLeft = gridToLocal(x, y);
    return Offset(topLeft.dx + cellWidth / 2, topLeft.dy + cellHeight / 2);
  }

  // --- Scene-graph bridge (XZ plane, Y-up) ---

  /// World position of a cell's top-left corner, at [height] above the grid.
  Vector3 gridToWorld(int x, int y, {double height = 0}) {
    final local = gridToLocal(x, y);
    return Vector3(local.dx, height, local.dy);
  }

  /// World position of a cell's centre, at [height] above the grid.
  Vector3 cellCenterWorld(int x, int y, {double height = 0}) {
    final centre = getCellCenter(x, y);
    return Vector3(centre.dx, height, centre.dy);
  }

  /// The cell containing [world]. The Y (height) component is ignored.
  ({int x, int y}) worldToGrid(Vector3 world) => localToGrid(world.x, world.z);

  /// Get neighboring cells for a given cell.
  /// The number and arrangement of neighbors depends on the grid type.
  List<({int x, int y})> getNeighbors(int x, int y);

  /// Calculate the distance between two cells.
  /// Uses grid-appropriate distance metric (Manhattan, Euclidean, Hex distance, etc.)
  double distance(int x1, int y1, int x2, int y2);

  /// Check if a cell is within a rectangular bounds.
  bool isInBounds(int x, int y, int minX, int minY, int maxX, int maxY) {
    return x >= minX && x <= maxX && y >= minY && y <= maxY;
  }

  /// Get all cells within a rectangular region.
  List<({int x, int y})> getCellsInRegion(int minX, int minY, int maxX, int maxY) {
    final cells = <({int x, int y})>[];
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        cells.add((x: x, y: y));
      }
    }
    return cells;
  }

  /// Get cells visible in a viewport (world coordinates)
  List<({int x, int y})> getVisibleCells(Rect viewport) {
    final topLeft = localToGrid(viewport.left, viewport.top);
    final bottomRight = localToGrid(viewport.right, viewport.bottom);

    // Add padding for partially visible cells
    return getCellsInRegion(topLeft.x - 1, topLeft.y - 1, bottomRight.x + 1, bottomRight.y + 1);
  }
}
