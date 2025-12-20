import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' as f2d;
import '../../core/systems/physics.dart';
import '../framework.dart';

class FlashStaticBody extends FlashNodeWidget {
  final f2d.BodyDef? bodyDef;
  final List<f2d.FixtureDef>? fixtures;

  const FlashStaticBody({
    super.key,
    this.bodyDef,
    this.fixtures,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
  });

  @override
  State<FlashStaticBody> createState() => _FlashStaticBodyState();
}

class _FlashStaticBodyState extends FlashNodeWidgetState<FlashStaticBody, FlashPhysicsBody> {
  @override
  FlashPhysicsBody createNode() {
    final element = context.getElementForInheritedWidgetOfExactType<InheritedFlashNode>();
    final engine = (element?.widget as InheritedFlashNode?)?.engine;
    final world = engine?.physicsWorld;

    if (world == null) {
      throw Exception('FlashStaticBody requires a FlashPhysicsWorld in the Flash engine');
    }

    final bodyDef = widget.bodyDef ?? f2d.BodyDef();
    bodyDef.type = f2d.BodyType.static;
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

    return FlashPhysicsBody(body: body);
  }
}
