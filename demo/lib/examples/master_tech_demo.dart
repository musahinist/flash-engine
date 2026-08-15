import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as v;

// --- Game Logic Nodes ---

class GameController extends FNode {
  final FSignal<int> scoreChanged = FSignal();
  int score = 0;

  GameController() : super(name: 'GameController');

  @override
  void ready() {
    print('GameController Ready!');
  }

  void addScore(int amount) {
    score += amount;
    scoreChanged.emit(score);
  }
}

class Coin extends FPhysicsBody {
  double _aliveTime = 0.0;

  Coin({required super.world, required super.x, required super.y})
    : super(
        type: FPhysics.staticBody, // Changed to STATIC so they don't move/scatter
        shapeType: FPhysics.circle, // Explicitly pass Y used for creation
        width: 20,
        height: 20,
        color: Colors.yellow,
      ) {
    debugDraw = true;
    addToGroup('collectibles');

    // Note: Static bodies only collide with Dynamic bodies.
    // Player is Dynamic, so this works.
    collision.connect((_) {
      // SAFETY: Grace period to avoid initialization glitches
      if (_aliveTime < 1.0) return;

      // NOTE: We cannot check 'other.name' yet because Native API sends 'this' as collision signal.
      // But since only Player is Dynamic, any collision triggers collection.

      collect();
    });
  }

  void collect() {
    print('Coin collected!');

    if (parent is GameController) {
      (parent as GameController).addScore(10);
    } else {
      final controller = tree?.root.children.whereType<GameController>().firstOrNull;
      controller?.addScore(10);
    }

    queueFree();
  }

  @override
  void process(double dt) {
    // process(), not update(): update is the pump that evaluates ProcessMode
    // and drives children. Overriding it means the node keeps working even
    // when it is disabled.
    super.process(dt);
    _aliveTime += dt;
  }
}

class PlayerController extends FPhysicsBody {
  final double speed = 300.0; // Velocity in pixels/sec

  PlayerController({required super.world})
    : super(
        name: 'Player',
        type: FPhysics.dynamicBody,
        shapeType: FPhysics.box,
        width: 40,
        height: 40,
        color: Colors.cyan,
        friction: 0.0, // No friction needed for setVelocity control
        restitution: 0.0,
      ) {
    debugDraw = true;
    // Disallow rotation for character controller feel
    // (requires API, if not available, we accept rotation or set angular damping)
  }
}

// --- Main Widget ---

class MasterTechDemo extends StatefulWidget {
  const MasterTechDemo({super.key});

  @override
  State<MasterTechDemo> createState() => _MasterTechDemoState();
}

class _MasterTechDemoState extends State<MasterTechDemo> {
  // Logic Root
  final GameController gameController = GameController();

  // Physics System
  late final FPhysicsSystem physicsSystem;

  // HUD State
  final ValueNotifier<int> scoreNotifier = ValueNotifier(0);

  // Mobile Input State
  v.Vector2 joystickInput = v.Vector2.zero();

  @override
  void initState() {
    super.initState();
    physicsSystem = FPhysicsSystem(gravity: v.Vector2(0, 0)); // Top-down, 0 gravity

    // Connect Signals
    gameController.scoreChanged.connect((newScore) {
      scoreNotifier.value = newScore;
    });
  }

  @override
  void dispose() {
    scoreNotifier.dispose();
    physicsSystem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: FView(
        physicsWorld: physicsSystem,
        enableInputCapture: true,
        child: Stack(
          children: [
            // SCENE SETUP
            Builder(
              builder: (context) {
                final engine = context.dependOnInheritedWidgetOfExactType<InheritedFNode>()?.engine;

                if (engine != null && !engine.scene.children.contains(gameController)) {
                  if (!engine.scene.children.contains(gameController)) {
                    print("Initializing Demo Scene...");
                    engine.scene.addChild(gameController);

                    // Add Camera logic
                    final camera = FCameraNode(name: 'MainCam');
                    camera.transform.position.z = 500;
                    engine.scene.addChild(camera);
                    engine.registerCamera(camera);

                    final world = physicsSystem.world;

                    // Create Player
                    final player = PlayerController(world: world);
                    player.transform.position.setValues(0, 0, 0);
                    gameController.addChild(player);

                    // Input Listener override
                    engine.addUpdateListener((dt) {
                      final input = engine.input;
                      double dx = 0;
                      double dy = 0;

                      // Keyboard Input
                      // Physics is Y-Up. W (Up) -> +Y. S (Down) -> -Y.
                      if (input.isKeyPressed(LogicalKeyboardKey.keyW)) dy += 1;
                      if (input.isKeyPressed(LogicalKeyboardKey.keyS)) dy -= 1;
                      if (input.isKeyPressed(LogicalKeyboardKey.keyA)) dx -= 1;
                      if (input.isKeyPressed(LogicalKeyboardKey.keyD)) dx += 1;

                      // Joystick Input
                      // Joystick gives Screen Coords (Up = -Y, Down = +Y).
                      // We need Physics Coords (Up = +Y, Down = -Y).
                      // So we must invert Y.
                      dx += joystickInput.x;
                      dy -= joystickInput.y; // Invert Y

                      if (dx != 0 || dy != 0) {
                        player.setVelocity(dx * player.speed, dy * player.speed);
                      } else {
                        player.setVelocity(0, 0); // Stop instantly when input release
                      }
                    });

                    // Create Coins
                    final rnd = Random();
                    for (int i = 0; i < 15; i++) {
                      final x = (rnd.nextDouble() - 0.5) * 500;
                      final y = (rnd.nextDouble() - 0.5) * 800; // Wider spread

                      // Need to set position via Constructor, because _syncFromPhysics will overwrite transform
                      // if we rely on transform.position setting later.
                      final coin = Coin(world: world, x: x, y: y);
                      gameController.addChild(coin);
                    }
                  }
                }
                return const SizedBox.shrink();
              },
            ),

            // HUD UI
            Positioned(
              top: 40,
              left: 20,
              child: ValueListenableBuilder<int>(
                valueListenable: scoreNotifier,
                builder: (context, score, _) {
                  return Text(
                    'Score: $score',
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.orange)],
                    ),
                  );
                },
              ),
            ),

            // Back Button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // Virtual Joystick (Left Bottom)
            Positioned(
              bottom: 40,
              left: 20,
              child: VirtualJoystick(
                onStickDrag: (dx, dy) {
                  joystickInput.setValues(dx, dy);
                },
              ),
            ),

            // Controls (Right Bottom)
            Positioned(
              bottom: 40,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.extended(
                    onPressed: () {
                      gameController.tree?.callGroup('collectibles', (node) {
                        if (node is Coin) {
                          node.collect();
                        } else {
                          node.queueFree();
                        }
                      });
                    },
                    label: const Text('Destroy'),
                    icon: const Icon(Icons.delete_forever),
                    backgroundColor: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple Virtual Joystick Widget
class VirtualJoystick extends StatefulWidget {
  final void Function(double dx, double dy) onStickDrag;
  const VirtualJoystick({super.key, required this.onStickDrag});

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _stickPos = Offset.zero;
  final double _radius = 60.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _updateStick(details.localPosition),
      onPanUpdate: (details) => _updateStick(details.localPosition),
      onPanEnd: (_) {
        setState(() {
          _stickPos = Offset.zero;
        });
        widget.onStickDrag(0, 0);
      },
      child: Container(
        width: _radius * 2,
        height: _radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: Colors.white30, width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: _stickPos,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }

  void _updateStick(Offset localPos) {
    final center = Offset(_radius, _radius);
    final delta = localPos - center;
    final dist = delta.distance;
    final clampedDist = min(dist, _radius);
    final clampedDelta = dist > 0 ? (delta / dist * clampedDist) : Offset.zero;

    setState(() {
      _stickPos = clampedDelta;
    });

    // Normalize output -1 to 1
    widget.onStickDrag(clampedDelta.dx / _radius, clampedDelta.dy / _radius);
  }
}
