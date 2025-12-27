import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../../core/systems/physics.dart';

import '../framework.dart';

/// Declarative widget to initialize a physics world in the Flash engine.
class FPhysicsWorld extends StatefulWidget {
  final v.Vector2? gravity;

  const FPhysicsWorld({super.key, this.gravity});

  @override
  State<FPhysicsWorld> createState() => _FPhysicsWorldState();
}

class _FPhysicsWorldState extends State<FPhysicsWorld> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final element = context.getElementForInheritedWidgetOfExactType<InheritedFNode>();
    final engine = (element?.widget as InheritedFNode?)?.engine;

    if (engine != null && engine.physicsWorld == null) {
      engine.physicsWorld = FPhysicsSystem(gravity: widget.gravity);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A rigid body that reacts to physics forces. Native implementation.
class FRigidBody extends FNodeWidget {
  final int type; // 0: Static, 1: Kinematic, 2: Dynamic
  final int shapeType; // FPhysics.circle or FPhysics.box
  final double width;
  final double height;
  final v.Vector2? initialVelocity;
  final void Function(FPhysicsBody)? onCollision;
  final void Function(FPhysicsBody)? onUpdate;
  final void Function(FPhysicsBody)? onCreated;
  final Color color;
  final bool debugDraw;
  final double restitution;
  final double friction;
  final int? categoryBits;
  final int? maskBits;

  const FRigidBody({
    super.key,
    super.position,
    this.type = 2, // Default: Dynamic
    this.shapeType = FPhysics.box, // Default to box for convenience
    this.width = 50,
    this.height = 50,
    super.rotation,
    super.child,
    super.name,
    this.initialVelocity,
    this.onCollision,
    this.onUpdate,
    this.onCreated,
    this.color = Colors.blue,
    this.debugDraw = false,
    this.restitution = 0.5,
    this.friction = 0.1,
    this.categoryBits,
    this.maskBits,
  });

  /// Shorthand constructor for squares/boxes
  const FRigidBody.square({
    super.key,
    required double size,
    super.position,
    super.rotation,
    super.name,
    super.child,
    this.initialVelocity,
    this.onUpdate,
    this.onCreated,
    this.color = Colors.red,
    this.onCollision,
    this.debugDraw = false,
    this.restitution = 0.5,
    this.friction = 0.1,
    this.categoryBits,
    this.maskBits,
  }) : type = 2,
       shapeType = FPhysics.box,
       width = size,
       height = size;

  /// Shorthand constructor for circles
  const FRigidBody.circle({
    super.key,
    required double radius,
    super.position,
    super.rotation,
    super.name,
    super.child,
    this.initialVelocity,
    this.onUpdate,
    this.onCreated,
    this.color = Colors.blue,
    this.onCollision,
    this.debugDraw = false,
    this.restitution = 0.5,
    this.friction = 0.1,
    this.categoryBits,
    this.maskBits,
  }) : type = 2,
       shapeType = FPhysics.circle,
       width = radius * 2,
       height = radius * 2;

  @override
  State<FRigidBody> createState() => _FRigidBodyState();
}

class _FRigidBodyState extends FNodeWidgetState<FRigidBody, FPhysicsBody> {
  @override
  FPhysicsBody createNode() {
    // Look up shared engine to get the shared physics world
    final element = context.getElementForInheritedWidgetOfExactType<InheritedFNode>();
    final engine = (element?.widget as InheritedFNode?)?.engine;

    // Auto-initialize physics if missing (e.g. no FPhysicsWorld widget used)
    if (engine != null && engine.physicsWorld == null) {
      engine.physicsWorld = FPhysicsSystem();
    }

    final physicsSystem =
        engine?.physicsWorld ?? FPhysicsSystem(); // Fallback only if no engine (shouldn't happen in widget tree)

    final double safeX = widget.position?.x ?? 0.0;
    final double safeY = widget.position?.y ?? 0.0;

    final body = FPhysicsBody(
      world: physicsSystem.world,
      type: widget.type,
      shapeType: widget.shapeType,
      x: safeX,
      y: safeY,
      width: widget.width,
      height: widget.height,
      rotation: widget.rotation?.z ?? 0,
      name: widget.name ?? 'RigidBody',
      color: widget.color,
      debugDraw: widget.debugDraw,
      restitution: widget.restitution,
      friction: widget.friction,
      categoryBits: widget.categoryBits ?? 0x0001,
      maskBits: widget.maskBits ?? 0xFFFF,
    );

    if (widget.initialVelocity != null) {
      body.setVelocity(widget.initialVelocity!.x, widget.initialVelocity!.y);
    }

    if (widget.onCreated != null) {
      widget.onCreated!(body);
    }

    // Connect signals to widget callbacks
    if (widget.onUpdate != null) {
      body.physicsProcess.connect((b) => widget.onUpdate?.call(b));
    }
    if (widget.onCollision != null) {
      body.collision.connect((b) => widget.onCollision?.call(b));
    }

    return body;
  }

  @override
  void applyProperties([FRigidBody? oldWidget]) {
    super.applyProperties(oldWidget);
    if (widget.debugDraw != oldWidget?.debugDraw) {
      node.debugDraw = widget.debugDraw;
    }
  }
}
