import 'package:flutter/material.dart';
import '../../core/systems/physics.dart';
import '../framework.dart';

/// A trigger volume that reports when something touches it.
///
/// The native solver reports a contact *count* per body, not which body is on
/// the other side, so the callbacks say "something entered" rather than
/// identifying the counterpart. Naming the other body needs native support
/// that does not exist yet.
///
/// It is also not a true sensor: the solver has no `isSensor` handling, so an
/// area still pushes bodies out the way a static body would. Treat it as
/// "a static body that tells you when it is touched".
class FArea extends FNodeWidget {
  final int shapeType;
  final double width;
  final double height;

  /// Called on the frame something starts touching this area.
  final VoidCallback? onCollisionStart;

  /// Called on the frame nothing is touching this area any more.
  final VoidCallback? onCollisionEnd;

  const FArea({
    super.key,
    this.shapeType = FPhysics.circle,
    this.width = 100,
    this.height = 100,
    this.onCollisionStart,
    this.onCollisionEnd,
    super.position,
    super.rotation,
    super.scale,
    super.name = 'Area',
    super.child,
  });

  @override
  State<FArea> createState() => _FAreaState();
}

class _FAreaState extends FNodeWidgetState<FArea, FPhysicsBody> {
  @override
  FPhysicsBody createNode() {
    final element = context.getElementForInheritedWidgetOfExactType<InheritedFNode>();
    final engine = (element?.widget as InheritedFNode?)?.engine;
    final world = engine?.physicsWorld;

    if (world == null && engine != null) {
      engine.physicsWorld = FPhysicsSystem(gravity: FPhysics.standardGravity);
    }

    final activeWorld = engine?.physicsWorld;
    if (activeWorld == null) {
      throw Exception('FArea: Failed to initialize physics world');
    }

    final node = FPhysicsBody(
      world: activeWorld.world,
      type: 0, // STATIC/SENSOR
      shapeType: widget.shapeType,
      x: widget.position?.x ?? 0,
      y: widget.position?.y ?? 0,
      width: widget.width,
      height: widget.height,
      rotation: widget.rotation?.z ?? 0,
      name: widget.name ?? 'Area',
    );

    node.collisionEntered.connect(_handleEnter);
    node.collisionExited.connect(_handleExit);
    return node;
  }

  void _handleEnter(FPhysicsBody _) => widget.onCollisionStart?.call();
  void _handleExit(FPhysicsBody _) => widget.onCollisionEnd?.call();

  @override
  void dispose() {
    node.collisionEntered.disconnect(_handleEnter);
    node.collisionExited.disconnect(_handleExit);
    super.dispose();
  }
}
