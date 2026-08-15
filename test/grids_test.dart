import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart';

/// Pure coordinate maths — the easiest layer in the engine to test, and until
/// now the one with no tests at all.
void main() {
  group('FSquareGrid', () {
    const grid = FSquareGrid(cellWidth: 32);

    test('grid -> local -> grid round-trips', () {
      for (final cell in const [(x: 0, y: 0), (x: 3, y: 7), (x: -4, y: -2), (x: 100, y: -100)]) {
        final local = grid.getCellCenter(cell.x, cell.y);
        final back = grid.localToGrid(local.dx, local.dy);
        expect(back, cell, reason: 'cell $cell did not survive the round-trip');
      }
    });

    test('cells map onto the XZ plane with Y as height', () {
      final world = grid.cellCenterWorld(2, 5, height: 12);
      expect(world.y, 12, reason: 'the second grid axis must be Z, not Y');
      expect(world.z, isNot(0));
    });

    test('worldToGrid ignores height', () {
      final flat = grid.worldToGrid(Vector3(70, 0, 40));
      final raised = grid.worldToGrid(Vector3(70, 999, 40));
      expect(raised, flat);
    });

    test('adjacent cells are one apart', () {
      expect(grid.distance(0, 0, 1, 0), 1);
      expect(grid.distance(2, 3, 2, 3), 0);
    });
  });

  group('FIsometricGrid', () {
    const grid = FIsometricGrid(cellWidth: 64);

    test('grid -> local -> grid round-trips', () {
      for (final cell in const [(x: 0, y: 0), (x: 5, y: 2), (x: -3, y: 4), (x: 12, y: -8)]) {
        final centre = grid.getCellCenter(cell.x, cell.y);
        final back = grid.localToGrid(centre.dx, centre.dy);
        expect(back, cell, reason: 'cell $cell did not survive the round-trip');
      }
    });

    test('continuousToLocal agrees with gridToLocal on whole cells', () {
      // These two used to disagree: the old project() folded a Y-down screen
      // offset into what is otherwise a pure lattice transform.
      for (final cell in const [(x: 0, y: 0), (x: 3, y: 1), (x: -2, y: 5)]) {
        final discrete = grid.gridToLocal(cell.x, cell.y);
        final continuous = grid.continuousToLocal(cell.x.toDouble(), cell.y.toDouble());
        expect(continuous.dx, closeTo(discrete.dx, 0.001));
        expect(continuous.dy, closeTo(discrete.dy, 0.001));
      }
    });

    test('continuousToLocal interpolates between cells', () {
      final a = grid.continuousToLocal(0, 0);
      final mid = grid.continuousToLocal(0.5, 0);
      final b = grid.continuousToLocal(1, 0);
      expect(mid.dx, closeTo((a.dx + b.dx) / 2, 0.001));
      expect(mid.dy, closeTo((a.dy + b.dy) / 2, 0.001));
    });

    test('cells map onto the XZ plane with Y as height', () {
      final world = grid.cellCenterWorld(1, 1, height: 25);
      expect(world.y, 25);
    });
  });

  group('FProceduralGenerator', () {
    test('is deterministic for a given seed', () {
      final a = FProceduralGenerator(seed: 42);
      final b = FProceduralGenerator(seed: 42);
      for (int x = -5; x < 5; x++) {
        for (int y = -5; y < 5; y++) {
          expect(a.getValue(x, y), b.getValue(x, y));
        }
      }
    });

    test('different seeds diverge', () {
      final a = FProceduralGenerator(seed: 1);
      final b = FProceduralGenerator(seed: 2);
      final differs = [
        for (int x = 0; x < 20; x++)
          for (int y = 0; y < 20; y++)
            if (a.getValue(x, y) != b.getValue(x, y)) 1,
      ];
      expect(differs, isNotEmpty);
    });
  });
}
