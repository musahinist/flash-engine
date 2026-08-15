import 'package:flutter/widgets.dart';

import '../../core/grids/f_grid.dart';
import '../../core/grids/grid_node.dart';
import '../framework.dart';

/// Makes a [FGrid] available to descendant [FCell]s.
///
/// Separate from [InheritedFNode] because a cell needs the *grid*, and walking
/// the node chain to find one on every build would be wasteful.
class InheritedFGrid extends InheritedWidget {
  const InheritedFGrid({required this.gridNode, required super.child, super.key});

  final FGridNode gridNode;

  /// Looks up the grid and subscribes to changes. Safe from `build` and
  /// `didChangeDependencies`, not from `initState`.
  static FGridNode? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InheritedFGrid>()?.gridNode;

  /// Looks up the grid *without* registering a dependency.
  ///
  /// FNodeWidgetState calls createNode()/applyProperties() from initState,
  /// where taking a dependency is an error. The subscription is established
  /// separately in didChangeDependencies.
  static FGridNode? readOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<InheritedFGrid>()?.gridNode;

  @override
  bool updateShouldNotify(InheritedFGrid oldWidget) => oldWidget.gridNode != gridNode;
}

/// Declarative grid container.
///
/// The grid system had no widget at all before this: a 2.5D engine whose main
/// promise is grids could only use them by driving the maths by hand. Children
/// are usually [FCell]s, which position themselves by grid coordinate.
///
/// ```dart
/// FGridView(
///   grid: const FIsometricGrid(cellWidth: 60),
///   children: [
///     FTileMap(tilePainter: paintTile),
///     for (final e in enemies) FCell(x: e.x, y: e.y, child: FCube(size: 40)),
///   ],
/// )
/// ```
class FGridView extends FMultiNodeWidget {
  const FGridView({super.key, required this.grid, required super.children, super.position, super.rotation, super.scale, super.name});

  final FGrid grid;

  @override
  State<FGridView> createState() => _FGridViewState();
}

class _FGridViewState extends FMultiNodeWidgetState<FGridView, FGridNode> {
  @override
  FGridNode createNode() => FGridNode(grid: widget.grid, name: widget.name ?? 'Grid');

  @override
  void applyProperties([FGridView? oldWidget]) {
    super.applyProperties(oldWidget);
    node.grid = widget.grid;
  }

  @override
  Widget build(BuildContext context) {
    return InheritedFGrid(gridNode: node, child: super.build(context));
  }
}
