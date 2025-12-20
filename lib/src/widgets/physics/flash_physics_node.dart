import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' as f2d;
import '../../core/systems/physics.dart';
import '../framework.dart';

class FlashPhysicsNode extends FlashNodeWidget {
  final f2d.Body body;

  const FlashPhysicsNode({super.key, required this.body, super.child, super.name});

  @override
  State<FlashPhysicsNode> createState() => _FlashPhysicsNodeState();
}

class _FlashPhysicsNodeState extends FlashNodeWidgetState<FlashPhysicsNode, FlashPhysicsBody> {
  @override
  FlashPhysicsBody createNode() => FlashPhysicsBody(body: widget.body);
}
