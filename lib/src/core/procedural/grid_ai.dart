import 'dart:math' as math;

import '../graph/node.dart';
import '../grids/f_grid.dart';

/// Abstract base for grid-based AI agents.
///
/// Agents move on discrete tile positions, driven by the engine's frame loop
/// like any other node.
///
/// They used to be plain objects with `update(int playerX, int playerY, int
/// currentTimeMs)`, which meant the caller had to feed them a wall-clock
/// timestamp every frame — CubeRunner used `DateTime.now()`. That ignored
/// [FSceneTree.paused] and any slow-motion entirely. Cooldowns are now in
/// seconds and accumulate from the same `dt` everything else uses.
abstract class FGridAgent extends FNode {
  int x;
  int y;

  /// Seconds between moves.
  final double moveCooldown;
  double _cooldownTimer = 0;

  /// The node this agent chases, flees or reacts to. Its world position is
  /// converted to grid coordinates via [grid] when set.
  FNode? target;

  /// Grid the agent walks on. Needed to turn [target]'s world position into
  /// cell coordinates.
  FGrid? grid;

  int _targetX = 0;
  int _targetY = 0;

  FGridAgent({required this.x, required this.y, this.moveCooldown = 0.5, super.name = 'GridAgent'});

  /// Sets the cell the agent should react to, for callers without a scene
  /// graph to point [target] at.
  void setTargetCell(int cellX, int cellY) {
    _targetX = cellX;
    _targetY = cellY;
  }

  /// Whether the agent may step onto a cell. Override to respect walls; the
  /// default lets an agent walk anywhere.
  bool canEnter(int cellX, int cellY) => true;

  @override
  void process(double dt) {
    final t = target;
    final g = grid;
    if (t != null && g != null) {
      final cell = g.worldToGrid(t.worldPosition);
      _targetX = cell.x;
      _targetY = cell.y;
    }

    _cooldownTimer -= dt;
    if (_cooldownTimer > 0) return;
    _cooldownTimer += moveCooldown;
    move(_targetX, _targetY);
  }

  /// Override to implement movement logic
  void move(int playerX, int playerY);

  /// Distance to player (Manhattan)
  int distanceTo(int px, int py) => (x - px).abs() + (y - py).abs();

  /// Unique key for this agent position
  String get key => '$x,$y';

  /// Moves to a cell if [canEnter] allows it.
  void tryMoveTo(int cellX, int cellY) {
    if (!canEnter(cellX, cellY)) return;
    x = cellX;
    y = cellY;
  }
}

/// Patrol agent - follows a fixed path
class FPatrolAgent extends FGridAgent {
  final List<({int x, int y})> path;
  int _pathIndex = 0;
  bool _forward = true;

  FPatrolAgent({required super.x, required super.y, required this.path, super.moveCooldown = 0.8});

  @override
  void move(int playerX, int playerY) {
    if (path.isEmpty) return;

    final target = path[_pathIndex];
    x = target.x;
    y = target.y;

    if (_forward) {
      _pathIndex++;
      if (_pathIndex >= path.length) {
        _pathIndex = path.length - 2;
        _forward = false;
      }
    } else {
      _pathIndex--;
      if (_pathIndex < 0) {
        _pathIndex = 1;
        _forward = true;
      }
    }
  }

  /// Create a rectangular patrol path
  static FPatrolAgent rectangle(int startX, int startY, int width, int height) {
    final path = <({int x, int y})>[];
    // Top edge
    for (int i = 0; i < width; i++) {
      path.add((x: startX + i, y: startY));
    }
    // Right edge
    for (int i = 1; i < height; i++) {
      path.add((x: startX + width - 1, y: startY + i));
    }
    // Bottom edge
    for (int i = width - 2; i >= 0; i--) {
      path.add((x: startX + i, y: startY + height - 1));
    }
    // Left edge
    for (int i = height - 2; i > 0; i--) {
      path.add((x: startX, y: startY + i));
    }
    return FPatrolAgent(x: startX, y: startY, path: path);
  }
}

/// Chaser agent - follows player when within range
class FChaserAgent extends FGridAgent {
  /// Detection range (Manhattan distance)
  final int detectionRange;

  FChaserAgent({required super.x, required super.y, this.detectionRange = 5, super.moveCooldown = 0.6});

  @override
  void move(int playerX, int playerY) {
    final distance = distanceTo(playerX, playerY);
    if (distance > detectionRange) return;

    final dx = playerX - x;
    final dy = playerY - y;

    // Move towards player (prioritize larger axis)
    if (dx.abs() > dy.abs()) {
      x += dx.sign;
    } else if (dy != 0) {
      y += dy.sign;
    }
  }
}

/// Wanderer agent - moves randomly
class FWandererAgent extends FGridAgent {
  final math.Random _random;

  /// Maximum distance from spawn point
  final int wanderRadius;
  final int _spawnX;
  final int _spawnY;

  FWandererAgent({required super.x, required super.y, this.wanderRadius = 5, int? seed, super.moveCooldown = 1.0})
    : _spawnX = x,
      _spawnY = y,
      _random = math.Random(seed);

  @override
  void move(int playerX, int playerY) {
    final direction = _random.nextInt(5); // 0-3: move, 4: stay

    int newX = x;
    int newY = y;

    switch (direction) {
      case 0:
        newX++;
        break;
      case 1:
        newX--;
        break;
      case 2:
        newY++;
        break;
      case 3:
        newY--;
        break;
    }

    // Check wander radius
    if ((newX - _spawnX).abs() <= wanderRadius && (newY - _spawnY).abs() <= wanderRadius) {
      x = newX;
      y = newY;
    }
  }
}

/// Jumper agent - teleports randomly
class FJumperAgent extends FGridAgent {
  final int jumpDistance;
  final math.Random _random;

  FJumperAgent({required super.x, required super.y, this.jumpDistance = 2, int? seed, super.moveCooldown = 1.2})
    : _random = math.Random(seed);

  @override
  void move(int playerX, int playerY) {
    final direction = _random.nextInt(4);

    switch (direction) {
      case 0:
        x += jumpDistance;
        break;
      case 1:
        x -= jumpDistance;
        break;
      case 2:
        y += jumpDistance;
        break;
      case 3:
        y -= jumpDistance;
        break;
    }
  }
}

/// Fleeing agent - runs away from player
class FFleeAgent extends FGridAgent {
  final int fleeRange;

  FFleeAgent({required super.x, required super.y, this.fleeRange = 4, super.moveCooldown = 0.4});

  @override
  void move(int playerX, int playerY) {
    final distance = distanceTo(playerX, playerY);
    if (distance > fleeRange) return;

    final dx = x - playerX;
    final dy = y - playerY;

    // Move away from player
    if (dx.abs() > dy.abs()) {
      x += dx.sign;
    } else if (dy != 0) {
      y += dy.sign;
    }
  }
}
