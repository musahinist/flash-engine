import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' as f2d;
import '../../core/systems/physics.dart';
import '../framework.dart';

class FlashRigidBody extends FlashNodeWidget {
  final f2d.BodyDef? bodyDef;
  final List<f2d.FixtureDef>? fixtures;
  final void Function(f2d.Contact)? onCollision;
  final void Function(f2d.Contact)? onCollisionEnd;
  final void Function(f2d.Body)? onUpdate;

  const FlashRigidBody({
    super.key,
    this.bodyDef,
    this.fixtures,
    this.onCollision,
    this.onCollisionEnd,
    this.onUpdate,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
  });

  @override
  State<FlashRigidBody> createState() => _FlashRigidBodyState();
}

class _FlashRigidBodyState extends FlashNodeWidgetState<FlashRigidBody, FlashPhysicsBody> {
  @override
  FlashPhysicsBody createNode() {
    final element = context.getElementForInheritedWidgetOfExactType<InheritedFlashNode>();
    final engine = (element?.widget as InheritedFlashNode?)?.engine;
    final world = engine?.physicsWorld;

    if (world == null) {
      throw Exception('FlashRigidBody requires a FlashPhysicsWorld in the Flash engine');
    }

    final bodyDef = widget.bodyDef ?? (f2d.BodyDef()..type = f2d.BodyType.dynamic);
    if (widget.position != null) {
      bodyDef.position = f2d.Vector2(widget.position!.x, widget.position!.y);
    }
    if (widget.rotation != null) {
      bodyDef.angle = widget.rotation!.z;
    }

    final body = world.world.createBody(bodyDef);
    if (widget.fixtures != null) {
      for (final fixture in widget.fixtures!) {
        body.createFixture(fixture);
      }
    }

    final node = FlashPhysicsBody(body: body);
    node.onCollisionStart = widget.onCollision;
    node.onCollisionEnd = widget.onCollisionEnd;
    node.onUpdate = widget.onUpdate;
    return node;
  }
}
