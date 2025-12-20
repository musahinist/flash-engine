import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:forge2d/forge2d.dart' as f2d;
import 'dart:math';

class PhysicsDemoExample extends StatefulWidget {
  const PhysicsDemoExample({super.key});

  @override
  State<PhysicsDemoExample> createState() => _PhysicsDemoExampleState();
}

class _PhysicsDemoExampleState extends State<PhysicsDemoExample> {
  late final FlashPhysicsWorld physicsWorld;
  final List<f2d.Body> bodies = [];
  final List<Color> colors = [];
  final List<v.Vector2> sizes = [];

  @override
  void initState() {
    super.initState();
    physicsWorld = FlashPhysicsWorld(gravity: FlashPhysics.standardGravity);
    _createGround();
    for (int i = 0; i < 10; i++) {
      _addRandomBox();
    }
  }

  void _createGround() {
    final shape = f2d.PolygonShape()
      ..setAsBox(FlashPhysics.toMeters(400), FlashPhysics.toMeters(20), v.Vector2.zero(), 0);
    final bodyDef = f2d.BodyDef()
      ..type = f2d.BodyType.static
      ..position = v.Vector2(0, FlashPhysics.toMeters(-400));

    final body = physicsWorld.world.createBody(bodyDef);
    body.createFixture(f2d.FixtureDef(shape)..friction = 0.5);

    bodies.add(body);
    colors.add(Colors.blueGrey);
    sizes.add(v.Vector2(800, 40));
  }

  void _addRandomBox() {
    final random = Random();
    final size = 30.0 + random.nextDouble() * 30.0;
    final x = (random.nextDouble() - 0.5) * 400;
    final y = 400 + (random.nextDouble() * 400);

    final shape = f2d.PolygonShape()
      ..setAsBox(FlashPhysics.toMeters(size / 2), FlashPhysics.toMeters(size / 2), v.Vector2.zero(), 0);
    final bodyDef = f2d.BodyDef()
      ..type = f2d.BodyType.dynamic
      ..position = v.Vector2(FlashPhysics.toMeters(x), FlashPhysics.toMeters(y))
      ..angularVelocity = (random.nextDouble() - 0.5) * 5;

    final body = physicsWorld.world.createBody(bodyDef);
    body.createFixture(
      f2d.FixtureDef(shape)
        ..density = 1.0
        ..restitution = 0.6
        ..friction = 0.3,
    );

    setState(() {
      bodies.add(body);
      colors.add(Colors.primaries[random.nextInt(Colors.primaries.length)]);
      sizes.add(v.Vector2(size, size));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Physics Demo (Declarative)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Flash(
        physicsWorld: physicsWorld,
        child: Stack(
          children: [
            for (int i = 0; i < bodies.length; i++)
              FlashPhysicsNode(
                body: bodies[i],
                child: FlashBox(width: sizes[i].x, height: sizes[i].y, color: colors[i]),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addRandomBox, child: const Icon(Icons.add)),
    );
  }
}
