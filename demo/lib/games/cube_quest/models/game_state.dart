/// Game state management for CubeQuest
library;

import 'dart:math' as math;
import 'collectible.dart';
import 'enemy.dart';

/// Complete game state
class GameState {
  // Player state
  int playerX = 0;
  int playerZ = 0;
  int lives = 3;
  int score = 0;

  // Combo system
  int comboCount = 0;
  int comboMultiplier = 1;
  DateTime? lastCollectTime;

  // Time mode
  Duration timeRemaining = const Duration(seconds: 60);
  bool isTimeMode = true;
  bool isGameOver = false;

  // Collected items tracking
  final Set<String> collectedItems = {};

  // Active power-ups
  final Map<PowerUpType, DateTime> activePowerUps = {};

  // Collected keys count
  int keysCollected = 0;

  // Portal pairs (color -> positions)
  final Map<int, List<({int x, int z})>> portals = {};

  // Shield hits remaining
  int shieldHits = 0;

  // High score
  int highScore = 0;

  GameState();

  /// Check if a specific power-up is active
  bool isPowerUpActive(PowerUpType type) {
    final expiry = activePowerUps[type];
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// Activate a power-up
  void activatePowerUp(PowerUpType type) {
    final expiry = DateTime.now().add(type.duration);
    activePowerUps[type] = expiry;

    if (type == PowerUpType.shield) {
      shieldHits = 3;
    }
  }

  /// Add score with combo multiplier
  void addScore(int points) {
    final now = DateTime.now();

    // Check combo timing (2 seconds window)
    if (lastCollectTime != null) {
      final diff = now.difference(lastCollectTime!);
      if (diff.inMilliseconds < 2000) {
        comboCount++;
        comboMultiplier = math.min(10, 1 + (comboCount ~/ 2));
      } else {
        comboCount = 0;
        comboMultiplier = 1;
      }
    }

    lastCollectTime = now;
    score += points * comboMultiplier;

    // Time mode: bonus time for score milestones
    if (isTimeMode && score > 0 && score % 500 < points * comboMultiplier) {
      timeRemaining += const Duration(seconds: 5);
    }
  }

  /// Take damage from enemy
  bool takeDamage() {
    // Check shield
    if (isPowerUpActive(PowerUpType.shield) && shieldHits > 0) {
      shieldHits--;
      if (shieldHits == 0) {
        activePowerUps.remove(PowerUpType.shield);
      }
      return false; // No damage taken
    }

    lives--;
    if (lives <= 0) {
      isGameOver = true;
      if (score > highScore) {
        highScore = score;
      }
    }
    return true;
  }

  /// Reset game state for new game
  void reset() {
    playerX = 0;
    playerZ = 0;
    lives = 3;
    score = 0;
    comboCount = 0;
    comboMultiplier = 1;
    lastCollectTime = null;
    timeRemaining = const Duration(seconds: 60);
    isGameOver = false;
    collectedItems.clear();
    activePowerUps.clear();
    keysCollected = 0;
    shieldHits = 0;
  }

  /// Update time (call every frame)
  void updateTime(Duration delta) {
    if (!isTimeMode || isGameOver) return;

    timeRemaining -= delta;
    if (timeRemaining.isNegative) {
      timeRemaining = Duration.zero;
      isGameOver = true;
      if (score > highScore) {
        highScore = score;
      }
    }
  }
}

/// World generation utilities
class WorldGenerator {
  /// Check if position has a collectible (deterministic)
  static Collectible? getCollectible(int x, int z, Set<String> collected) {
    if (x == 0 && z == 0) return null;

    final key = '$x,$z';
    if (collected.contains(key)) return null;

    // Deterministic hash
    int h = x * 374761393 ^ z * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    final value = h.abs() % 100;

    if (value < 8) {
      // 8% diamond
      return Collectible(x: x, z: z, type: CollectibleType.diamond);
    } else if (value < 10) {
      // 2% star
      return Collectible(x: x, z: z, type: CollectibleType.star);
    } else if (value < 11) {
      // 1% heart
      return Collectible(x: x, z: z, type: CollectibleType.heart);
    } else if (value < 12) {
      // 1% key
      return Collectible(x: x, z: z, type: CollectibleType.key);
    }
    return null;
  }

  /// Check if position has an obstacle (deterministic)
  static bool hasObstacle(int x, int z) {
    if (x.abs() <= 2 && z.abs() <= 2) return false; // Clear start area

    int h = x * 73856093 ^ z * 19349663;
    h = (h ^ (h >> 16)) * 0x85ebca6b;
    h = (h ^ (h >> 13)) * 0xc2b2ae35;
    h = (h ^ (h >> 16));

    return (h.abs() % 25) == 0; // 4% obstacles
  }

  /// Check if position has a power-up (deterministic)
  static PowerUp? getPowerUp(int x, int z, Set<String> collected) {
    if (x.abs() < 3 && z.abs() < 3) return null;

    final key = 'pu_$x,$z';
    if (collected.contains(key)) return null;

    int h = x * 92837111 ^ z * 18273645;
    h = (h ^ (h >> 11)) * 0x1b873593;
    final value = h.abs() % 200;

    if (value < 2) {
      return PowerUp(x: x, z: z, type: PowerUpType.speed);
    } else if (value < 3) {
      return PowerUp(x: x, z: z, type: PowerUpType.shield);
    } else if (value < 4) {
      return PowerUp(x: x, z: z, type: PowerUpType.magnet);
    } else if (value < 5) {
      return PowerUp(x: x, z: z, type: PowerUpType.ghost);
    }
    return null;
  }

  /// Check if position has a portal (deterministic)
  static ({int colorIndex, bool isEntry})? getPortal(int x, int z) {
    if (x.abs() < 5 && z.abs() < 5) return null;

    int h = x * 48271 ^ z * 16807;
    h = (h ^ (h >> 15)) * 0x94d049bb;
    final value = h.abs() % 150;

    if (value < 3) {
      // Portal exists - determine color (0-2 for 3 portal pairs)
      final colorIndex = (x.abs() + z.abs()) % 3;
      final isEntry = ((x + z) % 2) == 0;
      return (colorIndex: colorIndex, isEntry: isEntry);
    }
    return null;
  }

  /// Generate enemies around a position
  static List<Enemy> generateEnemies(int centerX, int centerZ) {
    final enemies = <Enemy>[];

    for (int dx = -8; dx <= 8; dx += 4) {
      for (int dz = -8; dz <= 8; dz += 4) {
        final x = centerX + dx;
        final z = centerZ + dz;

        if (x.abs() < 4 && z.abs() < 4) continue; // Safe zone

        int h = x * 12345 ^ z * 67890;
        h = (h ^ (h >> 13)) * 0xdeadbeef;
        final value = h.abs() % 50;

        if (value < 2) {
          enemies.add(Enemy(x: x, z: z, type: EnemyType.chaser));
        } else if (value < 3) {
          enemies.add(Enemy(x: x, z: z, type: EnemyType.jumper));
        } else if (value < 4) {
          enemies.add(
            Enemy(
              x: x,
              z: z,
              type: EnemyType.patrol,
              patrolRoute: [(x: x, z: z), (x: x + 2, z: z), (x: x + 2, z: z + 2), (x: x, z: z + 2)],
            ),
          );
        }
      }
    }

    return enemies;
  }
}
