/// Procedural content generation using hash functions.
///
/// Provides deterministic, reproducible random content based on coordinates.
/// Perfect for infinite worlds where content must be consistent across sessions.
class FProceduralGenerator {
  /// Seed for the generator
  final int seed;

  const FProceduralGenerator({this.seed = 0});

  /// Generate a deterministic hash for given coordinates.
  ///
  /// Uses a MurmurHash3-style mixing function for good distribution.
  int hash2D(int x, int y) {
    int h = x * 374761393 + seed;
    h = (h ^ y * 668265263);
    h = (h ^ (h >> 13)) * 1274126177;
    h = (h ^ (h >> 16));
    return h.abs();
  }

  /// Generate a hash for 3D coordinates.
  int hash3D(int x, int y, int z) {
    int h = x * 73856093 + seed;
    h = h ^ (y * 19349663);
    h = h ^ (z * 83492791);
    h = (h ^ (h >> 13)) * 0x85ebca6b;
    h = (h ^ (h >> 16));
    return h.abs();
  }

  /// Check if a cell has a feature with given probability.
  ///
  /// [x], [y] - Grid coordinates
  /// [probability] - Chance of feature (0.0 to 1.0)
  /// [layer] - Optional layer to separate different feature types
  bool hasFeature(int x, int y, double probability, {int layer = 0}) {
    final h = hash2D(x + layer * 10000, y);
    final threshold = (probability * 1000000).toInt();
    return (h % 1000000) < threshold;
  }

  /// Get a random value between 0.0 and 1.0 for given coordinates.
  double getValue(int x, int y, {int layer = 0}) {
    final h = hash2D(x + layer * 10000, y);
    return (h % 1000000) / 1000000.0;
  }

  /// Get a random integer in range [min, max] for given coordinates.
  int getInt(int x, int y, int min, int max, {int layer = 0}) {
    final h = hash2D(x + layer * 10000, y);
    return min + (h % (max - min + 1));
  }

  /// Create a feature generator for a specific feature type.
  ///
  /// Example:
  /// ```dart
  /// final diamonds = generator.featureGenerator(probability: 0.1, layer: 1);
  /// final obstacles = generator.featureGenerator(probability: 0.05, layer: 2);
  ///
  /// if (diamonds(x, y)) { ... }
  /// if (obstacles(x, y)) { ... }
  /// ```
  bool Function(int x, int y) featureGenerator({
    required double probability,
    int layer = 0,
    bool Function(int x, int y)? exclude,
  }) {
    return (int x, int y) {
      if (exclude != null && exclude(x, y)) return false;
      return hasFeature(x, y, probability, layer: layer);
    };
  }
}

/// Helper for creating safe zones (areas without certain features).
class FSafeZone {
  /// Rectangular safe zone centered at origin.
  static bool Function(int, int) rectangular(int halfWidth, int halfHeight) {
    return (int x, int y) => x.abs() <= halfWidth && y.abs() <= halfHeight;
  }

  /// Circular safe zone centered at origin.
  static bool Function(int, int) circular(int radius) {
    return (int x, int y) => x * x + y * y <= radius * radius;
  }

  /// Custom safe zone around specific cells.
  static bool Function(int, int) around(Set<String> cells) {
    return (int x, int y) => cells.contains('$x,$y');
  }
}
