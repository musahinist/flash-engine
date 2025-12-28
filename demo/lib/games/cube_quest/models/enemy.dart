/// Enemy types and behavior for CubeQuest
library;

import 'dart:math' as math;

/// Types of enemy cubes
enum EnemyType {
  /// Follows a fixed patrol route
  patrol,

  /// Chases player within 3 tiles
  chaser,

  /// Randomly jumps around
  jumper,
}

/// An enemy cube on the grid
class Enemy {
  int x;
  int z;
  final EnemyType type;

  /// Patrol route points (for patrol type)
  final List<({int x, int z})> patrolRoute;
  int _patrolIndex = 0;
  bool _patrolForward = true;

  /// Last update time for movement throttling
  int _lastMoveTime = 0;

  Enemy({required this.x, required this.z, required this.type, this.patrolRoute = const []});

  String get key => '$x,$z';

  /// Update enemy position based on type and player position
  void update(int playerX, int playerZ, int currentTime) {
    // Throttle movement (move every 800ms)
    if (currentTime - _lastMoveTime < 800) return;
    _lastMoveTime = currentTime;

    switch (type) {
      case EnemyType.patrol:
        _updatePatrol();
        break;
      case EnemyType.chaser:
        _updateChaser(playerX, playerZ);
        break;
      case EnemyType.jumper:
        _updateJumper();
        break;
    }
  }

  void _updatePatrol() {
    if (patrolRoute.isEmpty) return;

    final target = patrolRoute[_patrolIndex];
    x = target.x;
    z = target.z;

    if (_patrolForward) {
      _patrolIndex++;
      if (_patrolIndex >= patrolRoute.length) {
        _patrolIndex = patrolRoute.length - 2;
        _patrolForward = false;
      }
    } else {
      _patrolIndex--;
      if (_patrolIndex < 0) {
        _patrolIndex = 1;
        _patrolForward = true;
      }
    }
  }

  void _updateChaser(int playerX, int playerZ) {
    final dx = playerX - x;
    final dz = playerZ - z;
    final distance = math.sqrt(dx * dx + dz * dz);

    // Only chase if within 4 tiles
    if (distance > 4) return;

    // Move towards player
    if (dx.abs() > dz.abs()) {
      x += dx.sign;
    } else if (dz != 0) {
      z += dz.sign;
    }
  }

  void _updateJumper() {
    final random = math.Random();
    final direction = random.nextInt(4);
    switch (direction) {
      case 0:
        x += 2;
        break;
      case 1:
        x -= 2;
        break;
      case 2:
        z += 2;
        break;
      case 3:
        z -= 2;
        break;
    }
  }
}
