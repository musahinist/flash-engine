import 'package:flutter/widgets.dart';

import '../../core/grids/f_grid.dart';
import '../../core/grids/tilemap_node.dart';
import '../../core/procedural/tilemap.dart';
import '../framework.dart';
import 'flash_grid_view.dart';

/// Declarative tilemap.
///
/// Draws every visible cell of the enclosing [FGridView] in a single node, so
/// a large or infinite map costs one entry in the render list rather than one
/// per cell.
///
/// ```dart
/// FTileMap(
///   layers: const ['obstacle'],
///   procedural: myTilemap,
///   tilePainter: (canvas, centre, size, x, y) {
///     canvas.drawRect(Rect.fromCenter(center: centre, width: size.width, height: size.height), paint);
///   },
/// )
/// ```
class FTileMap extends FNodeWidget {
  const FTileMap({
    super.key,
    required this.tilePainter,
    this.grid,
    this.procedural,
    this.layers = const [],
    this.sortLayer = -1,
    this.paddingCells = 1,
    super.name = 'TileMap',
  });

  /// Paints one tile, in the grid's local space.
  final FTilePainter tilePainter;

  /// Grid to use. Defaults to the enclosing [FGridView]'s grid.
  final FGrid? grid;

  /// Infinite content source, if the map is generated rather than authored.
  final FProceduralTilemap? procedural;

  /// Procedural layers to test per cell. Empty draws every cell.
  final List<String> layers;

  /// Draw order. Negative by default so tiles sit behind everything standing
  /// on them.
  final int sortLayer;

  /// Extra ring of cells drawn beyond the visible rectangle.
  final int paddingCells;

  @override
  State<FTileMap> createState() => _FTileMapState();
}

class _FTileMapState extends FNodeWidgetState<FTileMap, FTileMapNode> {
  @override
  FTileMapNode createNode() {
    final grid = widget.grid ?? InheritedFGrid.readOf(context)?.grid;
    assert(
      grid != null,
      'FTileMap needs a grid: pass one directly or place it inside an FGridView.',
    );
    return FTileMapNode(
      grid: grid!,
      tilePainter: widget.tilePainter,
      procedural: widget.procedural,
      layers: widget.layers,
      paddingCells: widget.paddingCells,
      name: widget.name ?? 'TileMap',
    );
  }

  @override
  void applyProperties([FTileMap? oldWidget]) {
    super.applyProperties(oldWidget);
    node.tilePainter = widget.tilePainter;
    node.procedural = widget.procedural;
    node.layers = widget.layers;
    node.paddingCells = widget.paddingCells;
    node.sortLayer = widget.sortLayer;
    final grid = widget.grid ?? InheritedFGrid.readOf(context)?.grid;
    if (grid != null) node.grid = grid;
  }
}
