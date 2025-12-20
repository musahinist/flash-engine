import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' as f2d;
import '../../core/systems/physics.dart';
import '../framework.dart';

class FlashArea extends FlashNodeWidget {
  final f2d.Shape shape;
  final void Function(f2d.Contact)? onCollisionStart;
  final void Function(f2d.Contact)? onCollisionEnd;

  const FlashArea({
    super.key,
    required this.shape,
    this.onCollisionStart,
    this.onCollisionEnd,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
  });

  @override
  State<FlashArea> createState() => _FlashAreaState();
}

class _FlashAreaState extends FlashNodeWidgetState<FlashArea, FlashPhysicsBody> {
  @override
  FlashPhysicsBody createNode() {
    final element = context.getElementForInheritedWidgetOfExactType<InheritedFlashNode>();
    final engine = (element?.widget as InheritedFlashNode?)?.engine;
    final world = engine?.physicsWorld;

    if (world == null) {
      throw Exception('FlashArea requires a FlashPhysicsWorld');
    }

    final bodyDef = f2d.BodyDef()..type = f2d.BodyType.static;
    if (widget.position != null) {
      bodyDef.position = f2d.Vector2(widget.position!.x, widget.position!.y);
    }

    final body = world.world.createBody(bodyDef);
    final fixtureDef = f2d.FixtureDef(widget.shape)..isSensor = true;
    body.createFixture(fixtureDef);

    final node = FlashPhysicsBody(body: body);
    node.onCollisionStart = widget.onCollisionStart;
    node.onCollisionEnd = widget.onCollisionEnd;
    return node;
  }
}
