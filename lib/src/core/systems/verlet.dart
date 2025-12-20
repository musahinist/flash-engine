import 'package:vector_math/vector_math_64.dart';
import '../graph/node.dart';

/// Base class for physics joints
abstract class FlashJoint {
  final FlashNode? nodeA;
  final FlashNode? nodeB;
  final Vector3? anchorA; // Fixed anchor if nodeA is null
  final Vector3? anchorB; // Fixed anchor if nodeB is null

  FlashJoint({this.nodeA, this.nodeB, this.anchorA, this.anchorB});

  Vector3 get positionA => nodeA?.worldPosition ?? anchorA ?? Vector3.zero();
  Vector3 get positionB => nodeB?.worldPosition ?? anchorB ?? Vector3.zero();

  /// Update the joint physics
  void update(double dt);
}

/// Spring joint - connects two points with spring physics
class FlashSpringJoint extends FlashJoint {
  final double restLength;
  final double stiffness;
  final double damping;

  Vector3 velocityA = Vector3.zero();
  Vector3 velocityB = Vector3.zero();

  FlashSpringJoint({
    super.nodeA,
    super.nodeB,
    super.anchorA,
    super.anchorB,
    this.restLength = 100,
    this.stiffness = 50,
    this.damping = 0.5,
  });

  @override
  void update(double dt) {
    final delta = positionB - positionA;
    final distance = delta.length;
    if (distance == 0) return;

    final direction = delta.normalized();
    final displacement = distance - restLength;

    // Spring force: F = -k * x
    final springForce = direction * stiffness * displacement;

    // Apply to nodes
    if (nodeA != null) {
      velocityA += springForce * dt;
      velocityA *= (1 - damping * dt);
      nodeA!.transform.position += velocityA * dt;
    }

    if (nodeB != null) {
      velocityB -= springForce * dt;
      velocityB *= (1 - damping * dt);
      nodeB!.transform.position += velocityB * dt;
    }
  }
}

/// Rope segment for verlet integration
class RopePoint {
  Vector3 position;
  Vector3 oldPosition;
  bool locked;
  double mass;

  RopePoint({required this.position, this.locked = false, this.mass = 1.0}) : oldPosition = position.clone();

  Vector3 get velocity => position - oldPosition;
}

/// Rope joint using Verlet integration
class FlashRopeJoint extends FlashJoint {
  final List<RopePoint> points;
  final double segmentLength;
  final Vector3 gravity;
  final double damping;
  final int constraintIterations;

  FlashRopeJoint({
    super.anchorA,
    super.anchorB,
    int segments = 10,
    double totalLength = 200,
    Vector3? gravity,
    this.damping = 0.99,
    this.constraintIterations = 5,
  }) : gravity = gravity ?? Vector3(0, -200, 0),
       segmentLength = totalLength / segments,
       points = [] {
    _initializePoints(segments);
  }

  void _initializePoints(int segments) {
    final startPos = anchorA ?? Vector3.zero();
    final endPos = anchorB ?? Vector3(0, -segmentLength * segments, 0);

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final pos = Vector3(
        startPos.x + (endPos.x - startPos.x) * t,
        startPos.y + (endPos.y - startPos.y) * t,
        startPos.z + (endPos.z - startPos.z) * t,
      );
      points.add(
        RopePoint(
          position: pos,
          locked: i == 0, // Lock first point by default
        ),
      );
    }
  }

  /// Lock/unlock a point
  void lockPoint(int index, bool locked) {
    if (index >= 0 && index < points.length) {
      points[index].locked = locked;
    }
  }

  /// Move a locked point to position
  void movePoint(int index, Vector3 position) {
    if (index >= 0 && index < points.length) {
      points[index].position = position;
      points[index].oldPosition = position.clone();
    }
  }

  @override
  void update(double dt) {
    // Update anchor position if connected to nodeA (takes priority)
    if (nodeA != null && points.isNotEmpty) {
      points.first.position = nodeA!.worldPosition;
      points.first.oldPosition = points.first.position.clone();
    }
    // Note: If using movePoint(), anchorA is NOT used to override position
    // anchorA is only for initial positioning

    // Update end anchor if connected to nodeB
    if (nodeB != null && points.length > 1) {
      points.last.position = nodeB!.worldPosition;
      points.last.oldPosition = points.last.position.clone();
    }

    // Verlet integration
    for (final point in points) {
      if (point.locked) continue;

      final velocity = point.velocity * damping;
      point.oldPosition = point.position.clone();
      point.position += velocity + gravity * (dt * dt);
    }

    // Constraint satisfaction
    for (int iter = 0; iter < constraintIterations; iter++) {
      _applyConstraints();
    }
  }

  void _applyConstraints() {
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final delta = p2.position - p1.position;
      final distance = delta.length;
      if (distance == 0) continue;

      final error = distance - segmentLength;
      final correction = delta.normalized() * (error * 0.5);

      if (!p1.locked) {
        p1.position += correction;
      }
      if (!p2.locked) {
        p2.position -= correction;
      }
    }
  }

  /// Get all positions for rendering
  List<Vector3> get positions => points.map((p) => p.position).toList();
}

/// Distance joint - maintains fixed distance between two nodes
class FlashDistanceJoint extends FlashJoint {
  final double distance;

  FlashDistanceJoint({super.nodeA, super.nodeB, super.anchorA, super.anchorB, this.distance = 100});

  @override
  void update(double dt) {
    final delta = positionB - positionA;
    final currentDistance = delta.length;
    if (currentDistance == 0) return;

    final direction = delta.normalized();
    final error = currentDistance - distance;
    final correction = direction * (error * 0.5);

    if (nodeA != null) {
      nodeA!.transform.position += correction;
    }
    if (nodeB != null) {
      nodeB!.transform.position -= correction;
    }
  }
}

/// Pin joint - keeps a node at a fixed position
class FlashPinJoint extends FlashJoint {
  final Vector3 pinPosition;
  final double strength;

  FlashPinJoint({required super.nodeA, required this.pinPosition, this.strength = 1.0}) : super(anchorA: pinPosition);

  @override
  void update(double dt) {
    if (nodeA == null) return;

    final delta = pinPosition - nodeA!.transform.position;
    nodeA!.transform.position += delta * strength * dt;
  }
}

/// Joint manager for handling multiple joints
class FlashJointManager {
  final List<FlashJoint> _joints = [];

  void add(FlashJoint joint) {
    _joints.add(joint);
  }

  void remove(FlashJoint joint) {
    _joints.remove(joint);
  }

  void update(double dt) {
    for (final joint in _joints) {
      joint.update(dt);
    }
  }

  void clear() {
    _joints.clear();
  }

  int get count => _joints.length;

  List<FlashJoint> get joints => List.unmodifiable(_joints);
}
