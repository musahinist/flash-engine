import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../../core/systems/physics.dart';

import '../framework.dart';

/// Declarative widget to initialize a physics world in the Flash engine.
class FlashPhysicsWorld extends StatefulWidget {
  final v.Vector2? gravity;

  const FlashPhysicsWorld({super.key, this.gravity});

  @override
  State<FlashPhysicsWorld> createState() => _FlashPhysicsWorldState();
}

class _FlashPhysicsWorldState extends State<FlashPhysicsWorld> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final element = context.getElementForInheritedWidgetOfExactType<InheritedFlashNode>();
    final engine = (element?.widget as InheritedFlashNode?)?.engine;

    if (engine != null && engine.physicsWorld == null) {
      engine.physicsWorld = FlashPhysicsSystem(gravity: widget.gravity);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A rigid body that reacts to physics forces. Native implementation.
class FlashRigidBody extends FlashNodeWidget {
  final int type; // 0: Static, 1: Kinematic, 2: Dynamic
  final int shapeType; // FlashPhysics.circle or FlashPhysics.box
  final double width;
  final double height;
  final v.Vector2? initialVelocity;
  final void Function(FlashPhysicsBody)? onCollision;
  final void Function(FlashPhysicsBody)? onUpdate;
  final void Function(FlashPhysicsBody)? onCreated;
  final Color color;
  final bool debugDraw;

  const FlashRigidBody({
    super.key,
    super.position,
    this.type = 2, // Default: Dynamic
    this.shapeType = FlashPhysics.box, // Default to box for convenience
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
  });

  /// Shorthand constructor for squares/circles (as Boxes)
  factory FlashRigidBody.square({
    Key? key,
    required v.Vector3 position,
    required double size,
    v.Vector3? rotation,
    Widget? child,
    String? name,
    Color color = Colors.blue,
    v.Vector2? initialVelocity,
    void Function(FlashPhysicsBody)? onCollision,
    void Function(FlashPhysicsBody)? onUpdate,
    void Function(FlashPhysicsBody)? onCreated,
    bool debugDraw = false,
  }) {
    return FlashRigidBody(
      key: key,
      position: position,
      type: 2,
      shapeType: FlashPhysics.box,
      width: size,
      height: size,
      rotation: rotation,
      name: name,
      color: color,
      initialVelocity: initialVelocity,
      onCollision: onCollision,
      onUpdate: onUpdate,
      onCreated: onCreated,
      debugDraw: debugDraw,
      child: child,
    );
  }

  /// Shorthand constructor for circles
  factory FlashRigidBody.circle({
    Key? key,
    required v.Vector3 position,
    required double radius,
    v.Vector3? rotation,
    Widget? child,
    String? name,
    Color color = Colors.red,
    v.Vector2? initialVelocity,
    void Function(FlashPhysicsBody)? onCollision,
    void Function(FlashPhysicsBody)? onUpdate,
    void Function(FlashPhysicsBody)? onCreated,
    bool debugDraw = false,
  }) {
    return FlashRigidBody(
      key: key,
      position: position,
      type: 2,
      shapeType: FlashPhysics.circle,
      width: radius * 2,
      height: radius * 2,
      rotation: rotation,
      name: name,
      color: color,
      initialVelocity: initialVelocity,
      onCollision: onCollision,
      onUpdate: onUpdate,
      onCreated: onCreated,
      debugDraw: debugDraw,
      child: child,
    );
  }

  @override
  State<FlashRigidBody> createState() => _FlashRigidBodyState();
}

class _FlashRigidBodyState extends FlashNodeWidgetState<FlashRigidBody, FlashPhysicsBody> {
  @override
  FlashPhysicsBody createNode() {
    // Determine physics system.
    // Ideally we look up the engine. For now, we assume the global singleton mechanism
    // or that the parent creates it. FlashPhysicsBody currently requires a pointer.
    // We will use a safe fallback if context isn't ready, but usually it is.

    final physicsSystem = FlashPhysicsSystem(); // Uses existing singleton or creates new

    final double safeX = widget.position?.x ?? 0.0;
    final double safeY = widget.position?.y ?? 0.0;

    final body = FlashPhysicsBody(
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
    );

    if (widget.initialVelocity != null) {
      body.setVelocity(widget.initialVelocity!.x, widget.initialVelocity!.y);
    }

    body.onCollision = widget.onCollision;
    body.onUpdate = widget.onUpdate;

    if (widget.onCreated != null) {
      widget.onCreated!(body);
    }

    return body;
  }

  @override
  void applyProperties([FlashRigidBody? oldWidget]) {
    super.applyProperties(oldWidget);
    if (widget.debugDraw != oldWidget?.debugDraw) {
      node.debugDraw = widget.debugDraw;
    }
  }
}
