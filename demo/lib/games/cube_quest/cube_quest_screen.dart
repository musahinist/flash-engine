import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'models/face_def.dart';
import 'models/collectible.dart';
import 'models/enemy.dart';
import 'models/game_state.dart';
import 'painters/enhanced_grid_painter.dart';
import 'ui/collectible_widget.dart';
import 'ui/enemy_widget.dart';
import 'ui/power_up_widget.dart';
import 'ui/portal_widget.dart';
import 'ui/cube_face.dart';
import 'ui/hud_overlay.dart';

class CubeQuestScreen extends StatefulWidget {
  const CubeQuestScreen({super.key});

  @override
  State<CubeQuestScreen> createState() => _CubeQuestScreenState();
}

class _CubeQuestScreenState extends State<CubeQuestScreen> with TickerProviderStateMixin {
  static const double cubeSize = 60.0;
  static const double halfCubeSize = cubeSize / 2.0;

  // Game State
  final GameState _gameState = GameState();
  List<Enemy> _enemies = [];

  // Camera State
  double _cameraX = 0.0;
  double _cameraZ = 0.0;

  // Momentum State
  int _queuedSteps = 0;
  int? _lastDirection;

  // Gesture Tracking
  Offset? _dragStart;

  // Animation handling
  late AnimationController _controller;
  late final Ticker _ticker;
  Timer? _gameTimer;

  // Matrices & Caching
  late final Matrix4 _cameraMatrix;
  late final List<FaceDef> _baseFaces;
  final Vector3 _lightVector = Vector3(0.5, -1.0, -0.5).normalized();

  // Current 3D Rotation
  Matrix4 _currentRotation = Matrix4.identity();

  // Animation state
  int? _rollingDirection;
  bool _isJumping = false;

  // Time tracking
  DateTime _lastFrameTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _submitMove();
      }
    });

    // Continuous ticker for camera follow and game updates
    _ticker = createTicker((_) {
      final now = DateTime.now();
      final delta = now.difference(_lastFrameTime);
      _lastFrameTime = now;

      // Update game time
      if (!_gameState.isGameOver) {
        _gameState.updateTime(delta);

        // Update enemies
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        for (final enemy in _enemies) {
          enemy.update(_gameState.playerX, _gameState.playerZ, currentTime);
        }

        // Check enemy collision
        _checkEnemyCollision();

        // Magnet effect
        if (_gameState.isPowerUpActive(PowerUpType.magnet)) {
          _applyMagnetEffect();
        }
      }

      // Camera follow
      final targetX = _gameState.playerX * cubeSize;
      final targetZ = _gameState.playerZ * cubeSize;
      final dx = targetX - _cameraX;
      final dz = targetZ - _cameraZ;

      if (dx.abs() > 0.01 || dz.abs() > 0.01 || _gameState.isGameOver) {
        setState(() {
          _cameraX += dx * 0.08;
          _cameraZ += dz * 0.08;
        });
      }
    })..start();

    // Generate initial enemies
    _enemies = WorldGenerator.generateEnemies(0, 0);

    // Cache the standard isometric camera matrix
    _cameraMatrix = Matrix4.identity()
      ..rotateX(-math.atan(1.0 / math.sqrt(2.0)))
      ..rotateY(-math.pi / 4.0);

    // Baseline face definitions
    _baseFaces = [
      FaceDef('front', Vector3(0, 0, -1), Matrix4.identity()..translateByVector3(Vector3(0, 0, -halfCubeSize))),
      FaceDef(
        'back',
        Vector3(0, 0, 1),
        Matrix4.identity()
          ..translateByVector3(Vector3(0, 0, halfCubeSize))
          ..rotateY(math.pi),
      ),
      FaceDef(
        'right',
        Vector3(1, 0, 0),
        Matrix4.identity()
          ..translateByVector3(Vector3(halfCubeSize, 0, 0))
          ..rotateY(math.pi / 2),
      ),
      FaceDef(
        'left',
        Vector3(-1, 0, 0),
        Matrix4.identity()
          ..translateByVector3(Vector3(-halfCubeSize, 0, 0))
          ..rotateY(-math.pi / 2),
      ),
      FaceDef(
        'top',
        Vector3(0, -1, 0),
        Matrix4.identity()
          ..translateByVector3(Vector3(0, -halfCubeSize, 0))
          ..rotateX(math.pi / 2),
      ),
      FaceDef(
        'bottom',
        Vector3(0, 1, 0),
        Matrix4.identity()
          ..translateByVector3(Vector3(0, halfCubeSize, 0))
          ..rotateX(-math.pi / 2),
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _ticker.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _checkEnemyCollision() {
    if (_gameState.isGameOver) return;

    // Ghost power-up allows passing through enemies
    if (_gameState.isPowerUpActive(PowerUpType.ghost)) return;

    for (final enemy in _enemies) {
      if (enemy.x == _gameState.playerX && enemy.z == _gameState.playerZ) {
        _gameState.takeDamage();
        // Push enemy away
        enemy.x += (enemy.x - _gameState.playerX).sign * 2;
        enemy.z += (enemy.z - _gameState.playerZ).sign * 2;
        break;
      }
    }
  }

  void _applyMagnetEffect() {
    // Automatically collect nearby items
    final px = _gameState.playerX;
    final pz = _gameState.playerZ;

    for (int dx = -2; dx <= 2; dx++) {
      for (int dz = -2; dz <= 2; dz++) {
        final x = px + dx;
        final z = pz + dz;
        final collectible = WorldGenerator.getCollectible(x, z, _gameState.collectedItems);
        if (collectible != null) {
          _collectItem(collectible);
        }
      }
    }
  }

  void _collectItem(Collectible collectible) {
    if (_gameState.collectedItems.contains(collectible.key)) return;

    _gameState.collectedItems.add(collectible.key);

    switch (collectible.type) {
      case CollectibleType.diamond:
      case CollectibleType.star:
        _gameState.addScore(collectible.type.points);
        break;
      case CollectibleType.heart:
        _gameState.lives++;
        break;
      case CollectibleType.key:
        _gameState.keysCollected++;
        break;
    }
  }

  void _collectPowerUp(PowerUp powerUp) {
    if (_gameState.collectedItems.contains('pu_${powerUp.key}')) return;

    _gameState.collectedItems.add('pu_${powerUp.key}');
    _gameState.activatePowerUp(powerUp.type);
  }

  void _checkPortalTeleport() {
    final portal = WorldGenerator.getPortal(_gameState.playerX, _gameState.playerZ);
    if (portal == null) return;

    // Find matching portal
    // Simple teleport: move to a random position with same color index
    final random = math.Random(_gameState.playerX * 1000 + _gameState.playerZ);
    final teleportX = _gameState.playerX + random.nextInt(20) - 10 + (portal.isEntry ? 15 : -15);
    final teleportZ = _gameState.playerZ + random.nextInt(20) - 10 + (portal.isEntry ? 15 : -15);

    _gameState.playerX = teleportX;
    _gameState.playerZ = teleportZ;

    // Regenerate enemies around new position
    _enemies = WorldGenerator.generateEnemies(teleportX, teleportZ);
  }

  void _submitMove() {
    if (_rollingDirection == null) return;

    setState(() {
      final step = _isJumping ? 2 : 1;
      final speedMultiplier = _gameState.isPowerUpActive(PowerUpType.speed) ? 2 : 1;

      switch (_rollingDirection) {
        case 0:
          _gameState.playerX += step * speedMultiplier;
          break;
        case 1:
          _gameState.playerX -= step * speedMultiplier;
          break;
        case 2:
          _gameState.playerZ += step * speedMultiplier;
          break;
        case 3:
          _gameState.playerZ -= step * speedMultiplier;
          break;
      }

      double angle = 0.0;
      Vector3 axis = Vector3(1.0, 0.0, 0.0);

      switch (_rollingDirection) {
        case 0:
          angle = math.pi / 2;
          axis = Vector3(0, 0, 1);
          break;
        case 1:
          angle = -math.pi / 2;
          axis = Vector3(0, 0, 1);
          break;
        case 2:
          angle = -math.pi / 2;
          axis = Vector3(1, 0, 0);
          break;
        case 3:
          angle = math.pi / 2;
          axis = Vector3(1, 0, 0);
          break;
      }

      _currentRotation = (Matrix4.identity()..rotate(axis, angle * (_isJumping ? 2.0 : 1.0))) * _currentRotation;
      _rollingDirection = null;
      _isJumping = false;
      _controller.reset();

      // Check collectibles
      final collectible = WorldGenerator.getCollectible(
        _gameState.playerX,
        _gameState.playerZ,
        _gameState.collectedItems,
      );
      if (collectible != null) {
        _collectItem(collectible);
      }

      // Check power-ups
      final powerUp = WorldGenerator.getPowerUp(_gameState.playerX, _gameState.playerZ, _gameState.collectedItems);
      if (powerUp != null) {
        _collectPowerUp(powerUp);
      }

      // Check portal
      _checkPortalTeleport();

      // Regenerate enemies if moved far
      if ((_gameState.playerX - _enemies.first.x).abs() > 15 || (_gameState.playerZ - _enemies.first.z).abs() > 15) {
        _enemies = WorldGenerator.generateEnemies(_gameState.playerX, _gameState.playerZ);
      }

      // Chain momentum
      if (_queuedSteps > 0 && _lastDirection != null) {
        _queuedSteps--;
        _triggerRoll(_lastDirection!, durationMs: 180);
      }
    });
  }

  void _triggerJump(int direction) {
    if (_controller.isAnimating || _gameState.isGameOver) return;

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

    // Ghost can pass through obstacles
    if (!_gameState.isPowerUpActive(PowerUpType.ghost)) {
      if (WorldGenerator.hasObstacle(_gameState.playerX + dx, _gameState.playerZ + dz)) {
        return;
      }
    }

    setState(() {
      _isJumping = true;
      _rollingDirection = direction;
      _lastDirection = direction;
      _controller.duration = const Duration(milliseconds: 500);
      _controller.forward(from: 0.0);
    });
  }

  void _triggerRoll(int direction, {int durationMs = 350}) {
    if (_controller.isAnimating || _gameState.isGameOver) return;

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

    // Ghost can pass through obstacles
    if (!_gameState.isPowerUpActive(PowerUpType.ghost)) {
      if (WorldGenerator.hasObstacle(_gameState.playerX + dx, _gameState.playerZ + dz)) {
        setState(() => _queuedSteps = 0);
        return;
      }
    }

    // Speed boost = faster animation
    final speedMultiplier = _gameState.isPowerUpActive(PowerUpType.speed) ? 0.6 : 1.0;

    setState(() {
      _isJumping = false;
      _rollingDirection = direction;
      _lastDirection = direction;
      _controller.duration = Duration(milliseconds: (durationMs * speedMultiplier).round());
      _controller.forward(from: 0.0);
    });
  }

  void _restartGame() {
    setState(() {
      _gameState.reset();
      _cameraX = 0;
      _cameraZ = 0;
      _currentRotation = Matrix4.identity();
      _enemies = WorldGenerator.generateEnemies(0, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Cyberpunk neon theme
    const bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D0221), Color(0xFF150734), Color(0xFF1A0A47)],
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (_controller.isAnimating || _gameState.isGameOver) return;
                final tapPos = details.localPosition;
                final localDx = tapPos.dx - center.dx;
                final localDy = tapPos.dy - center.dy;

                if ((localDx > 0 && localDy > 0) || (localDx < 0 && localDy < 0)) {
                  _triggerJump(localDx > 0 ? 0 : 1);
                } else {
                  _triggerJump(localDx > 0 ? 3 : 2);
                }
              },
              onPanStart: (details) => _dragStart = details.localPosition,
              onPanUpdate: (details) {
                if (_controller.isAnimating || _dragStart == null || _gameState.isGameOver) return;

                final displacement = details.localPosition - _dragStart!;
                if (displacement.distance > 25.0) {
                  final dx = displacement.dx;
                  final dy = displacement.dy;

                  if ((dx > 0 && dy > 0) || (dx < 0 && dy < 0)) {
                    _triggerRoll(dx > 0 ? 0 : 1);
                  } else {
                    _triggerRoll(dx > 0 ? 3 : 2);
                  }
                  _dragStart = null;
                }
              },
              onPanEnd: (details) {
                _dragStart = null;
                final velocity = details.velocity.pixelsPerSecond.distance;
                if (velocity > 800.0) {
                  setState(() => _queuedSteps = (velocity / 800.0).floor().clamp(0, 5));
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Grid
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.copy(_cameraMatrix)..rotateX(math.pi / 2),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: EnhancedGridPainter(
                        cameraX: _cameraX,
                        cameraZ: _cameraZ,
                        gridSize: cubeSize,
                        primaryColor: Colors.purple.shade800,
                        accentColor: Colors.cyanAccent,
                      ),
                    ),
                  ),

                  // Collectibles
                  ..._buildVisibleCollectibles(),

                  // Power-ups
                  ..._buildVisiblePowerUps(),

                  // Portals
                  ..._buildVisiblePortals(),

                  // Obstacles
                  ..._buildVisibleObstacles(),

                  // Enemies
                  ..._buildVisibleEnemies(),

                  // Player Cube
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final worldToCamera = Matrix4.identity()..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ));
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.copy(_cameraMatrix)..multiply(worldToCamera),
                        child: _buildRollingCube(),
                      );
                    },
                  ),

                  // HUD
                  HudOverlay(state: _gameState),

                  // Game Over
                  if (_gameState.isGameOver)
                    GameOverOverlay(
                      score: _gameState.score,
                      highScore: _gameState.highScore,
                      onRestart: _restartGame,
                      onExit: () => Navigator.pop(context),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildVisibleCollectibles() {
    final widgets = <Widget>[];
    final centerX = (_cameraX / cubeSize).round();
    final centerZ = (_cameraZ / cubeSize).round();

    for (int ix = centerX - 6; ix <= centerX + 6; ix++) {
      for (int iz = centerZ - 6; iz <= centerZ + 6; iz++) {
        final collectible = WorldGenerator.getCollectible(ix, iz, _gameState.collectedItems);
        if (collectible != null) {
          final worldPos = Vector3(ix * cubeSize, 0, iz * cubeSize);
          final worldToCamera = Matrix4.identity()..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ));
          final fullMatrix = Matrix4.copy(_cameraMatrix)
            ..multiply(worldToCamera)
            ..translateByVector3(worldPos);

          widgets.add(
            Transform(
              transform: fullMatrix,
              alignment: Alignment.center,
              child: CollectibleWidget(type: collectible.type),
            ),
          );
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildVisiblePowerUps() {
    final widgets = <Widget>[];
    final centerX = (_cameraX / cubeSize).round();
    final centerZ = (_cameraZ / cubeSize).round();

    for (int ix = centerX - 6; ix <= centerX + 6; ix++) {
      for (int iz = centerZ - 6; iz <= centerZ + 6; iz++) {
        final powerUp = WorldGenerator.getPowerUp(ix, iz, _gameState.collectedItems);
        if (powerUp != null) {
          final worldPos = Vector3(ix * cubeSize, 0, iz * cubeSize);
          final worldToCamera = Matrix4.identity()..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ));
          final fullMatrix = Matrix4.copy(_cameraMatrix)
            ..multiply(worldToCamera)
            ..translateByVector3(worldPos);

          widgets.add(
            Transform(
              transform: fullMatrix,
              alignment: Alignment.center,
              child: PowerUpWidget(type: powerUp.type),
            ),
          );
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildVisiblePortals() {
    final widgets = <Widget>[];
    final centerX = (_cameraX / cubeSize).round();
    final centerZ = (_cameraZ / cubeSize).round();

    for (int ix = centerX - 8; ix <= centerX + 8; ix++) {
      for (int iz = centerZ - 8; iz <= centerZ + 8; iz++) {
        final portal = WorldGenerator.getPortal(ix, iz);
        if (portal != null) {
          final worldPos = Vector3(ix * cubeSize, 0, iz * cubeSize);
          final worldToCamera = Matrix4.identity()..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ));
          final fullMatrix = Matrix4.copy(_cameraMatrix)
            ..multiply(worldToCamera)
            ..translateByVector3(worldPos);

          widgets.add(
            Transform(
              transform: fullMatrix,
              alignment: Alignment.center,
              child: PortalWidget(colorIndex: portal.colorIndex),
            ),
          );
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildVisibleObstacles() {
    final widgets = <Widget>[];
    final centerX = (_cameraX / cubeSize).round();
    final centerZ = (_cameraZ / cubeSize).round();

    final worldToCamera = Matrix4.identity()..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ));
    final projection = Matrix4.copy(_cameraMatrix)..multiply(worldToCamera);

    for (int ix = centerX - 8; ix <= centerX + 8; ix++) {
      for (int iz = centerZ - 8; iz <= centerZ + 8; iz++) {
        if (WorldGenerator.hasObstacle(ix, iz)) {
          final translation = Vector3(ix * cubeSize, -halfCubeSize, iz * cubeSize);
          widgets.add(
            Transform(
              alignment: Alignment.center,
              transform: projection,
              child: _renderCubeAt(translation, Matrix4.identity(), hue: 260, saturation: 0.3, lightness: 0.35),
            ),
          );
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildVisibleEnemies() {
    final widgets = <Widget>[];
    final worldToCamera = Matrix4.identity()..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ));

    for (final enemy in _enemies) {
      final worldPos = Vector3(enemy.x * cubeSize, -halfCubeSize, enemy.z * cubeSize);
      final fullMatrix = Matrix4.copy(_cameraMatrix)
        ..multiply(worldToCamera)
        ..translateByVector3(worldPos);

      widgets.add(
        Transform(
          transform: fullMatrix,
          alignment: Alignment.center,
          child: EnemyWidget(type: enemy.type, cubeSize: cubeSize * 0.9),
        ),
      );
    }
    return widgets;
  }

  Widget _buildRollingCube() {
    final startX = _gameState.playerX * cubeSize;
    final startZ = _gameState.playerZ * cubeSize;

    var translation = Vector3(startX, -halfCubeSize, startZ);
    var animRotation = Matrix4.identity();

    if (_controller.isAnimating && _rollingDirection != null) {
      final animValue = _controller.value;

      if (_isJumping) {
        final jumpDistance = cubeSize * 2.0;
        final jumpHeight = cubeSize * 1.2;
        final progress = animValue;
        final yOffset = -math.sin(math.pi * progress) * jumpHeight;

        Vector3 dirVector;
        Vector3 axis;
        double angle;

        switch (_rollingDirection) {
          case 0:
            dirVector = Vector3(1, 0, 0);
            axis = Vector3(0, 0, 1);
            angle = progress * math.pi;
            break;
          case 1:
            dirVector = Vector3(-1, 0, 0);
            axis = Vector3(0, 0, 1);
            angle = -progress * math.pi;
            break;
          case 2:
            dirVector = Vector3(0, 0, 1);
            axis = Vector3(1, 0, 0);
            angle = -progress * math.pi;
            break;
          default:
            dirVector = Vector3(0, 0, -1);
            axis = Vector3(1, 0, 0);
            angle = progress * math.pi;
        }

        translation =
            Vector3(startX, -halfCubeSize, startZ) + (dirVector * (progress * jumpDistance)) + Vector3(0, yOffset, 0);
        animRotation = Matrix4.identity()..rotate(axis, angle);
      } else {
        Vector3 pivotOffset;
        Vector3 axis;
        double angle;

        switch (_rollingDirection) {
          case 0:
            pivotOffset = Vector3(halfCubeSize, halfCubeSize, 0);
            axis = Vector3(0, 0, 1);
            angle = animValue * math.pi / 2;
            break;
          case 1:
            pivotOffset = Vector3(-halfCubeSize, halfCubeSize, 0);
            axis = Vector3(0, 0, 1);
            angle = -animValue * math.pi / 2;
            break;
          case 2:
            pivotOffset = Vector3(0, halfCubeSize, halfCubeSize);
            axis = Vector3(1, 0, 0);
            angle = -animValue * math.pi / 2;
            break;
          default:
            pivotOffset = Vector3(0, halfCubeSize, -halfCubeSize);
            axis = Vector3(1, 0, 0);
            angle = animValue * math.pi / 2;
        }

        final rotMat = Matrix4.identity()..rotate(axis, angle);
        translation = Vector3(startX, -halfCubeSize, startZ) + pivotOffset + rotMat.transformed3(-pivotOffset);
        animRotation = rotMat;
      }
    }

    final combinedRotation = Matrix4.identity()
      ..multiply(animRotation)
      ..multiply(_currentRotation);

    // Player cube: neon cyan
    return _renderCubeAt(translation, combinedRotation, hue: 180, saturation: 0.9, lightness: 0.55);
  }

  Widget _renderCubeAt(
    Vector3 translation,
    Matrix4 rotationAndOrientation, {
    required double hue,
    required double saturation,
    required double lightness,
  }) {
    final cubeFullMatrix = Matrix4.identity()
      ..translateByVector3(translation)
      ..multiply(rotationAndOrientation);

    final processedFaces = _baseFaces.map((face) {
      final viewTransform = Matrix4.copy(_cameraMatrix)
        ..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ))
        ..multiply(cubeFullMatrix)
        ..multiply(face.baseTransform);

      face.zDepth = viewTransform.getTranslation().z;

      final worldNormal = rotationAndOrientation.transformed3(face.baseNormal);
      final intensity = (worldNormal.dot(_lightVector) + 1.0) / 2.0;
      final currentLightness = lightness + (intensity * 0.35);

      face.displayColor = HSLColor.fromAHSL(1, hue, saturation, currentLightness).toColor();
      return face;
    }).toList();

    processedFaces.sort((a, b) => a.zDepth!.compareTo(b.zDepth!));

    return Transform(
      alignment: Alignment.center,
      transform: cubeFullMatrix,
      child: Stack(
        children: processedFaces.map((face) {
          return Positioned.fill(
            child: Center(
              child: Transform(
                transform: face.baseTransform,
                alignment: Alignment.center,
                child: CubeFace(color: face.displayColor, size: cubeSize),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
