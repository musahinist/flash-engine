import 'package:vector_math/vector_math_64.dart';

import '../graph/node.dart';
import '../rendering/camera.dart';
import 'f_grid.dart';
import 'f_grid_cell.dart';

/// A node that anchors a [FGrid] in the scene.
///
/// Draws nothing itself. Its job is to be the coordinate frame children are
/// placed in: `place(node, x, y)` puts a node at a cell, and everything below
/// inherits the grid's transform. Real entities — the player, enemies, pickups
/// — stay ordinary nodes, so they keep Z-sorting, culling, physics and
/// lighting for free.
///
/// Grid maths itself stays out of the scene graph: [FGrid] and its subclasses
/// remain pure, testable value objects that this node *holds* rather than
/// inherits from.
class FGridNode extends FNode {
  FGridNode({required this.grid, super.name = 'Grid'});

  /// Coordinate system for this grid.
  FGrid grid;

  /// Optional per-cell data (walkability, weights, payloads).
  final FGridData<Object?> data = FGridData<Object?>();

  /// Places [child] at a cell, adding it if it is not already a child.
  void place(FNode child, int x, int y, {double height = 0}) {
    if (child.parent != this) addChild(child);
    child.transform.position = grid.gridToWorld(x, y, height: height);
  }

  /// The cell a world position falls in.
  ({int x, int y}) cellAt(Vector3 worldPos) => grid.worldToGrid(worldPos - worldPosition);

  /// Cells currently visible to [camera], with a one-cell margin.
  ///
  /// A tilemap can be unbounded, so a renderer needs this to know where to
  /// stop rather than walking the whole plane.
  List<({int x, int y})> visibleCells(FCameraNode camera, Vector2 viewportSize) {
    final rect = camera.getVisibleWorldRect(viewportSize);
    final origin = worldPosition;
    return grid.getVisibleCells(rect.translate(-origin.x, -origin.z));
  }
}
