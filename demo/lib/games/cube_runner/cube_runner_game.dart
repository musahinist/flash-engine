import 'dart:math' as math;
import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'enemy_face.dart';
import '../cube_quest/models/collectible.dart' as cq;
import '../cube_quest/ui/collectible_widget.dart';
import '../cube_quest/ui/portal_widget.dart';
import '../cube_quest/painters/enhanced_grid_painter.dart';

/// CubeRunner game logic using Flash Engine systems
class CubeRunnerGame extends ChangeNotifier {
  // Flash Engine Systems
  late final FProceduralTilemap tilemap;
  late final FScoreSystem scoreSystem;
  late final FGameTimer gameTimer;
  late final FCollectibleSystem collectibles;
  late final FPowerUpSystem powerUps;

  // Grid and Camera Systems
  static const double gridSize = 60.0;
  final FIsometricGrid isoGrid = const FIsometricGrid(cellWidth: gridSize);
  late final FGridCamera camera;

  // Grid Agents (Enemies)
  final List<FGridAgent> enemies = [];

  // Player State
  int playerX = 0;
  int playerZ = 0;
  double playerRotation = 0;

  // HUD State
  int lives = 3;
  bool isGameOver = false;

  // Animation State
  bool _isAnimating = false;
  double _animProgress = 0;
  int? _moveDirection;
  bool _isJumping = false;

  // Stored viewport for camera
  Size _viewport = const Size(800, 600);

  // CubeQuest Projection Matrix (True Isometric)
  // Rotate X: -35.264 degrees, Rotate Y: -45 degrees
  static final _isoMatrix = Matrix4.identity()
    ..rotateX(-math.atan(1.0 / math.sqrt(2.0)))
    ..rotateY(-math.pi / 4.0);

  CubeRunnerGame() {
    tilemap = FProceduralTilemap(
      seed: math.Random().nextInt(10000),
      generators: {
        'obstacle': FProceduralTilemap.obstacleGenerator(frequency: 20, clearRadius: 3),
        'diamond': FProceduralTilemap.collectibleGenerator(frequency: 40, threshold: 8),
        'star': FProceduralTilemap.rareItemGenerator(frequency: 150, threshold: 4),
        'portal': FProceduralTilemap.rareItemGenerator(frequency: 500, threshold: 2),
      },
    );
    scoreSystem = FScoreSystem();
    gameTimer = FGameTimer();
    collectibles = FCollectibleSystem();
    powerUps = FPowerUpSystem();

    // Initialize FGridCamera
    // Use high lerp speed to keep background grid and objects in sync
    camera = FGridCamera(zoom: 1.0, followMode: CameraFollowMode.smooth, lerpSpeed: 5.0);

    gameTimer.addListener(notifyListeners);
    _setupPowerUps();
    reset();
  }

  void _setupPowerUps() {
    powerUps.register(const FPowerUpDef(id: 'speed', name: 'Speed', duration: Duration(seconds: 5), value: 2.0));
    powerUps.register(const FPowerUpDef(id: 'shield', name: 'Shield', duration: Duration(seconds: 8), value: 1.0));
    powerUps.register(const FPowerUpDef(id: 'magnet', name: 'Magnet', duration: Duration(seconds: 5), value: 3.0));
  }

  void initialize(v.Vector2 viewport) {
    _viewport = Size(viewport.x, viewport.y);
    // Center camera on player initially
    // Use _isoMatrix for projection to match rendering
    final projected = _isoMatrix.transformed3(v.Vector3(playerX * gridSize, 0, playerZ * gridSize));
    camera.position = v.Vector2(projected.x, projected.y);

    gameTimer.start();
    _spawnEnemies();
    notifyListeners();
  }

  void updateViewport(Size size) {
    _viewport = size;
  }

  void _spawnEnemies() {
    enemies.clear();
    final rng = math.Random(playerX * 1000 + playerZ);

    for (int i = 0; i < 5; i++) {
      final ex = playerX + rng.nextInt(20) - 10;
      final ez = playerZ + rng.nextInt(20) - 10;

      if ((ex - playerX).abs() < 3 && (ez - playerZ).abs() < 3) continue;

      final type = rng.nextInt(3);
      switch (type) {
        case 0:
          enemies.add(FPatrolAgent.rectangle(ex, ez, 4, 4));
          break;
        case 1:
          enemies.add(FChaserAgent(x: ex, y: ez, detectionRange: 5));
          break;
        case 2:
          enemies.add(FJumperAgent(x: ex, y: ez, jumpDistance: 2, seed: rng.nextInt(10000)));
          break;
      }
    }
  }

  void triggerMove(int direction) {
    if (_isAnimating || isGameOver) return;

    int dx = 0, dz = 0;
    switch (direction) {
      case 0:
        dx = 1;
        break;
      case 1:
        dx = -1;
        break;
      case 2:
        dz = 1;
        break;
      case 3:
        dz = -1;
        break;
    }

    if (!powerUps.isActive('ghost') && tilemap.check('obstacle', playerX + dx, playerZ + dz)) {
      return;
    }

    _moveDirection = direction;
    _isJumping = false;
    _startAnimation();
  }

  void triggerJump(int direction) {
    if (_isAnimating || isGameOver) return;

    int dx = 0, dz = 0;
    switch (direction) {
      case 0:
        dx = 2;
        break;
      case 1:
        dx = -2;
        break;
      case 2:
        dz = 2;
        break;
      case 3:
        dz = -2;
        break;
    }

    if (!powerUps.isActive('ghost') && tilemap.check('obstacle', playerX + dx, playerZ + dz)) {
      return;
    }

    _moveDirection = direction;
    _isJumping = true;
    _startAnimation();
  }

  void _startAnimation() {
    _isAnimating = true;
    _animProgress = 0;
    notifyListeners();
  }

  void update(double dt) {
    if (isGameOver) return;

    gameTimer.update(Duration(milliseconds: (dt * 1000).round()));
    powerUps.update();

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    for (final enemy in enemies) {
      enemy.update(playerX, playerZ, currentTime);
    }

    if (!powerUps.isActive('shield')) {
      for (final enemy in enemies) {
        if (enemy.x == playerX && enemy.y == playerZ) {
          lives--;
          scoreSystem.breakCombo();
          if (lives <= 0) {
            isGameOver = true;
          }
          enemy.x += (enemy.x - playerX).sign * 3;
          enemy.y += (enemy.y - playerZ).sign * 3;
          break;
        }
      }
    }

    if (powerUps.isActive('magnet')) {
      final magnetRange = powerUps.getValue('magnet')?.toInt() ?? 2;
      for (int dx = -magnetRange; dx <= magnetRange; dx++) {
        for (int dz = -magnetRange; dz <= magnetRange; dz++) {
          _collectAtPosition(playerX + dx, playerZ + dz);
        }
      }
    }

    if (_isAnimating) {
      final speed = powerUps.isActive('speed') ? 2.0 : 1.0;
      _animProgress += dt * 3.0 * speed;
      if (_animProgress >= 1.0) {
        _completeMove();
      }
    }

    // Camera Update Logic
    // Target is visual position of player (Projected)
    // We calculate current visual player pos based on animation
    double pWx = playerX * gridSize;
    double pWz = playerZ * gridSize;

    // Interpolate logical pos for camera smoothness during move
    if (_isAnimating && _moveDirection != null) {
      final dist = _isJumping ? gridSize * 2 : gridSize;
      switch (_moveDirection) {
        case 0:
          pWx += dist * _animProgress;
          break;
        case 1:
          pWx -= dist * _animProgress;
          break;
        case 2:
          pWz += dist * _animProgress;
          break;
        case 3:
          pWz -= dist * _animProgress;
          break;
      }
    }

    final projected = _isoMatrix.transformed3(v.Vector3(pWx, 0, pWz));
    camera.target = v.Vector2(projected.x, projected.y);
    camera.update(dt);

    if (enemies.isNotEmpty) {
      final dist = (enemies.first.x - playerX).abs() + (enemies.first.y - playerZ).abs();
      if (dist > 25) {
        _spawnEnemies();
      }
    }

    notifyListeners();
  }

  void _completeMove() {
    final step = _isJumping ? 2 : 1;
    switch (_moveDirection) {
      case 0:
        playerX += step;
        break;
      case 1:
        playerX -= step;
        break;
      case 2:
        playerZ += step;
        break;
      case 3:
        playerZ -= step;
        break;
    }

    switch (_moveDirection) {
      case 0:
      case 1:
        playerRotation += math.pi / 2 * (_isJumping ? 2 : 1) * (_moveDirection == 0 ? 1 : -1);
        break;
      case 2:
      case 3:
        playerRotation += math.pi / 2 * (_isJumping ? 2 : 1) * (_moveDirection == 2 ? -1 : 1);
        break;
    }

    _isAnimating = false;
    _moveDirection = null;
    _animProgress = 0;

    _collectAtPosition(playerX, playerZ);

    if (tilemap.check('portal', playerX, playerZ)) {
      _teleport();
    }

    notifyListeners();
  }

  void _collectAtPosition(int x, int z) {
    if (tilemap.check('diamond', x, z) && !collectibles.isCollected('diamond', x, z)) {
      collectibles.collect('diamond', x, z);
      tilemap.collect('diamond', x, z);
      scoreSystem.add(10);
    }
    if (tilemap.check('star', x, z) && !collectibles.isCollected('star', x, z)) {
      collectibles.collect('star', x, z);
      tilemap.collect('star', x, z);
      scoreSystem.add(25);
    }
    if (tilemap.check('powerup', x, z) && !tilemap.isCollected('powerup', x, z)) {
      tilemap.collect('powerup', x, z);
      final types = ['speed', 'shield', 'magnet'];
      final rng = math.Random(x * 1000 + z);
      powerUps.activate(types[rng.nextInt(types.length)]);
    }
  }

  void _teleport() {
    final rng = math.Random(playerX * 1000 + playerZ);
    playerX += rng.nextInt(30) - 15;
    playerZ += rng.nextInt(30) - 15;

    // Reset camera to new pos instantly
    final playerIso = isoGrid.project(v.Vector3(playerX * gridSize, 0, playerZ * gridSize));
    camera.position = v.Vector2(playerIso.dx, playerIso.dy);

    _spawnEnemies();
  }

  List<Widget> buildGameObjects(double elapsed) {
    final widgets = <Widget>[];

    // CubeQuest Projection Matrix (True Isometric)
    // Rotate X: -35.264 degrees, Rotate Y: -45 degrees
    // final isoMatrix = Matrix4.identity()
    //   ..rotateX(-math.atan(1.0 / math.sqrt(2.0)))
    //   ..rotateY(-math.pi / 4.0);

    // Helper: Project 3D world pos -> True Iso 2D -> Screen 2D (via Camera)
    v.Vector3 toScreen(v.Vector3 worldPos) {
      // 1. Isometric Projection
      final projected = _isoMatrix.transformed3(worldPos);

      // 2. Camera Transform (2D)
      final screen = camera.worldToScreen(v.Vector2(projected.x, projected.y), _viewport);

      if (screen.dx.isNaN || screen.dy.isNaN) return v.Vector3.zero();
      return v.Vector3(screen.dx, screen.dy, 0);
    }

    // Add Enhanced Grid Painter (Background)
    // We access player World Position for camera offset simulation

    // Calculate interpolated position same as Player/Camera logic
    double renderX = playerX * gridSize;
    double renderZ = playerZ * gridSize;

    if (_isAnimating && _moveDirection != null) {
      final dist = _isJumping ? gridSize * 2 : gridSize;
      switch (_moveDirection) {
        case 0:
          renderX += dist * _animProgress;
          break;
        case 1:
          renderX -= dist * _animProgress;
          break;
        case 2:
          renderZ += dist * _animProgress;
          break;
        case 3:
          renderZ -= dist * _animProgress;
          break;
      }
    }

    final camX = renderX;
    final camZ = renderZ;

    // Grid Transform: Isometric Rotation + Rotate X 90 (to lie flat)
    // CubeQuest uses: Matrix4.copy(_cameraMatrix)..rotateX(math.pi / 2)
    // Here we need to align it with FGridCamera's view.
    // FGridCamera applies translation/scale.
    // But CustomPaint fills screen. We need to sync with camera.

    // For now, let's try placing it centrally with Transform.
    // Actually, FGridCamera moves everything.
    // Ideally, the grid painter should receive camera offset.
    // game.camera.position is the center.

    // In CubeQuest, Transform is applied to the whole painter canvas.
    // Here we are inside specific widget list.

    widgets.add(
      Positioned.fill(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.copy(_isoMatrix)..rotateX(math.pi / 2),
          child: CustomPaint(
            painter: EnhancedGridPainter(
              cameraX: camX.toDouble(),
              cameraZ: camZ.toDouble(),
              gridSize: gridSize,
              primaryColor: Colors.purple.shade800,
              accentColor: Colors.cyanAccent,
            ),
          ),
        ),
      ),
    );

    // Helper to add positioned cube
    void addCube({
      required v.Vector3 position,
      required double size,
      required Color color,
      Matrix4? rotation,
      Map<String, Widget>? faceChildren,
    }) {
      final safeSize = size.isNaN ? gridSize : size;
      final safePos = position; // Already checked in toScreen potentially

      widgets.add(
        Positioned(
          left: safePos.x - safeSize / 2,
          top: safePos.y - safeSize / 2,
          child: FIsometricCubeWidget(size: safeSize, color: color, rotation: rotation, faceChildren: faceChildren),
        ),
      );
    }

    // Helper to add positioned 2D widget (Centered at position)
    void addWidget({required v.Vector3 position, required Widget child, double size = gridSize}) {
      widgets.add(
        Positioned(
          left: position.x - size / 2,
          top: position.y - size / 2,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: child),
          ),
        ),
      );
    }

    // Calculate visible range (approximate logic range based on viewport)
    const range = 15;

    // --- Game Objects ---

    // Isometric Rotation not needed for FIsometricCubeWidget (handled internally)
    // But for player spinning we use rotation parameter.

    final px = playerX;
    final pz = playerZ;

    for (int dx = -range; dx <= range; dx++) {
      for (int dz = -range; dz <= range; dz++) {
        final x = px + dx;
        final z = pz + dz;

        final worldX = x * gridSize;
        final worldZ = z * gridSize;

        // Obstacles
        if (tilemap.check('obstacle', x, z)) {
          final pos = toScreen(v.Vector3(worldX, 0, worldZ));
          addCube(position: pos, size: gridSize * 0.8, color: Colors.grey.shade800);
        }

        // Collectibles (Using Cube Quest Widgets)
        if (tilemap.check('diamond', x, z) && !tilemap.isCollected('diamond', x, z)) {
          final hover = math.sin(elapsed * 4) * 5;
          final pos = toScreen(v.Vector3(worldX, 15 + hover, worldZ));
          addWidget(
            position: pos,
            child: const CollectibleWidget(type: cq.CollectibleType.diamond),
          );
        }

        if (tilemap.check('star', x, z) && !tilemap.isCollected('star', x, z)) {
          final pos = toScreen(v.Vector3(worldX, 15, worldZ));
          addWidget(
            position: pos,
            child: const CollectibleWidget(type: cq.CollectibleType.star),
          );
        }

        // Portal
        if (tilemap.check('portal', x, z)) {
          final pos = toScreen(v.Vector3(worldX, 5, worldZ));
          addWidget(
            position: pos,
            child: PortalWidget(colorIndex: 0, size: gridSize * 0.8),
          );
        }
      }
    }

    // Enemies (Using FIsometricCubeWidget + EnemyFace)
    // We calculate animation value based on elapsed time
    final animValue = (elapsed % 2.0) / 2.0;

    for (final enemy in enemies) {
      final ex = enemy.x * gridSize;
      final ez = enemy.y * gridSize;
      final pos = toScreen(v.Vector3(ex, 0, ez));

      EnemyFaceType faceType = EnemyFaceType.patrol;
      Color c = Colors.purple;
      if (enemy is FChaserAgent) {
        c = Colors.red;
        faceType = EnemyFaceType.chaser;
      }
      if (enemy is FJumperAgent) {
        c = Colors.green;
        faceType = EnemyFaceType.jumper;
      }

      addCube(
        position: pos,
        size: gridSize * 0.7,
        color: c,
        faceChildren: {'front': EnemyFace(type: faceType, size: gridSize * 0.7, animValue: animValue)},
      );
    }

    // Player
    double pWx = playerX * gridSize;
    double pWz = playerZ * gridSize;
    if (_isAnimating && _moveDirection != null) {
      final dist = _isJumping ? gridSize * 2 : gridSize;
      switch (_moveDirection) {
        case 0:
          pWx += dist * _animProgress;
          break;
        case 1:
          pWx -= dist * _animProgress;
          break;
        case 2:
          pWz += dist * _animProgress;
          break;
        case 3:
          pWz -= dist * _animProgress;
          break;
      }
    }

    double pH = 0;
    if (_isJumping && _isAnimating) {
      pH = math.sin(_animProgress * math.pi) * gridSize * 1.5;
    }

    // Project player
    final playerPos = toScreen(v.Vector3(pWx, pH, pWz));

    addCube(
      position: playerPos,
      size: gridSize * 0.85,
      color: Colors.cyan,
      rotation: Matrix4.rotationY(playerRotation),
      // Could add player face here too if desired
    );

    return widgets;
  }

  void reset() {
    playerX = 0;
    playerZ = 0;
    playerRotation = 0;
    lives = 3;
    isGameOver = false;
    _isAnimating = false;
    _animProgress = 0;
    _moveDirection = null;

    tilemap.reset();
    scoreSystem.reset();
    gameTimer.reset();
    collectibles.reset();
    powerUps.reset();
    enemies.clear();

    camera.position = v.Vector2.zero();

    notifyListeners();
  }

  @override
  void dispose() {
    scoreSystem.dispose();
    gameTimer.dispose();
    collectibles.dispose();
    powerUps.dispose();
    super.dispose();
  }
}
