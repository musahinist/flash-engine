import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';
import '../shared/virtual_joystick.dart';

// --- Game Logic Nodes ---

class GameController extends FNode {
  final FSignal<int> scoreChanged = FSignal();
  int score = 0;

  GameController() : super(name: 'GameController');

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
    return DemoPage(
      title: 'Master Tech Demo',
      subtitle: 'Signals, groups, physics and input, all at once.',
      accent: DemoTheme.accentAlt,
      controls: [
        DemoButton(
          label: 'Collect everything',
          icon: Icons.auto_awesome_rounded,
          tint: DemoTheme.warning,
          onPressed: () => gameController.tree?.callGroup('collectibles', (node) {
            // A group is the engine's answer to "everything of this kind",
            // without anyone holding a list.
            if (node is Coin) {
              node.collect();
            } else {
              node.queueFree();
            }
          }),
        ),
      ],
      readouts: [
        ValueListenableBuilder<int>(
          valueListenable: scoreNotifier,
          builder: (context, score, _) => DemoStat(
            label: 'Score',
            value: '$score',
            tint: DemoTheme.warning,
          ),
        ),
      ],
      hint: 'WASD or the stick. Coins report collection through a signal.',
      overlays: [
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: VirtualJoystick(
              tint: DemoTheme.accentAlt,
              onStickDrag: joystickInput.setValues,
            ),
          ),
        ),
      ],
      scene: FView(
        physicsWorld: physicsSystem,
        child: Stack(
          children: [
            // SCENE SETUP
            Builder(
              builder: (context) {
                final engine = context.dependOnInheritedWidgetOfExactType<InheritedFNode>()?.engine;

                if (engine != null && !engine.scene.children.contains(gameController)) {
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
                return const SizedBox.shrink();
              },
            ),

          ],
        ),
      ),
    );
  }
}


