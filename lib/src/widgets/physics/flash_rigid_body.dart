import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' as f2d;
import 'package:vector_math/vector_math_64.dart' as v;
import '../../core/systems/physics.dart';
import '../framework.dart';

/// Declarative widget to initialize a physics world in the Flash engine.
class FlashPhysicsWorldWidget extends StatefulWidget {
  final v.Vector2? gravity;

  const FlashPhysicsWorldWidget({super.key, this.gravity});

  @override
  State<FlashPhysicsWorldWidget> createState() => _FlashPhysicsWorldWidgetState();
}

class _FlashPhysicsWorldWidgetState extends State<FlashPhysicsWorldWidget> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final element = context.getElementForInheritedWidgetOfExactType<InheritedFlashNode>();
    final engine = (element?.widget as InheritedFlashNode?)?.engine;

    if (engine != null && engine.physicsWorld == null) {
      engine.physicsWorld = FlashPhysicsWorld(gravity: widget.gravity);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class FlashRigidBody extends FlashNodeWidget {
  final f2d.BodyDef? bodyDef;
  final List<f2d.FixtureDef>? fixtures;
  final void Function(f2d.Contact)? onCollision;
  final void Function(f2d.Contact)? onCollisionEnd;
  final void Function(f2d.Body)? onUpdate;

  /// Collision category (bitwise)
  final int category;

  /// Collision mask (bitwise)
  final int mask;

  const FlashRigidBody({
    super.key,
    this.bodyDef,
    this.fixtures,
    this.onCollision,
    this.onCollisionEnd,
    this.onUpdate,
    this.category = FlashCollisionLayer.layer1,
    this.mask = FlashCollisionLayer.all,
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
  void didUpdateWidget(FlashRigidBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.category != oldWidget.category || widget.mask != oldWidget.mask) {
      _updateFilters();
    }
  }

  void _updateFilters() {
    for (final fixture in node.body.fixtures) {
      final filter = f2d.Filter()
        ..categoryBits = widget.category
        ..maskBits = widget.mask;
      fixture.filterData = filter;
    }
  }

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
      bodyDef.position = f2d.Vector2(
        FlashPhysics.toMeters(widget.position!.x),
        FlashPhysics.toMeters(widget.position!.y),
      );
    }
    if (widget.rotation != null) {
      bodyDef.angle = widget.rotation!.z;
    }

    final body = world.world.createBody(bodyDef);
    if (widget.fixtures != null) {
      for (final fixtureDef in widget.fixtures!) {
        // Automatically scale fixture shapes from pixels to meters
        _scaleShape(fixtureDef.shape);

        // Apply collision filters to fixtures
        fixtureDef.filter.categoryBits = widget.category;
        fixtureDef.filter.maskBits = widget.mask;
        body.createFixture(fixtureDef);
      }
    }

    final node = FlashPhysicsBody(body: body);
    node.onCollisionStart = widget.onCollision;
    node.onCollisionEnd = widget.onCollisionEnd;
    node.onUpdate = widget.onUpdate;
    return node;
  }

  void _scaleShape(f2d.Shape shape) {
    if (shape is f2d.PolygonShape) {
      for (int i = 0; i < shape.vertices.length; i++) {
        shape.vertices[i].setFrom(FlashPhysics.toMetersV(shape.vertices[i]));
      }
    } else if (shape is f2d.CircleShape) {
      shape.radius = FlashPhysics.toMeters(shape.radius);
      shape.position.setFrom(FlashPhysics.toMetersV(shape.position));
    } else if (shape is f2d.EdgeShape) {
      shape.vertex1.setFrom(FlashPhysics.toMetersV(shape.vertex1));
      shape.vertex2.setFrom(FlashPhysics.toMetersV(shape.vertex2));
    }
  }
}
