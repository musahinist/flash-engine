import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// RayCast Demo showcasing FRayCast2D functionality.
/// - A player-controlled box that shoots a ray from its center.
/// - Static obstacles that the ray detects.
/// - Debug drawing shows ray (red when not hitting, green when hitting).
class RayCastDemo extends StatefulWidget {
  const RayCastDemo({super.key});

  @override
  State<RayCastDemo> createState() => _RayCastDemoState();
}

class _RayCastDemoState extends State<RayCastDemo> {
  late final FPhysicsSystem physicsSystem;
  PlayerNode? player;
  FRayCast2D? raycast;

  // HUD State
  final ValueNotifier<String> hitInfoNotifier = ValueNotifier('None');

  // Mobile Input State
  v.Vector2 joystickInput = v.Vector2.zero();

  @override
  void initState() {
    super.initState();
    physicsSystem = FPhysicsSystem(gravity: v.Vector2(0, 0));
  }

  @override
  void dispose() {
    hitInfoNotifier.dispose();
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

                if (engine != null && player == null) {
                  print("Initializing RayCast Demo Scene...");

                  final camera = FCameraNode(name: 'MainCam');
                  camera.transform.position.z = 500;
                  engine.scene.addChild(camera);
                  engine.registerCamera(camera);

                  final world = physicsSystem.world;

                  // Create Player
                  player = PlayerNode(world: world);
                  engine.scene.addChild(player!);

                  // Attach RayCast2D to player
                  raycast = FRayCast2D(
                    name: 'PlayerRay',
                    targetPosition: v.Vector2(0, 300), // Cast upwards
                    debugDraw: true,
                    debugColor: Colors.red,
                  );
                  raycast!.setWorld(world);
                  player!.addChild(raycast!);

                  // Connect signal
                  raycast!.bodyEntered.connect((bodyId) {
                    hitInfoNotifier.value = 'Hit Body ID: $bodyId';
                  });
                  raycast!.bodyExited.connect((bodyId) {
                    hitInfoNotifier.value = 'Exited Body ID: $bodyId';
                  });

                  // Create Obstacles
                  final rnd = Random();
                  for (int i = 0; i < 5; i++) {
                    final obstacle = ObstacleNode(
                      world: world,
                      x: (rnd.nextDouble() - 0.5) * 400,
                      y: 100 + rnd.nextDouble() * 300,
                      width: 60 + rnd.nextDouble() * 60,
                      height: 40 + rnd.nextDouble() * 40,
                    );
                    engine.scene.addChild(obstacle);
                  }

                  // Input Listener
                  engine.onUpdate = () {
                    final input = engine.input;
                    double dx = 0;
                    double dy = 0;

                    if (input.isKeyPressed(LogicalKeyboardKey.keyW)) dy += 1;
                    if (input.isKeyPressed(LogicalKeyboardKey.keyS)) dy -= 1;
                    if (input.isKeyPressed(LogicalKeyboardKey.keyA)) dx -= 1;
                    if (input.isKeyPressed(LogicalKeyboardKey.keyD)) dx += 1;

                    dx += joystickInput.x;
                    dy -= joystickInput.y;

                    if (dx != 0 || dy != 0) {
                      player!.setVelocity(dx * player!.speed, dy * player!.speed);
                    } else {
                      player!.setVelocity(0, 0);
                    }

                    // Update HUD if colliding
                    if (raycast!.isColliding) {
                      hitInfoNotifier.value =
                          'Hit ID: ${raycast!.colliderBodyId}, '
                          'Point: (${raycast!.collisionPoint.x.toStringAsFixed(1)}, ${raycast!.collisionPoint.y.toStringAsFixed(1)})';
                    } else if (hitInfoNotifier.value.startsWith('Hit')) {
                      hitInfoNotifier.value = 'None';
                    }
                  };
                }
                return const SizedBox.shrink();
              },
            ),

            // HUD UI
            Positioned(
              top: 40,
              left: 20,
              child: ValueListenableBuilder<String>(
                valueListenable: hitInfoNotifier,
                builder: (context, info, _) {
                  return Text(
                    'RayCast Hit: $info',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold),
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

            // Virtual Joystick
            Positioned(
              bottom: 40,
              left: 20,
              child: VirtualJoystick(
                onStickDrag: (dx, dy) {
                  joystickInput.setValues(dx, dy);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helper Nodes ---

class PlayerNode extends FPhysicsBody {
  final double speed = 250.0;

  PlayerNode({required super.world})
    : super(
        name: 'Player',
        type: FPhysics.dynamicBody,
        shapeType: FPhysics.box,
        width: 40,
        height: 40,
        color: Colors.cyan,
        friction: 0.0,
        restitution: 0.0,
      ) {
    debugDraw = true;
  }
}

class ObstacleNode extends FPhysicsBody {
  ObstacleNode({required super.world, required super.x, required super.y, required super.width, required super.height})
    : super(name: 'Obstacle', type: FPhysics.staticBody, shapeType: FPhysics.box, color: Colors.deepOrange) {
    debugDraw = true;
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

    widget.onStickDrag(clampedDelta.dx / _radius, clampedDelta.dy / _radius);
  }
}
