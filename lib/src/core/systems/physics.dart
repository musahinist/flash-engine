import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../graph/node.dart';
import '../native/particles_ffi.dart';
import '../native/physics_joints_ffi.dart';

class FlashPhysicsSystem {
  // Singleton instance of the native physics world
  final Pointer<PhysicsWorld> world;
  final v.Vector2 gravity;

  // Static instance of Joints FFI
  static PhysicsJointsFFI? _jointsFFI;
  static PhysicsJointsFFI? get jointsFFI => _jointsFFI;

  FlashPhysicsSystem({v.Vector2? gravity})
    : gravity = gravity ?? FlashPhysics.standardGravity,
      // Safety check for native initialization
      world = _createWorldSafe(2048) {
    // Set gravity on the world struct directly
    world.ref.gravityX = this.gravity.x;
    world.ref.gravityY = this.gravity.y;

    // OPTIMIZED PARAMETERS for stability (prevent sinking & vibration)
    // 8x Sub-stepping allows us to use very stiff springs (120Hz) stably.
    // This is critical for preventing sinking into the rigid floor.
    world.ref.contactHertz = 120.0;

    // OPTIMIZED PARAMETERS for stability (prevent sinking & vibration)
    world.ref.contactHertz = 120.0; // High stiffness to prevent sinking
    world.ref.positionIterations = 4; // Sufficient with sub-stepping
    world.ref.velocityIterations = 4;
    world.ref.contactDampingRatio = 0.5; // Standard damping

    // Initialize Joints FFI if not already done
    if (_jointsFFI == null && Platform.isMacOS) {
      // Only try loading joints lib on supported platform
      try {
        final lib = PhysicsJointsFFI.loadLibrary();
        _jointsFFI = PhysicsJointsFFI(lib);
      } catch (e) {
        // Failed to load joints library
      }
    }
  }

  static Pointer<PhysicsWorld> _createWorldSafe(int capacity) {
    if (FlashNativeParticles.createPhysicsWorld == null) {
      throw UnsupportedError(
        'Native physics functions not initialized.\n'
        'This usually happens when running on a platform without the native library linked (e.g. iOS Simulator).\n'
        '👉 PLEASE RUN ON MACOS DESKTOP: flutter run -d macos',
      );
    }
    return FlashNativeParticles.createPhysicsWorld!(capacity);
  }

  double _accumulator = 0.0;
  static const double _fixedDt = 1.0 / 120.0; // Run physics at 120Hz fixed

  void update(double dt) {
    // Fixed Time Step Loop
    // Accumulate time and step physics in fixed chunks.
    // This prevents instability caused by variable frame times (dt).

    // Clamp dt to avoid spiral of death
    if (dt > 0.25) dt = 0.25;

    _accumulator += dt;

    while (_accumulator >= _fixedDt) {
      FlashNativeParticles.stepPhysics!(world, _fixedDt);
      _accumulator -= _fixedDt;
    }
  }

  void dispose() {
    FlashNativeParticles.destroyPhysicsWorld!(world);
  }

  void setWarmStarting(bool enable) {
    // FlashNativeParticles.setWarmStarting!(world, enable ? 1 : 0);
  }
}

class FlashPhysics {
  // Conversion constants
  static const double pixelsToMeters = 1.0 / 50.0;
  static const double metersToPixels = 50.0;
  // FlashPainter uses Y-Up coordinate system (0,0 in center, +Y is Up).
  // So Gravity must be negative to pull things down.
  static final v.Vector2 standardGravity = v.Vector2(0, -9.8 * 100);

  // Body Types
  static const int staticBody = 0;
  static const int kinematicBody = 1;
  static const int dynamicBody = 2;

  // Shapes
  static const int circle = 0;
  static const int box = 1;
}

class FlashPhysicsBody extends FlashNode {
  final double width;
  final double height;
  final double rotation;
  Color color;

  // Internal body ID from native physics
  final int bodyId;
  final Pointer<PhysicsWorld> _world;

  /// Callback when this body collides
  void Function(FlashPhysicsBody)? onCollision;

  /// Callback on every physics update.
  void Function(FlashPhysicsBody)? onUpdate;

  // Temporary buffers to avoid allocation in sync
  static final Pointer<Float> _posX = calloc<Float>();
  static final Pointer<Float> _posY = calloc<Float>();

  // Mutable debug flag
  bool debugDraw;

  FlashPhysicsBody({
    required Pointer<PhysicsWorld> world,
    int type = 2, // DYNAMIC
    int shapeType = FlashPhysics.circle,
    double x = 0,
    double y = 0,
    this.width = 50,
    this.height = 50,
    this.rotation = 0,
    super.name = 'PhysicsBody',
    this.color = Colors.white,
    this.debugDraw = false,
    double restitution = 0.5, // Increased default bounciness
    double friction = 0.1, // Reduced default friction
  }) : _world = world,
       bodyId = FlashNativeParticles.createBody!(world, type, shapeType, x, y, width, height, rotation) {
    // Set initial material properties via FFI
    this.restitution = restitution;
    this.friction = friction;
    _syncFromPhysics();
  }

  /// Get/Set Restitution (Bounciness) directly on native body
  double get restitution => _world.ref.bodies[bodyId].restitution;
  set restitution(double value) => _world.ref.bodies[bodyId].restitution = value;

  /// Get/Set Friction directly on native body
  double get friction => _world.ref.bodies[bodyId].friction;
  set friction(double value) => _world.ref.bodies[bodyId].friction = value;

  /// Get the native physics world pointer
  Pointer<PhysicsWorld> get world => _world;

  @override
  void draw(Canvas canvas) {
    if (!debugDraw) return;

    final paint = Paint()..color = color;

    // Detect shape from dimensions heuristic since we don't store shapeType yet.
    // In our demo:
    // - Balls are circles (width=height)
    // - Anchors are circles (width=height)
    // - Rope segments are squares (width=height)
    // - Ground is a box (width!=height)

    final isCircle =
        (width == height) &&
        (name.toLowerCase().contains('ball') ||
            name.toLowerCase().contains('circle') ||
            name.toLowerCase().contains('anchor') ||
            name.toLowerCase().contains('pendulum'));

    if (isCircle) {
      canvas.drawCircle(Offset.zero, width / 2, paint);
    } else {
      final visibleRect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
      canvas.drawRect(visibleRect, paint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncFromPhysics();
    onUpdate?.call(this);
  }

  void setVelocity(double vx, double vy) {
    FlashNativeParticles.setBodyVelocity!(_world, bodyId, vx, vy);
  }

  void applyForce(double fx, double fy) {
    FlashNativeParticles.applyForce!(_world, bodyId, fx, fy);
  }

  void applyTorque(double torque) {
    FlashNativeParticles.applyTorque!(_world, bodyId, torque);
  }

  /// Enable continuous collision detection for fast-moving bodies
  void setBullet(bool isBullet) {
    // FIX: Replaced elementAt with pointer arithmetic + to fix deprecation warning
    final bodyPtr = _world.ref.bodies + bodyId;
    bodyPtr.ref.isBullet = isBullet ? 1 : 0;
  }

  void _syncFromPhysics() {
    FlashNativeParticles.getBodyPosition!(_world, bodyId, _posX, _posY);

    // FIX: Replaced elementAt with pointer arithmetic + to fix deprecation warning
    final bodyPtr = _world.ref.bodies + bodyId;
    transform.position = v.Vector3(_posX.value, _posY.value, 0);
    transform.rotation = v.Vector3(0, 0, bodyPtr.ref.rotation);

    // Check for collisions (feedback from native core)
    if (bodyPtr.ref.collisionCount > 0) {
      onCollision?.call(this);
    }
  }
}

/// Helper class for defining collision layers (Legacy/UI compatibility)
class FlashCollisionLayer {
  static const int none = 0x0000;
  static const int all = 0xFFFF;
  static int maskOf(List<int> layers) {
    int mask = 0;
    for (final layer in layers) {
      mask |= (1 << layer);
    }
    return mask;
  }
}
