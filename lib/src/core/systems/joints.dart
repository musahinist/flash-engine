import 'dart:ffi';
import 'dart:math' as math;
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../native/flash_native_bindings.dart' as native;
import '../native/flash_native_bindings.dart' show JointDef, JointType;
import 'physics.dart'; // Import physics system directly to ensure visibility

/// Base class for all joints
abstract class FJoint {
  final FPhysicsBody bodyA;
  final FPhysicsBody bodyB;
  JointId? _jointId;

  FJoint({required this.bodyA, required this.bodyB});

  /// Create the joint in the physics world
  void create(WorldId world);

  /// Destroy the joint
  void destroy(WorldId world) {
    if (_jointId != null && _jointId!.isValid) {
      native.destroyJoint(world, _jointId!);
      _jointId = null;
    }
  }

  bool get isCreated => _jointId != null && _jointId!.isValid;

  /// Records the result of `create_joint`, throwing if the world refused it.
  ///
  /// `create_joint` returns -1 when the world's joint pool is full — a fixed
  /// 200 — and that is reachable in a scene that builds joints at runtime. Only
  /// one of the four joint types used to check at all, and it printed to stdout
  /// rather than surfacing anything a caller could act on; the other three
  /// stored the -1 and carried on, so the joint simply did not exist and
  /// nothing said so. Physics is a tier 2 feature: it fails loudly.
  void _store(JointId id, String kind) {
    if (!id.isValid) {
      throw StateError(
        'Failed to create a $kind joint: the physics world would not accept it. '
        'The most likely cause is exhausting the joint pool, which holds 200.',
      );
    }
    _jointId = id;
  }
}

/// Distance joint - maintains a fixed or spring distance between two bodies
class FDistanceJointStructure extends FJoint {
  final v.Vector2 anchorA;
  final v.Vector2 anchorB;
  final double length;
  final double frequency;
  final double dampingRatio;

  FDistanceJointStructure({
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

  static double _calculateDistance(FPhysicsBody bodyA, FPhysicsBody bodyB, v.Vector2? anchorA, v.Vector2? anchorB) {
    final aPos = bodyA.transform.position;
    final bPos = bodyB.transform.position;
    final aAnchor = anchorA ?? v.Vector2.zero();
    final bAnchor = anchorB ?? v.Vector2.zero();

    final dx = (bPos.x + bAnchor.x) - (aPos.x + aAnchor.x);
    final dy = (bPos.y + bAnchor.y) - (aPos.y + aAnchor.y);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  void create(WorldId world) {
    if (isCreated) return;

    // Allocate JointDef
    final def = calloc<JointDef>();
    try {
      def.ref.type = JointType.distance;
      def.ref.bodyA = bodyA.bodyId;
      def.ref.bodyB = bodyB.bodyId;
      def.ref.anchorAx = anchorA.x;
      def.ref.anchorAy = anchorA.y;
      def.ref.anchorBx = anchorB.x;
      def.ref.anchorBy = anchorB.y;
      def.ref.length = length;
      def.ref.frequency = frequency;
      def.ref.dampingRatio = dampingRatio;

      _store(native.createJoint(world, def), 'distance');
    } finally {
      calloc.free(def);
    }
  }
}

/// Revolute joint - forces two bodies to share a common anchor point
class FRevoluteJointStructure extends FJoint {
  final v.Vector2 anchor;
  final bool enableMotor;
  final double motorSpeed;
  final double maxMotorTorque;
  final bool enableLimit;
  final double lowerAngle;
  final double upperAngle;

  FRevoluteJointStructure({
    required super.bodyA,
    required super.bodyB,
    required this.anchor,
    this.enableMotor = false,
    this.motorSpeed = 0.0,
    this.maxMotorTorque = 0.0,
    this.enableLimit = false,
    this.lowerAngle = 0.0,
    this.upperAngle = 0.0,
  });

  @override
  void create(WorldId world) {
    if (isCreated) return;

    final def = calloc<JointDef>();
    try {
      def.ref.type = JointType.revolute;
      def.ref.bodyA = bodyA.bodyId;
      def.ref.bodyB = bodyB.bodyId;
      def.ref.anchorAx = anchor.x;
      def.ref.anchorAy = anchor.y;

      def.ref.enableMotor = enableMotor ? 1 : 0;
      def.ref.motorSpeed = motorSpeed;
      def.ref.maxMotorTorque = maxMotorTorque;
      def.ref.enableLimit = enableLimit ? 1 : 0;
      def.ref.lowerAngle = lowerAngle;
      def.ref.upperAngle = upperAngle;

      _store(native.createJoint(world, def), 'revolute');
    } finally {
      calloc.free(def);
    }
  }
}

/// Prismatic joint - allows relative translation along a specified axis
class FPrismaticJointStructure extends FJoint {
  final v.Vector2 axis;
  final bool enableLimit;
  final double lowerTranslation;
  final double upperTranslation;
  final bool enableMotor;
  final double motorSpeed;
  final double maxMotorForce;

  FPrismaticJointStructure({
    required super.bodyA,
    required super.bodyB,
    required this.axis,
    this.enableLimit = false,
    this.lowerTranslation = 0.0,
    this.upperTranslation = 0.0,
    this.enableMotor = false,
    this.motorSpeed = 0.0,
    this.maxMotorForce = 0.0,
  });

  @override
  void create(WorldId world) {
    if (isCreated) return;

    final def = calloc<JointDef>();
    try {
      def.ref.type = JointType.prismatic;
      def.ref.bodyA = bodyA.bodyId;
      def.ref.bodyB = bodyB.bodyId;
      def.ref.axisx = axis.x;
      def.ref.axisy = axis.y;
      def.ref.enableLimit = enableLimit ? 1 : 0;
      def.ref.lowerTranslation = lowerTranslation;
      def.ref.upperTranslation = upperTranslation;
      def.ref.enableMotor = enableMotor ? 1 : 0;
      def.ref.motorSpeed = motorSpeed;
      def.ref.maxMotorForce = maxMotorForce;

      _store(native.createJoint(world, def), 'prismatic');
    } finally {
      calloc.free(def);
    }
  }
}

/// Weld joint - constrains relative position and orientation
class FWeldJointStructure extends FJoint {
  final v.Vector2 anchor;
  final double stiffness;
  final double damping;

  FWeldJointStructure({
    required super.bodyA,
    required super.bodyB,
    required this.anchor,
    this.stiffness = 0.0,
    this.damping = 0.0,
  });

  @override
  void create(WorldId world) {
    if (isCreated) return;

    final def = calloc<JointDef>();
    try {
      def.ref.type = JointType.weld;
      def.ref.bodyA = bodyA.bodyId;
      def.ref.bodyB = bodyB.bodyId;
      def.ref.anchorAx = anchor.x;
      def.ref.anchorAy = anchor.y;
      def.ref.stiffness = stiffness;
      def.ref.damping = damping;

      _store(native.createJoint(world, def), 'weld');
    } finally {
      calloc.free(def);
    }
  }
}
