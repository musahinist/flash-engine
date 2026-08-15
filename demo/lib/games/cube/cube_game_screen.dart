import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../shared/cube_face.dart';
import '../shared/face_def.dart';
import 'package:flash/flash.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'painters/grid_painter.dart';

class CubeGameScreen extends StatefulWidget {
  const CubeGameScreen({super.key});

  @override
  State<CubeGameScreen> createState() => _CubeGameScreenState();
}

class _CubeGameScreenState extends State<CubeGameScreen> with TickerProviderStateMixin {
  static const double cubeSize = 60.0;
  static const double halfCubeSize = cubeSize / 2.0;

  // State: gridX, gridZ (Depth)
  int gridX = 0;
  int gridZ = 0;

  // Camera State (Smoothly follows the target)
  double _cameraX = 0.0;
  double _cameraZ = 0.0;

  // Diamond Collection State
  int _score = 0;
  final Set<String> _collectedDiamonds = {};

  // Momentum State
  int _queuedSteps = 0;
  int? _lastDirection;

  // Gesture Tracking
  Offset? _dragStart;

  // Animation handling
  late AnimationController _controller;
  late final Ticker _ticker;

  // Matrices & Caching
  late final Matrix4 _cameraMatrix;
  late final List<FaceDef> _baseFaces;
  final Vector3 _lightVector = Vector3(0.5, -1.0, -0.5).normalized();

  // Current 3D Rotation (visual orientation only)
  Matrix4 _currentRotation = Matrix4.identity();

  // Animation state
  int? _rollingDirection;
  bool _isJumping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _submitMove();
      }
    });

    // Continuous ticker for soft camera follow
    _ticker = createTicker((_) {
      final double targetX = gridX * cubeSize;
      final double targetZ = gridZ * cubeSize;
      final double dx = targetX - _cameraX;
      final double dz = targetZ - _cameraZ;

      if (dx.abs() > 0.01 || dz.abs() > 0.01) {
        setState(() {
          _cameraX += dx * 0.06;
          _cameraZ += dz * 0.06;
        });
      }
    })..start();

    // Cache the standard isometric camera matrix (projection)
    _cameraMatrix = Matrix4.identity()
      ..rotateX(-math.atan(1.0 / math.sqrt(2.0)))
      ..rotateY(-math.pi / 4.0);

    // Baseline face definitions
    _baseFaces = [
      FaceDef('front', Vector3(0, 0, -1), Matrix4.identity()..translateByVector3(Vector3(0.0, 0.0, -halfCubeSize))),
      FaceDef(
        'back',
        Vector3(0, 0, 1),
        Matrix4.identity()
          ..translateByVector3(Vector3(0.0, 0.0, halfCubeSize))
          ..rotateY(math.pi),
      ),
      FaceDef(
        'right',
        Vector3(1, 0, 0),
        Matrix4.identity()
          ..translateByVector3(Vector3(halfCubeSize, 0.0, 0.0))
          ..rotateY(math.pi / 2.0),
      ),
      FaceDef(
        'left',
        Vector3(-1, 0, 0),
        Matrix4.identity()
          ..translateByVector3(Vector3(-halfCubeSize, 0.0, 0.0))
          ..rotateY(-math.pi / 2.0),
      ),
      FaceDef(
        'top',
        Vector3(0, -1, 0),
        Matrix4.identity()
          ..translateByVector3(Vector3(0.0, -halfCubeSize, 0.0))
          ..rotateX(math.pi / 2.0),
      ),
      FaceDef(
        'bottom',
        Vector3(0, 1, 0),
        Matrix4.identity()
          ..translateByVector3(Vector3(0.0, halfCubeSize, 0.0))
          ..rotateX(-math.pi / 2.0),
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _ticker.dispose();
    super.dispose();
  }

  bool _hasDiamond(int x, int z) {
    if (x == 0 && z == 0) return false;
    final String key = '$x,$z';
    if (_collectedDiamonds.contains(key)) return false;

    // Deterministic hash that works across all platforms (web/mobile/desktop)
    int h = x * 374761393 ^ z * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h.abs() % 10) == 0;
  }

  bool _hasObstacle(int x, int z) {
    if (x.abs() <= 1 && z.abs() <= 1) return false; // Clear start area

    // Improved hash to avoid linear patterns (MurmurHash3-style mixer)
    int h = x * 73856093 ^ z * 19349663;
    h = (h ^ (h >> 16)) * 0x85ebca6b;
    h = (h ^ (h >> 13)) * 0xc2b2ae35;
    h = (h ^ (h >> 16));

    // Frequency: ~5% (1 in 20)
    // Also ensure no overlap with diamonds
    return (h.abs() % 20) == 0 && !_hasDiamond(x, z);
  }

  void _submitMove() {
    if (_rollingDirection == null) return;

    setState(() {
      // Update logical grid position
      final int step = _isJumping ? 2 : 1;
      switch (_rollingDirection) {
        case 0:
          gridX += step;
          break; // +X (Right)
        case 1:
          gridX -= step;
          break; // -X (Left)
        case 2:
          gridZ += step;
          break; // +Z (Back)
        case 3:
          gridZ -= step;
          break; // -Z (Front)
      }

      double angle = 0.0;
      Vector3 axis = Vector3(1.0, 0.0, 0.0);

      switch (_rollingDirection) {
        case 0:
          angle = math.pi / 2.0;
          axis = Vector3(0.0, 0.0, 1.0);
          break;
        case 1:
          angle = -math.pi / 2.0;
          axis = Vector3(0.0, 0.0, 1.0);
          break;
        case 2:
          angle = -math.pi / 2.0;
          axis = Vector3(1.0, 0.0, 0.0);
          break;
        case 3:
          angle = math.pi / 2.0;
          axis = Vector3(1.0, 0.0, 0.0);
          break;
      }

      _currentRotation = (Matrix4.identity()..rotate(axis, angle * (_isJumping ? 2.0 : 1.0))) * _currentRotation;
      _rollingDirection = null;
      _isJumping = false;
      _controller.reset();

      // Check for diamond collection
      if (_hasDiamond(gridX, gridZ)) {
        _collectedDiamonds.add('$gridX,$gridZ');
        _score++;
      }

      // CHAIN MOMENTUM
      if (_queuedSteps > 0 && _lastDirection != null) {
        _queuedSteps--;
        _triggerRoll(_lastDirection!, durationMs: 200);
      }
    });
  }

  void _triggerJump(int direction) {
    if (_controller.isAnimating) return;

    // Boundary/Obstacle check for landing position
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

    if (_hasObstacle(gridX + dx, gridZ + dz)) {
      // Blocked move - maybe add a shake effect later
      return;
    }

    setState(() {
      _isJumping = true;
      _rollingDirection = direction;
      _lastDirection = direction;
      _controller.duration = const Duration(milliseconds: 600);
      _controller.forward(from: 0.0);
    });
  }

  void _triggerRoll(int direction, {int durationMs = 400}) {
    if (_controller.isAnimating) return;

    // Check target cell for obstacle
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

    if (_hasObstacle(gridX + dx, gridZ + dz)) {
      // Stopped by wall, clear momentum
      setState(() {
        _queuedSteps = 0;
      });
      return;
    }

    setState(() {
      _isJumping = false;
      _rollingDirection = direction;
      _lastDirection = direction;
      _controller.duration = Duration(milliseconds: durationMs);
      _controller.forward(from: 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A5A40),
      appBar: AppBar(
        title: const Text(
          'Cube Roller',
          style: TextStyle(color: Color(0xFFDAD7CD), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFDAD7CD)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.diamond, color: Colors.cyanAccent, size: 24),
                const SizedBox(width: 8),
                Text(
                  '$_score',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (_controller.isAnimating) return;
              final tapPos = details.localPosition;
              final localDx = tapPos.dx - center.dx;
              final localDy = tapPos.dy - center.dy;

              // Diagonal Mapping for Taps
              // Top-Right / Bottom-Left line (X axis) vs Top-Left / Bottom-Right line (Z axis)
              if ((localDx > 0.0 && localDy > 0.0) || (localDx < 0.0 && localDy < 0.0)) {
                if (localDx > 0.0) {
                  _triggerJump(0); // Right (+X)
                } else {
                  _triggerJump(1); // Left (-X)
                }
              } else {
                if (localDx > 0.0) {
                  _triggerJump(3); // Up (-Z)
                } else {
                  _triggerJump(2); // Down (+Z)
                }
              }
            },
            onPanStart: (details) {
              _dragStart = details.localPosition;
            },
            onPanUpdate: (details) {
              if (_controller.isAnimating || _dragStart == null) return;

              final currentPos = details.localPosition;
              final displacement = currentPos - _dragStart!;

              // Threshold: 25 pixels before triggering
              if (displacement.distance > 25.0) {
                final dx = displacement.dx;
                final dy = displacement.dy;

                // Simplified isometric mapping
                if ((dx > 0.0 && dy > 0.0) || (dx < 0.0 && dy < 0.0)) {
                  if (dx > 0.0) {
                    _triggerRoll(0); // Right (+X)
                  } else {
                    _triggerRoll(1); // Left (-X)
                  }
                } else {
                  if (dx > 0.0) {
                    _triggerRoll(3); // Up (-Z)
                  } else {
                    _triggerRoll(2); // Down (+Z)
                  }
                }

                // Reset drag start to prevent multiple triggers in one swipe
                _dragStart = null;
              }
            },
            onPanEnd: (details) {
              _dragStart = null;
              final velocity = details.velocity.pixelsPerSecond.distance;
              if (velocity > 800.0) {
                setState(() {
                  _queuedSteps = (velocity / 800.0).floor().clamp(0, 5);
                });
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Playfield Grid
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.copy(_cameraMatrix)..rotateX(math.pi / 2.0),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: GridPainter(
                      cameraX: _cameraX,
                      cameraZ: _cameraZ,
                      gridSize: cubeSize,
                      color: const Color(0xFF588157).withValues(alpha: 0.3),
                    ),
                  ),
                ),

                // Render Diamonds in View
                ..._buildVisibleDiamonds(),

                // Render Obstacles in View
                ..._buildVisibleObstacles(),

                // 3D Cube (Affected by camera offset)
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
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildVisibleDiamonds() {
    final List<Widget> widgets = [];
    final int centerX = (_cameraX / cubeSize).round();
    final int centerZ = (_cameraZ / cubeSize).round();

    for (int ix = centerX - 5; ix <= centerX + 5; ix++) {
      for (int iz = centerZ - 5; iz <= centerZ + 5; iz++) {
        if (_hasDiamond(ix, iz)) {
          final worldPos = Vector3(ix * cubeSize, 0.0, iz * cubeSize);
          final worldToCamera = Matrix4.identity()..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ));

          final fullMatrix = Matrix4.copy(_cameraMatrix)
            ..multiply(worldToCamera)
            ..translateByVector3(worldPos);

          widgets.add(Transform(transform: fullMatrix, alignment: Alignment.center, child: const FFloatingItem(child: FDiamondWidget())));
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildVisibleObstacles() {
    final List<Widget> widgets = [];
    final int centerX = (_cameraX / cubeSize).round();
    final int centerZ = (_cameraZ / cubeSize).round();

    final worldToCamera = Matrix4.identity()..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ));
    final projection = Matrix4.copy(_cameraMatrix)..multiply(worldToCamera);

    for (int ix = centerX - 8; ix <= centerX + 8; ix++) {
      for (int iz = centerZ - 8; iz <= centerZ + 8; iz++) {
        if (_hasObstacle(ix, iz)) {
          final translation = Vector3(ix * cubeSize, -halfCubeSize, iz * cubeSize);
          widgets.add(
            Transform(
              alignment: Alignment.center,
              transform: projection,
              child: _renderCubeAt(translation, Matrix4.identity(), hue: 0, saturation: 0, lightness: 0.5),
            ),
          );
        }
      }
    }
    return widgets;
  }

  Widget _buildRollingCube() {
    final double startX = gridX * cubeSize;
    final double startZ = gridZ * cubeSize;

    Vector3 translation = Vector3(startX, -halfCubeSize, startZ);
    Matrix4 animRotation = Matrix4.identity();

    if (_controller.isAnimating && _rollingDirection != null) {
      final double animValue = _controller.value;
      double angle = 0.0;
      Vector3 axis = Vector3(1.0, 0.0, 0.0);
      Vector3 pivotOffset = Vector3.zero();

      if (_isJumping) {
        // Jump distance 2 cells
        final double jumpDistance = cubeSize * 2.0;
        final double jumpHeight = cubeSize * 1.2;
        final double progress = animValue;

        // Parabolic arc for translation
        final double yOffset = -math.sin(math.pi * progress) * jumpHeight;

        Vector3 dirVector = Vector3.zero();
        switch (_rollingDirection) {
          case 0:
            dirVector = Vector3(1, 0, 0);
            axis = Vector3(0.0, 0.0, 1.0);
            angle = progress * math.pi;
            break;
          case 1:
            dirVector = Vector3(-1, 0, 0);
            axis = Vector3(0.0, 0.0, 1.0);
            angle = -progress * math.pi;
            break;
          case 2:
            dirVector = Vector3(0, 0, 1);
            axis = Vector3(1.0, 0.0, 0.0);
            angle = -progress * math.pi;
            break;
          case 3:
            dirVector = Vector3(0, 0, -1);
            axis = Vector3(1.0, 0.0, 0.0);
            angle = progress * math.pi;
            break;
        }

        translation =
            Vector3(startX, -halfCubeSize, startZ) + (dirVector * (progress * jumpDistance)) + Vector3(0, yOffset, 0);
        animRotation = Matrix4.identity()..rotate(axis, angle);
      } else {
        // Normal rolling
        switch (_rollingDirection) {
          case 0:
            pivotOffset = Vector3(halfCubeSize, halfCubeSize, 0.0);
            axis = Vector3(0.0, 0.0, 1.0);
            angle = animValue * math.pi / 2.0;
            break;
          case 1:
            pivotOffset = Vector3(-halfCubeSize, halfCubeSize, 0.0);
            axis = Vector3(0.0, 0.0, 1.0);
            angle = -animValue * math.pi / 2.0;
            break;
          case 2:
            pivotOffset = Vector3(0.0, halfCubeSize, halfCubeSize);
            axis = Vector3(1.0, 0.0, 0.0);
            angle = -animValue * math.pi / 2.0;
            break;
          case 3:
            pivotOffset = Vector3(0.0, halfCubeSize, -halfCubeSize);
            axis = Vector3(1.0, 0.0, 0.0);
            angle = animValue * math.pi / 2.0;
            break;
        }

        final rotMat = Matrix4.identity()..rotate(axis, angle);
        translation = Vector3(startX, -halfCubeSize, startZ) + pivotOffset + rotMat.transformed3(-pivotOffset);
        animRotation = rotMat;
      }
    }

    final Matrix4 combinedRotation = Matrix4.identity()
      ..multiply(animRotation)
      ..multiply(_currentRotation);

    return _renderCubeAt(translation, combinedRotation, hue: 35.0, saturation: 0.8, lightness: 0.55);
  }

  Widget _renderCubeAt(
    Vector3 translation,
    Matrix4 rotationAndOrientation, {
    required double hue,
    required double saturation,
    required double lightness,
  }) {
    final Matrix4 cubeFullMatrix = Matrix4.identity()
      ..translateByVector3(translation)
      ..multiply(rotationAndOrientation);

    final List<FaceDef> processedFaces = _baseFaces.map((face) {
      final Matrix4 viewTransform = Matrix4.copy(_cameraMatrix)
        ..translateByVector3(Vector3(-_cameraX, 0, -_cameraZ))
        ..multiply(cubeFullMatrix)
        ..multiply(face.baseTransform);

      face.zDepth = viewTransform.getTranslation().z;

      final worldNormal = rotationAndOrientation.transformed3(face.baseNormal);
      final intensity = (worldNormal.dot(_lightVector) + 1.0) / 2.0;
      final currentLightness = lightness + (intensity * 0.35);

      face.displayColor = HSLColor.fromAHSL(1.0, hue, saturation, currentLightness).toColor();
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
