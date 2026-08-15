import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';

/// Covers the grid's entry into the scene graph, plus the first widget-level
/// tests in the codebase — the whole widget layer previously had none.
void main() {
  group('FGridNode', () {
    test('places children at cell positions', () {
      final gridNode = FGridNode(grid: const FSquareGrid(cellWidth: 32));
      final child = FNode(name: 'piece');

      gridNode.place(child, 2, 3);

      final expected = gridNode.grid.gridToWorld(2, 3);
      expect(child.transform.position.x, closeTo(expected.x, 0.001));
      expect(child.transform.position.z, closeTo(expected.z, 0.001));
      expect(child.parent, gridNode);
    });

    test('place() adopts a node that is not yet a child', () {
      final gridNode = FGridNode(grid: const FSquareGrid(cellWidth: 32));
      final child = FNode();
      expect(child.parent, isNull);
      gridNode.place(child, 0, 0);
      expect(child.parent, gridNode);
      // Placing again must not duplicate it.
      gridNode.place(child, 1, 1);
      expect(gridNode.children.length, 1);
    });

    test('height lifts a piece off the grid plane', () {
      final gridNode = FGridNode(grid: const FSquareGrid(cellWidth: 32));
      final child = FNode();
      gridNode.place(child, 0, 0, height: 45);
      expect(child.transform.position.y, closeTo(45, 0.001));
    });

    test('cellAt is the inverse of place', () {
      final gridNode = FGridNode(grid: const FSquareGrid(cellWidth: 32));
      final world = gridNode.grid.cellCenterWorld(4, -2);
      expect(gridNode.cellAt(world), (x: 4, y: -2));
    });
  });

  group('FTileMapNode', () {
    FTileMapNode makeTileMap({List<String> layers = const []}) {
      return FTileMapNode(
        grid: const FSquareGrid(cellWidth: 50),
        layers: layers,
        tilePainter: (canvas, centre, size, x, y) {},
      );
    }

    test('joins the tilemap group so the engine can find it', () {
      expect(makeTileMap().isInGroup(FTileMapNode.group), isTrue);
    });

    test('sorts behind other nodes by default', () {
      expect(makeTileMap().sortLayer, lessThan(FNode().sortLayer));
    });

    test('draws nothing until it is given a region', () {
      // Unbounded maps must not attempt to walk the whole plane.
      var painted = 0;
      final map = FTileMapNode(
        grid: const FSquareGrid(cellWidth: 50),
        tilePainter: (canvas, centre, size, x, y) => painted++,
      );

      final recorder = ui.PictureRecorder();
      map.draw(Canvas(recorder));
      expect(painted, 0);
    });

    test('draws only the cells inside the visible region', () {
      var painted = 0;
      final map = FTileMapNode(
        grid: const FSquareGrid(cellWidth: 50),
        tilePainter: (canvas, centre, size, x, y) => painted++,
      )..visibleRect = const Rect.fromLTRB(0, 0, 100, 100);

      final recorder = ui.PictureRecorder();
      map.draw(Canvas(recorder));

      // A 2x2 window plus one cell of padding on each side.
      expect(painted, greaterThan(0));
      expect(painted, lessThanOrEqualTo(6 * 6));
    });
  });

  group('render order', () {
    test('creationIndex is stable and increasing', () {
      // hashCode was the old tie-break, which is not stable between runs, so
      // co-planar objects could swap draw order from one launch to the next.
      final a = FNode();
      final b = FNode();
      expect(b.creationIndex, greaterThan(a.creationIndex));
    });
  });

  group('widgets', () {
    testWidgets('FGridView positions descendant cells through its grid', (tester) async {
      const grid = FSquareGrid(cellWidth: 40);
      FEngine? engine;

      await tester.pumpWidget(
        MaterialApp(
          home: FView(
            showDebugOverlay: false,
            onReady: (e) => engine = e,
            child: const FGridView(
              grid: grid,
              children: [FCell(x: 3, y: 2, name: 'target')],
            ),
          ),
        ),
      );
      await tester.pump();

      final placed = engine!.scene.findChild('target');
      expect(placed, isNotNull, reason: 'FCell did not attach to the scene');

      final expected = grid.gridToWorld(3, 2);
      expect(placed!.transform.position.x, closeTo(expected.x, 0.001));
      expect(placed.transform.position.z, closeTo(expected.z, 0.001));
    });

    testWidgets('FTileMap attaches and registers for culling', (tester) async {
      FEngine? engine;

      await tester.pumpWidget(
        MaterialApp(
          home: FView(
            showDebugOverlay: false,
            onReady: (e) => engine = e,
            child: FGridView(
              grid: const FSquareGrid(cellWidth: 40),
              children: [
                FTileMap(name: 'tiles', tilePainter: (canvas, centre, size, x, y) {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final tiles = engine!.scene.findChild('tiles');
      expect(tiles, isA<FTileMapNode>());
      expect(tiles!.isInGroup(FTileMapNode.group), isTrue);
    });
  });
}
