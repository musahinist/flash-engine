/// Dart mirror of the Flash native core (`src/native/*.cpp`).
///
/// Every symbol resolves through the `package:flash/flash_core` code asset
/// produced by `hook/build.dart`, so there is no runtime library lookup and no
/// filesystem path anywhere in this file. The struct layouts below must stay
/// byte-for-byte identical to the C++ headers; `test/native_abi_test.dart`
/// enforces that.
@DefaultAsset('package:flash/flash_core')
library;

import 'dart:ffi';

// FFI Struct Bit-mappings
// (Must match the C++ structs exactly)

final class NativeParticle extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double z;

  @Float()
  external double vx;
  @Float()
  external double vy;
  @Float()
  external double vz;

  @Float()
  external double life;
  @Float()
  external double maxLife;
  @Float()
  external double size;

  @Uint32()
  external int color;
}

final class NativeTransform extends Struct {
  @Float()
  external double m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14, m15;

  List<double> toList() => [m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14, m15];
}

final class NativeNode extends Struct {
  @Uint32()
  external int id;
  @Float()
  external double posX, posY, posZ;
  @Float()
  external double rotX, rotY, rotZ;
  @Float()
  external double scaleX, scaleY, scaleZ;

  external NativeTransform localMatrix;
  external NativeTransform worldMatrix;

  @Int32()
  external int parentId;
  @Int32()
  external int dirty;
  @Uint32()
  external int worldVersion;
  @Int32()
  external int alive;
}

final class NativeScene extends Struct {
  external Pointer<NativeNode> nodes;
  @Int32()
  external int maxNodes;
  @Int32()
  external int activeCount;
  @Uint32()
  external int totalUpdates;

  external Pointer<Int32> freeList;
  @Int32()
  external int freeCount;
}

final class PhysicsWorld extends Struct {
  external Pointer<NativeBody> bodies;
  @Int32()
  external int maxBodies;
  @Int32()
  external int activeCount;
  @Float()
  external double gravityX;
  @Float()
  external double gravityY;
  @Int32()
  external int velocityIterations;
  @Int32()
  external int positionIterations;

  // Solver configuration (Box2D-inspired)
  @Int32()
  external int enableWarmStarting;
  @Float()
  external double contactHertz;
  @Float()
  external double contactDampingRatio;
  @Float()
  external double restitutionThreshold;
  @Float()
  external double maxLinearVelocity;

  // Internal solver state (Must match order in physics.h)
  external Pointer<Void> constraints;
  @Int32()
  external int maxConstraints;
  @Int32()
  external int activeConstraints;

  external Pointer<Void> softBodies;
  @Int32()
  external int maxSoftBodies;
  @Int32()
  external int activeSoftBodies;
}

final class NativeBody extends Struct {
  @Uint32()
  external int id;
  @Int32()
  external int type;
  @Int32()
  external int shapeType;
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double rotation;
  @Float()
  external double vx;
  @Float()
  external double vy;
  @Float()
  external double angularVelocity;
  @Float()
  external double forceX;
  @Float()
  external double forceY;
  @Float()
  external double torque;
  @Float()
  external double mass;
  @Float()
  external double inverseMass;
  @Float()
  external double inertia;
  @Float()
  external double inverseInertia;
  @Float()
  external double restitution;
  @Float()
  external double friction;
  @Float()
  external double width;
  @Float()
  external double height;
  @Float()
  external double radius;
  @Int32()
  external int collisionCount;
  @Float()
  external double sleepTime; // Time body has been at rest
  @Uint32()
  external int categoryBits;
  @Uint32()
  external int maskBits;
  @Int32()
  external int proxyId;
  @Int32()
  external int isAwake;
}

final class ParticleEmitter extends Struct {
  external Pointer<NativeParticle> particles;

  @Int32()
  external int maxParticles;

  @Int32()
  external int activeCount;

  @Float()
  external double gravityX;
  @Float()
  external double gravityY;
  @Float()
  external double gravityZ;
  @Int32()
  external int shapeType;
}

/// Everything an emission burst needs. Mirrors `EmitParams` in particles.h.
final class EmitParams extends Struct {
  @Float()
  external double originX, originY, originZ;

  @Float()
  external double velMinX, velMinY, velMinZ;
  @Float()
  external double velMaxX, velMaxY, velMaxZ;

  @Float()
  external double lifetimeMin, lifetimeMax;
  @Float()
  external double sizeMin, sizeMax;

  @Float()
  external double spreadAngle;
  @Uint32()
  external int color;
}

// RayCast Struct (Must match C++ physics.h)
final class RayCastHit extends Struct {
  @Int32()
  external int bodyId;
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double normalX;
  @Float()
  external double normalY;
  @Float()
  external double fraction;
  @Int32()
  external int hit;
}

// ---------------------------------------------------------------------------
// Joints
// ---------------------------------------------------------------------------

/// Joint types, matching the C++ enum in `src/native/joints.h`.
///
/// Previously duplicated verbatim in both physics_joints_ffi.dart and
/// systems/joints.dart, where the two copies could drift apart silently.
abstract final class JointType {
  static const int distance = 0;
  static const int revolute = 1;
  static const int prismatic = 2;
  static const int weld = 3;
}

/// Opaque joint handle.
final class Joint extends Opaque {}

/// Joint definition passed to [createJoint].
final class JointDef extends Struct {
  @Int32()
  external int type;
  @Uint32()
  external int bodyA;
  @Uint32()
  external int bodyB;

  // Anchor points (local coordinates)
  @Float()
  external double anchorAx;
  @Float()
  external double anchorAy;
  @Float()
  external double anchorBx;
  @Float()
  external double anchorBy;

  // Distance joint parameters
  @Float()
  external double length;
  @Float()
  external double frequency;
  @Float()
  external double dampingRatio;

  // Revolute joint parameters
  @Float()
  external double referenceAngle;
  @Int32()
  external int enableLimit;
  @Float()
  external double lowerAngle;
  @Float()
  external double upperAngle;
  @Int32()
  external int enableMotor;
  @Float()
  external double motorSpeed;
  @Float()
  external double maxMotorTorque;

  // Prismatic joint parameters
  @Float()
  external double axisx;
  @Float()
  external double axisy;
  @Float()
  external double lowerTranslation;
  @Float()
  external double upperTranslation;
  @Float()
  external double maxMotorForce;

  // Weld joint parameters
  @Float()
  external double stiffness;
  @Float()
  external double damping;
}

// ---------------------------------------------------------------------------
// Native entry points
// ---------------------------------------------------------------------------
//
// `isLeaf: true` skips the Dart-to-native transition bookkeeping. It is only
// valid for functions that never call back into Dart, never allocate on the
// Dart heap and return promptly — which is true of every solver and buffer
// call here. It is deliberately omitted from ray_cast, which returns a struct
// by value.

/// Version handshake, also used as the availability probe. See [FlashNative].
@Native<Int32 Function()>(symbol: 'get_physics_version', isLeaf: true)
external int getPhysicsVersion();

// --- Particles ---

@Native<Void Function(Pointer<ParticleEmitter>, Float)>(symbol: 'update_particles', isLeaf: true)
external void updateParticles(Pointer<ParticleEmitter> emitter, double dt);

/// Spawns a whole burst in one call.
///
/// The per-particle path this replaced cost one FFI crossing and several Dart
/// allocations per particle — at the 1M-particle target that was ~500k calls
/// and ~2M allocations a second, which no amount of native speed could absorb.
@Native<Int32 Function(Pointer<ParticleEmitter>, Pointer<EmitParams>, Int32, Uint32)>(
  symbol: 'emit_particles',
  isLeaf: true,
)
external int emitParticles(Pointer<ParticleEmitter> emitter, Pointer<EmitParams> params, int count, int seed);

@Native<Int32 Function(Pointer<ParticleEmitter>, Pointer<Float>, Pointer<Float>, Pointer<Uint32>, Int32)>(
  symbol: 'fill_vertex_buffer',
  isLeaf: true,
)
external int fillVertexBuffer(
  Pointer<ParticleEmitter> emitter,
  Pointer<Float> matrix,
  Pointer<Float> vertices,
  Pointer<Uint32> colors,
  int maxRenderCount,
);

/// Particle count at or above which the vertex fill runs across the thread
/// pool. Returns the previous threshold. Exposed for benchmarks, so the
/// crossover between the serial and parallel paths can be measured on
/// identical input rather than assumed.
@Native<Int32 Function(Int32)>(symbol: 'set_particle_parallel_threshold', isLeaf: true)
external int setParticleParallelThreshold(int threshold);

/// How many threads a pool dispatch runs across, including the caller.
@Native<Int32 Function()>(symbol: 'particle_pool_concurrency', isLeaf: true)
external int particlePoolConcurrency();

// --- Physics world ---

@Native<Pointer<PhysicsWorld> Function(Int32)>(symbol: 'create_physics_world')
external Pointer<PhysicsWorld> createPhysicsWorld(int maxBodies);

@Native<Void Function(Pointer<PhysicsWorld>)>(symbol: 'destroy_physics_world')
external void destroyPhysicsWorld(Pointer<PhysicsWorld> world);

@Native<Void Function(Pointer<PhysicsWorld>, Float)>(symbol: 'step_physics', isLeaf: true)
external void stepPhysics(Pointer<PhysicsWorld> world, double dt);

@Native<Int32 Function(Pointer<PhysicsWorld>, Int32, Int32, Float, Float, Float, Float, Float, Uint32, Uint32)>(
  symbol: 'create_body',
  isLeaf: true,
)
external int createBody(
  Pointer<PhysicsWorld> world,
  int type,
  int shapeType,
  double x,
  double y,
  double width,
  double height,
  double rotation,
  int categoryBits,
  int maskBits,
);

@Native<Void Function(Pointer<PhysicsWorld>, Int32, Float, Float)>(symbol: 'apply_force', isLeaf: true)
external void applyForce(Pointer<PhysicsWorld> world, int bodyId, double fx, double fy);

@Native<Void Function(Pointer<PhysicsWorld>, Int32, Float)>(symbol: 'apply_torque', isLeaf: true)
external void applyTorque(Pointer<PhysicsWorld> world, int bodyId, double torque);

@Native<Void Function(Pointer<PhysicsWorld>, Int32, Float, Float)>(symbol: 'set_body_velocity', isLeaf: true)
external void setBodyVelocity(Pointer<PhysicsWorld> world, int bodyId, double vx, double vy);

@Native<Void Function(Pointer<PhysicsWorld>, Int32, Pointer<Float>, Pointer<Float>)>(
  symbol: 'get_body_position',
  isLeaf: true,
)
external void getBodyPosition(Pointer<PhysicsWorld> world, int bodyId, Pointer<Float> outX, Pointer<Float> outY);

@Native<RayCastHit Function(Pointer<PhysicsWorld>, Float, Float, Float, Float)>(symbol: 'ray_cast')
external RayCastHit rayCast(Pointer<PhysicsWorld> world, double startX, double startY, double endX, double endY);

// --- Soft bodies ---

@Native<Int32 Function(Pointer<PhysicsWorld>, Int32, Pointer<Float>, Pointer<Float>, Float, Float)>(
  symbol: 'create_soft_body',
)
external int createSoftBody(
  Pointer<PhysicsWorld> world,
  int pointCount,
  Pointer<Float> initialX,
  Pointer<Float> initialY,
  double pressure,
  double stiffness,
);

@Native<Void Function(Pointer<PhysicsWorld>, Int32, Int32, Pointer<Float>, Pointer<Float>)>(
  symbol: 'get_soft_body_point',
  isLeaf: true,
)
external void getSoftBodyPoint(
  Pointer<PhysicsWorld> world,
  int softBodyId,
  int pointIndex,
  Pointer<Float> outX,
  Pointer<Float> outY,
);

/// Reads every point of a soft body in one crossing.
@Native<Int32 Function(Pointer<PhysicsWorld>, Int32, Pointer<Float>, Pointer<Float>, Int32)>(
  symbol: 'get_soft_body_points',
  isLeaf: true,
)
external int getSoftBodyPoints(
  Pointer<PhysicsWorld> world,
  int softBodyId,
  Pointer<Float> outX,
  Pointer<Float> outY,
  int maxPoints,
);

@Native<Void Function(Pointer<PhysicsWorld>, Int32, Int32, Float, Float)>(symbol: 'set_soft_body_point', isLeaf: true)
external void setSoftBodyPoint(Pointer<PhysicsWorld> world, int softBodyId, int pointIndex, double x, double y);

@Native<Void Function(Pointer<PhysicsWorld>, Int32, Float, Float)>(symbol: 'set_soft_body_params', isLeaf: true)
external void setSoftBodyParams(Pointer<PhysicsWorld> world, int softBodyId, double pressure, double stiffness);

// --- Joints ---

@Native<Int32 Function(Pointer<PhysicsWorld>, Pointer<JointDef>)>(symbol: 'create_joint')
external int createJoint(Pointer<PhysicsWorld> world, Pointer<JointDef> def);

@Native<Void Function(Pointer<PhysicsWorld>, Int32)>(symbol: 'destroy_joint')
external void destroyJoint(Pointer<PhysicsWorld> world, int jointId);

// --- Native scene graph ---

@Native<Pointer<NativeScene> Function(Int32)>(symbol: 'create_native_scene')
external Pointer<NativeScene> createNativeScene(int maxNodes);

@Native<Void Function(Pointer<NativeScene>)>(symbol: 'destroy_native_scene')
external void destroyNativeScene(Pointer<NativeScene> scene);

@Native<Int32 Function(Pointer<NativeScene>, Int32)>(symbol: 'create_native_node', isLeaf: true)
external int createNativeNode(Pointer<NativeScene> scene, int parentId);

@Native<Void Function(Pointer<NativeScene>, Int32)>(symbol: 'destroy_native_node', isLeaf: true)
external void destroyNativeNode(Pointer<NativeScene> scene, int nodeId);

@Native<Void Function(Pointer<NativeScene>)>(symbol: 'update_scene_transforms', isLeaf: true)
external void updateSceneTransforms(Pointer<NativeScene> scene);

// ---------------------------------------------------------------------------
// ABI introspection (test support)
// ---------------------------------------------------------------------------

/// Size in bytes of a native struct, by id. See `src/native/abi_probe.cpp`.
@Native<Int32 Function(Int32)>(symbol: 'get_struct_size', isLeaf: true)
external int getStructSize(int structId);

/// Byte offset of a native struct field, by id. See `src/native/abi_probe.cpp`.
@Native<Int32 Function(Int32)>(symbol: 'get_field_offset', isLeaf: true)
external int getFieldOffset(int fieldId);
