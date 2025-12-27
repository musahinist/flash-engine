import 'dart:ffi';
import 'dart:math' as math;
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../native/particles_ffi.dart';
import '../native/physics_joints_ffi.dart';
import 'physics.dart'; // Import physics system directly to ensure visibility

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
  void destroy(Pointer world) {
    if (_jointId != null && _jointId! >= 0) {
      final ffi = FlashPhysicsSystem.jointsFFI;
      if (ffi != null) {
        ffi.destroyJoint(world, _jointId!);
      }
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

    final ffi = FlashPhysicsSystem.jointsFFI;
    if (ffi == null) {
      print('⚠️  Joints FFI not available');
      return;
    }

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

      _jointId = ffi.createJoint(world, def);

      if (_jointId! >= 0) {
        print('✅ Distance joint created: ID=$_jointId, length=${length.toStringAsFixed(1)}');
      } else {
        print('❌ Failed to create distance joint');
      }
    } finally {
      calloc.free(def);
    }
  }
}

/// Revolute joint - forces two bodies to share a common anchor point
class FlashRevoluteJoint extends FlashJoint {
  final v.Vector2 anchor;
  final bool enableMotor;
  final double motorSpeed;
  final double maxMotorTorque;
  final bool enableLimit;
  final double lowerAngle;
  final double upperAngle;

  FlashRevoluteJoint({
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
  void create(Pointer<PhysicsWorld> world) {
    if (isCreated) return;

    final ffi = FlashPhysicsSystem.jointsFFI;
    if (ffi == null) {
      print('⚠️  Joints FFI not available for Revolute Joint');
      return;
    }

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

      _jointId = ffi.createJoint(world, def);
      print('🔄 Revolute Joint Created: ID=$_jointId');
    } finally {
      calloc.free(def);
    }
  }
}

/// Prismatic joint - allows relative translation along a specified axis
class FlashPrismaticJoint extends FlashJoint {
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

    final ffi = FlashPhysicsSystem.jointsFFI;
    if (ffi == null) {
      print('⚠️ Joints FFI not available for Prismatic Joint');
      return;
    }

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

      _jointId = ffi.createJoint(world, def);
      print('📏 Prismatic Joint Created: ID=$_jointId');
    } finally {
      calloc.free(def);
    }
  }
}

/// Weld joint - constrains relative position and orientation
class FlashWeldJoint extends FlashJoint {
  final v.Vector2 anchor;
  final double stiffness;
  final double damping;

  FlashWeldJoint({
    required super.bodyA,
    required super.bodyB,
    required this.anchor,
    this.stiffness = 0.0,
    this.damping = 0.0,
  });

  @override
  void create(Pointer<PhysicsWorld> world) {
    if (isCreated) return;

    final ffi = FlashPhysicsSystem.jointsFFI;
    if (ffi == null) {
      print('⚠️ Joints FFI not available for Weld Joint');
      return;
    }

    final def = calloc<JointDef>();
    try {
      def.ref.type = JointType.weld;
      def.ref.bodyA = bodyA.bodyId;
      def.ref.bodyB = bodyB.bodyId;
      def.ref.anchorAx = anchor.x;
      def.ref.anchorAy = anchor.y;
      def.ref.stiffness = stiffness;
      def.ref.damping = damping;

      _jointId = ffi.createJoint(world, def);
      print('🔗 Weld Joint Created: ID=$_jointId');
    } finally {
      calloc.free(def);
    }
  }
}
