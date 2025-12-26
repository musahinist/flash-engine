import 'dart:ffi';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:flash/flash.dart';
import '../native/particles_ffi.dart';

/// Joint types matching C++ enum
class JointType {
  static const int distance = 0;
  static const int revolute = 1;
  static const int prismatic = 2;
  static const int weld = 3;
}

/// Base class for all joints
abstract class FlashJoint {
  final FlashPhysicsBody bodyA;
  final FlashPhysicsBody bodyB;
  int? _jointId;

  FlashJoint({required this.bodyA, required this.bodyB});

  /// Create the joint in the physics world
  void create(Pointer<PhysicsWorld> world);

  /// Destroy the joint
  void destroy(Pointer<PhysicsWorld> world) {
    if (_jointId != null && _jointId! >= 0) {
      // TODO: Add destroy_joint FFI binding
      _jointId = null;
    }
  }

  bool get isCreated => _jointId != null && _jointId! >= 0;
}

/// Distance joint - maintains a fixed or spring distance between two bodies
class FlashDistanceJoint extends FlashJoint {
  final v.Vector2 anchorA;
  final v.Vector2 anchorB;
  final double length;
  final double frequency;
  final double dampingRatio;

  FlashDistanceJoint({
    required super.bodyA,
    required super.bodyB,
    v.Vector2? anchorA,
    v.Vector2? anchorB,
    double? length,
    this.frequency = 0.0, // 0 = rigid, >0 = spring
    this.dampingRatio = 0.0,
  }) : anchorA = anchorA ?? v.Vector2.zero(),
       anchorB = anchorB ?? v.Vector2.zero(),
       length = length ?? _calculateDistance(bodyA, bodyB, anchorA, anchorB);

  static double _calculateDistance(
    FlashPhysicsBody bodyA,
    FlashPhysicsBody bodyB,
    v.Vector2? anchorA,
    v.Vector2? anchorB,
  ) {
    final aPos = bodyA.transform.position;
    final bPos = bodyB.transform.position;
    final aAnchor = anchorA ?? v.Vector2.zero();
    final bAnchor = anchorB ?? v.Vector2.zero();

    final dx = (bPos.x + bAnchor.x) - (aPos.x + aAnchor.x);
    final dy = (bPos.y + bAnchor.y) - (aPos.y + aAnchor.y);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  void create(Pointer<PhysicsWorld> world) {
    if (isCreated) return;

    // TODO: Create JointDef struct and call create_joint via FFI
    // For now, this is a placeholder
    print('Distance joint created: length=$length, freq=$frequency, damp=$dampingRatio');
  }
}

/// Revolute joint - allows rotation around a point (hinge/pivot)
class FlashRevoluteJoint extends FlashJoint {
  final v.Vector2 anchor;
  final double referenceAngle;
  final bool enableLimit;
  final double lowerAngle;
  final double upperAngle;
  final bool enableMotor;
  final double motorSpeed;
  final double maxMotorTorque;

  FlashRevoluteJoint({
    required super.bodyA,
    required super.bodyB,
    required this.anchor,
    this.referenceAngle = 0.0,
    this.enableLimit = false,
    this.lowerAngle = 0.0,
    this.upperAngle = 0.0,
    this.enableMotor = false,
    this.motorSpeed = 0.0,
    this.maxMotorTorque = 0.0,
  });

  @override
  void create(Pointer<PhysicsWorld> world) {
    if (isCreated) return;
    print('Revolute joint created at anchor=$anchor');
  }
}

/// Prismatic joint - allows sliding along an axis
class FlashPrismaticJoint extends FlashJoint {
  final v.Vector2 anchor;
  final v.Vector2 axis;
  final bool enableLimit;
  final double lowerTranslation;
  final double upperTranslation;
  final bool enableMotor;
  final double motorSpeed;
  final double maxMotorForce;

  FlashPrismaticJoint({
    required super.bodyA,
    required super.bodyB,
    required this.anchor,
    required this.axis,
    this.enableLimit = false,
    this.lowerTranslation = 0.0,
    this.upperTranslation = 0.0,
    this.enableMotor = false,
    this.motorSpeed = 0.0,
    this.maxMotorForce = 0.0,
  });

  @override
  void create(Pointer<PhysicsWorld> world) {
    if (isCreated) return;
    print('Prismatic joint created along axis=$axis');
  }
}

/// Weld joint - rigidly connects two bodies
class FlashWeldJoint extends FlashJoint {
  final v.Vector2 anchor;
  final double stiffness;
  final double damping;

  FlashWeldJoint({
    required super.bodyA,
    required super.bodyB,
    required this.anchor,
    this.stiffness = 0.0, // 0 = rigid
    this.damping = 0.0,
  });

  @override
  void create(Pointer<PhysicsWorld> world) {
    if (isCreated) return;
    print('Weld joint created at anchor=$anchor');
  }
}
