import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../../core/systems/joints.dart';
import '../../core/systems/physics.dart';
import '../framework.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Internal node for handling physics joint logic.
class FJointNode extends FNode {
  final String nodeA;
  final String nodeB;
  final FJoint Function(FPhysicsBody a, FPhysicsBody b) creator;

  FJoint? _joint;
  FJoint? get joint => _joint;

  FJointNode({required super.name, required this.nodeA, required this.nodeB, required this.creator});

  @override
  void ready() {
    super.ready();
    _createJoint();
  }

  @override
  void exitTree() {
    final world = bodyA?.world;
    if (world != null) {
      _joint?.destroy(world);
    }
    super.exitTree();
  }

  FPhysicsBody? get bodyA => _findBody(nodeA);
  FPhysicsBody? get bodyB => _findBody(nodeB);

  FPhysicsBody? _findBody(String name) {
    if (tree == null) return null;
    final node = tree!.root.findChild(name, recursive: true);
    if (node == null) return null;

    if (node is FPhysicsBody) {
      return node;
    }
    return null;
  }

  void _createJoint() {
    final a = bodyA;
    final b = bodyB;

    if (a == null || b == null) return;
    if (a.world != b.world) return;

    _joint = creator(a, b);
    _joint?.create(a.world);
  }

  @override
  void draw(Canvas canvas) {
    final a = bodyA;
    final b = bodyB;
    if (a == null || b == null) return;

    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.6)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    // Convert world positions to local positions relative to this node
    final posA = a.worldPosition;
    final posB = b.worldPosition;

    final invWorld = Matrix4.copy(worldMatrix)..invert();
    final localA = invWorld.transform3(posA);
    final localB = invWorld.transform3(posB);

    canvas.drawLine(Offset(localA.x, localA.y), Offset(localB.x, localB.y), paint);
  }
}

// --- Declarative Widgets ---

class FDistanceJoint extends FNodeWidget {
  final String nodeA;
  final String nodeB;
  final v.Vector2? anchorA;
  final v.Vector2? anchorB;
  final double? length;
  final double frequency;
  final double dampingRatio;

  const FDistanceJoint({
    super.key,
    super.name,
    required this.nodeA,
    required this.nodeB,
    this.anchorA,
    this.anchorB,
    this.length,
    this.frequency = 0.0,
    this.dampingRatio = 0.0,
  });

  @override
  State<FDistanceJoint> createState() => _FDistanceJointState();
}

class _FDistanceJointState extends FNodeWidgetState<FDistanceJoint, FJointNode> {
  @override
  FJointNode createNode() {
    return FJointNode(
      name: widget.name ?? 'DistanceJoint',
      nodeA: widget.nodeA,
      nodeB: widget.nodeB,
      creator: (a, b) => FDistanceJointStructure(
        bodyA: a,
        bodyB: b,
        anchorA: widget.anchorA,
        anchorB: widget.anchorB,
        length: widget.length,
        frequency: widget.frequency,
        dampingRatio: widget.dampingRatio,
      ),
    );
  }
}

class FRevoluteJoint extends FNodeWidget {
  final String nodeA;
  final String nodeB;
  final v.Vector2 anchor;
  final bool enableMotor;
  final double motorSpeed;
  final double maxMotorTorque;
  final bool enableLimit;
  final double lowerAngle;
  final double upperAngle;

  const FRevoluteJoint({
    super.key,
    super.name,
    required this.nodeA,
    required this.nodeB,
    required this.anchor,
    this.enableMotor = false,
    this.motorSpeed = 0.0,
    this.maxMotorTorque = 0.0,
    this.enableLimit = false,
    this.lowerAngle = 0.0,
    this.upperAngle = 0.0,
  });

  @override
  State<FRevoluteJoint> createState() => _FRevoluteJointState();
}

class _FRevoluteJointState extends FNodeWidgetState<FRevoluteJoint, FJointNode> {
  @override
  FJointNode createNode() {
    return FJointNode(
      name: widget.name ?? 'RevoluteJoint',
      nodeA: widget.nodeA,
      nodeB: widget.nodeB,
      creator: (a, b) => FRevoluteJointStructure(
        bodyA: a,
        bodyB: b,
        anchor: widget.anchor,
        enableMotor: widget.enableMotor,
        motorSpeed: widget.motorSpeed,
        maxMotorTorque: widget.maxMotorTorque,
        enableLimit: widget.enableLimit,
        lowerAngle: widget.lowerAngle,
        upperAngle: widget.upperAngle,
      ),
    );
  }
}

class FPrismaticJoint extends FNodeWidget {
  final String nodeA;
  final String nodeB;
  final v.Vector2 axis;
  final bool enableLimit;
  final double lowerTranslation;
  final double upperTranslation;
  final bool enableMotor;
  final double motorSpeed;
  final double maxMotorForce;

  const FPrismaticJoint({
    super.key,
    super.name,
    required this.nodeA,
    required this.nodeB,
    required this.axis,
    this.enableLimit = false,
    this.lowerTranslation = 0.0,
    this.upperTranslation = 0.0,
    this.enableMotor = false,
    this.motorSpeed = 0.0,
    this.maxMotorForce = 0.0,
  });

  @override
  State<FPrismaticJoint> createState() => _FPrismaticJointState();
}

class _FPrismaticJointState extends FNodeWidgetState<FPrismaticJoint, FJointNode> {
  @override
  FJointNode createNode() {
    return FJointNode(
      name: widget.name ?? 'PrismaticJoint',
      nodeA: widget.nodeA,
      nodeB: widget.nodeB,
      creator: (a, b) => FPrismaticJointStructure(
        bodyA: a,
        bodyB: b,
        axis: widget.axis,
        enableLimit: widget.enableLimit,
        lowerTranslation: widget.lowerTranslation,
        upperTranslation: widget.upperTranslation,
        enableMotor: widget.enableMotor,
        motorSpeed: widget.motorSpeed,
        maxMotorForce: widget.maxMotorForce,
      ),
    );
  }
}

class FWeldJoint extends FNodeWidget {
  final String nodeA;
  final String nodeB;
  final v.Vector2 anchor;
  final double stiffness;
  final double damping;

  const FWeldJoint({
    super.key,
    super.name,
    required this.nodeA,
    required this.nodeB,
    required this.anchor,
    this.stiffness = 0.0,
    this.damping = 0.0,
  });

  @override
  State<FWeldJoint> createState() => _FWeldJointState();
}

class _FWeldJointState extends FNodeWidgetState<FWeldJoint, FJointNode> {
  @override
  FJointNode createNode() {
    return FJointNode(
      name: widget.name ?? 'WeldJoint',
      nodeA: widget.nodeA,
      nodeB: widget.nodeB,
      creator: (a, b) => FWeldJointStructure(
        bodyA: a,
        bodyB: b,
        anchor: widget.anchor,
        stiffness: widget.stiffness,
        damping: widget.damping,
      ),
    );
  }
}
