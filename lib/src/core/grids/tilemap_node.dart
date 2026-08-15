import 'dart:ui';

import '../graph/node.dart';
import '../procedural/tilemap.dart';
import 'grid_node.dart';

/// How a single tile is painted.
///
/// The canvas is already in the grid's local space when this runs, so draw
/// around [centre] using the cell size the grid provides.
typedef FTilePainter = void Function(Canvas canvas, Offset centre, Size cellSize, int x, int y);

/// Draws a grid's tiles in one pass.
///
/// Deliberately a single node rather than a node per cell. [FPainter] sorts
/// `engine.renderNodes` every frame, so a node-per-cell tilemap turns an O(1)
/// draw into an O(n log n) sort — CubeRunner alone scans 31x31 = 961 cells.
///
/// Only cells inside the camera's visible rectangle are drawn, which is what
/// makes an unbounded procedural map affordable.
class FTileMapNode extends FGridNode {
  /// Scene-tree group every tilemap joins, so the engine can hand them their
  /// visible region once per frame without walking the whole tree.
  static const String group = 'flash.tilemap';

  FTileMapNode({
    required super.grid,
    required this.tilePainter,
    this.procedural,
    this.layers = const [],
    super.name = 'TileMap',
    this.paddingCells = 1,
  }) {
    addToGroup(group);
    // Tilemaps are backdrops: draw them before anything standing on them.
    sortLayer = -1;
  }

  /// Paints one tile.
  FTilePainter tilePainter;

  /// Optional infinite source of tile content.
  FProceduralTilemap? procedural;

  /// Procedural layer names to test per cell. Empty means "draw every cell".
  List<String> layers;

  /// Extra ring of cells drawn beyond the visible rectangle, so tiles do not
  /// pop in at the edges.
  int paddingCells;

  /// Bounds used when no camera has been supplied yet.
  Rect? explicitBounds;

  /// Set by the engine each frame so [draw] knows what is on screen.
  Rect? _visibleRect;

  /// Restricts drawing to [rect], in this node's local grid space.
  set visibleRect(Rect? rect) => _visibleRect = rect;

  @override
  void draw(Canvas canvas) {
    final rect = _visibleRect ?? explicitBounds;
    if (rect == null) return;

    final topLeft = grid.localToGrid(rect.left, rect.top);
    final bottomRight = grid.localToGrid(rect.right, rect.bottom);
    final cellSize = Size(grid.cellWidth, grid.cellHeight);

    for (int y = topLeft.y - paddingCells; y <= bottomRight.y + paddingCells; y++) {
      for (int x = topLeft.x - paddingCells; x <= bottomRight.x + paddingCells; x++) {
        if (!_shouldDraw(x, y)) continue;
        tilePainter(canvas, grid.getCellCenter(x, y), cellSize, x, y);
      }
    }
  }

  bool _shouldDraw(int x, int y) {
    if (layers.isEmpty) return true;
    final source = procedural;
    if (source == null) return true;
    for (final layer in layers) {
      if (source.check(layer, x, y)) return true;
    }
    return false;
  }

  @override
  Rect? get bounds => explicitBounds;
}

/// Convenience for reading a grid off a node chain.
extension FGridLookup on FNode {
  /// Nearest [FGridNode] at or above this node, if any.
  FGridNode? get enclosingGrid {
    FNode? current = this;
    while (current != null) {
      if (current is FGridNode) return current;
      current = current.parent;
    }
    return null;
  }
}
