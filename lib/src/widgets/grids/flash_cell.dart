import 'package:flutter/widgets.dart';

import '../../core/graph/node.dart';
import '../framework.dart';
import 'flash_grid_view.dart';

/// Positions its child at a grid cell.
///
/// The grid equivalent of `Positioned`: place it inside an [FGridView] and it
/// resolves `(x, y)` through that grid's coordinate system, so games stop
/// hand-rolling the same lattice arithmetic.
class FCell extends FNodeWidget {
  const FCell({
    super.key,
    required this.x,
    required this.y,
    this.height = 0,
    super.name = 'Cell',
    super.rotation,
    super.scale,
    super.child,
  });

  /// Cell column.
  final int x;

  /// Cell row.
  final int y;

  /// Height above the grid plane, in world units — a jumping piece, a stacked
  /// tile.
  final double height;

  @override
  State<FCell> createState() => _FCellState();
}

class _FCellState extends FNodeWidgetState<FCell, FNode> {
  @override
  FNode createNode() => FNode(name: widget.name ?? 'Cell');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe here, where taking a dependency is legal.
    InheritedFGrid.maybeOf(context);
    _applyCellPosition();
  }

  @override
  void applyProperties([FCell? oldWidget]) {
    super.applyProperties(oldWidget);
    _applyCellPosition();
  }

  void _applyCellPosition() {
    final gridNode = InheritedFGrid.readOf(context);
    if (gridNode == null) return;
    node.transform.position = gridNode.grid.gridToWorld(widget.x, widget.y, height: widget.height);
  }
}
