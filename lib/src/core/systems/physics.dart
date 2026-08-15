import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../graph/node.dart';
import '../graph/signal.dart';
import '../native/flash_native_bindings.dart' as native;
import '../native/flash_native_bindings.dart' show NativeBody, RayCastHit;
import '../native/flash_native.dart';
import '../native/physics_ids.dart';

export '../native/physics_ids.dart'; // Export ID types (WorldId, BodyId)

class FPhysicsSystem {
  // Singleton instance of the native physics world
  final WorldId world;
  final v.Vector2 gravity;

  FPhysicsSystem({v.Vector2? gravity})
    : gravity = gravity ?? FPhysics.standardGravity,
      // Safety check for native initialization
      world = _createWorldSafe(2048) {
    // Set gravity on the world struct directly
    world.ref.gravityX = this.gravity.x;
    world.ref.gravityY = this.gravity.y;

    // Stability tuning: 8x sub-stepping lets us run very stiff springs
    // (120Hz) without the bodies sinking into a rigid floor.
    world.ref.contactHertz = 120.0;
    world.ref.positionIterations = 4; // Sufficient with sub-stepping
    world.ref.velocityIterations = 4;
    world.ref.contactDampingRatio = 0.5; // Standard damping
  }

  static WorldId _createWorldSafe(int capacity) {
    // Tier 2: physics cannot be faked. Fail loudly at construction rather than
    // silently not simulating.
    FlashNative.require('Physics');
    return native.createPhysicsWorld(capacity);
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
      native.stepPhysics(world, _fixedDt);
      _accumulator -= _fixedDt;
    }
  }

  void dispose() {
    native.destroyPhysicsWorld(world);
  }

  // --- ID-Based API Wrappers (Static for strict separation) ---

  static BodyId createBody(
    WorldId world,
    int type,
    int shapeType,
    double x,
    double y,
    double width,
    double height,
    double rotation,
    int categoryBits,
    int maskBits,
  ) {
    return native.createBody(
      world,
      type,
      shapeType,
      x,
      y,
      width,
      height,
      rotation,
      categoryBits,
      maskBits,
    );
  }

  static void setBodyVelocity(WorldId world, BodyId bodyId, double vx, double vy) {
    native.setBodyVelocity(world, bodyId, vx, vy);
  }

  static void applyForce(WorldId world, BodyId bodyId, double fx, double fy) {
    native.applyForce(world, bodyId, fx, fy);
  }

  static void applyTorque(WorldId world, BodyId bodyId, double torque) {
    native.applyTorque(world, bodyId, torque);
  }

  /// Position of a body, in world units.
  ///
  /// Read straight from the body struct. There is an FFI entry point for this
  /// (`get_body_position`), but it returns the same two fields that `rotation`
  /// and `collisionCount` are already read from directly — so calling it cost
  /// one crossing per body per frame for nothing.
  static Offset getBodyPosition(WorldId world, BodyId bodyId) {
    final b = _getBodyPtr(world, bodyId).ref;
    return Offset(b.x, b.y);
  }

  // Helper to access body struct safely via ID
  static Pointer<NativeBody> _getBodyPtr(WorldId world, BodyId bodyId) {
    return world.ref.bodies + bodyId;
  }

  static void setRestitution(WorldId world, BodyId bodyId, double value) {
    _getBodyPtr(world, bodyId).ref.restitution = value;
  }

  static double getRestitution(WorldId world, BodyId bodyId) {
    return _getBodyPtr(world, bodyId).ref.restitution;
  }

  static void setFriction(WorldId world, BodyId bodyId, double value) {
    _getBodyPtr(world, bodyId).ref.friction = value;
  }

  static double getFriction(WorldId world, BodyId bodyId) {
    return _getBodyPtr(world, bodyId).ref.friction;
  }

  static double getRotation(WorldId world, BodyId bodyId) {
    return _getBodyPtr(world, bodyId).ref.rotation;
  }

  static int getCollisionCount(WorldId world, BodyId bodyId) {
    return _getBodyPtr(world, bodyId).ref.collisionCount;
  }

  static void setCategoryBits(WorldId world, BodyId bodyId, int bits) {
    _getBodyPtr(world, bodyId).ref.categoryBits = bits;
  }

  static int getCategoryBits(WorldId world, BodyId bodyId) {
    return _getBodyPtr(world, bodyId).ref.categoryBits;
  }

  static void setMaskBits(WorldId world, BodyId bodyId, int bits) {
    _getBodyPtr(world, bodyId).ref.maskBits = bits;
  }

  static int getMaskBits(WorldId world, BodyId bodyId) {
    return _getBodyPtr(world, bodyId).ref.maskBits;
  }

  // --- RayCast ---
  static RayCastHit? rayCast(WorldId world, double fromX, double fromY, double toX, double toY) {
    final result = native.rayCast(world, fromX, fromY, toX, toY);
    if (result.hit != 0) return result;
    return null;
  }

  // --- Soft Body API ---

  /// Creates a soft body from a ring of points.
  static int createSoftBody(WorldId world, List<Offset> points, {double pressure = 1.0, double stiffness = 0.5}) {
    final xs = calloc<Float>(points.length);
    final ys = calloc<Float>(points.length);
    try {
      for (var i = 0; i < points.length; i++) {
        xs[i] = points[i].dx;
        ys[i] = points[i].dy;
      }
      return native.createSoftBody(world, points.length, xs, ys, pressure, stiffness);
    } finally {
      calloc.free(xs);
      calloc.free(ys);
    }
  }

  static void setSoftBodyPoint(WorldId world, int sbId, int pointIdx, double x, double y) {
    native.setSoftBodyPoint(world, sbId, pointIdx, x, y);
  }

  /// Helper to get point position as Offset without manual implementation management
  static Offset getSoftBodyPointPos(WorldId world, int sbId, int pointIdx) {
    final ptrX = calloc<Float>();
    final ptrY = calloc<Float>();

    native.getSoftBodyPoint(world, sbId, pointIdx, ptrX, ptrY);

    final x = ptrX.value;
    final y = ptrY.value;

    calloc.free(ptrX);
    calloc.free(ptrY);

    return Offset(x, y);
  }

  static void setSoftBodyParams(WorldId world, int sbId, double pressure, double stiffness) {
    native.setSoftBodyParams(world, sbId, pressure, stiffness);
  }
}

class FPhysics {
  // Conversion constants
  static const double pixelsToMeters = 1.0 / 50.0;
  static const double metersToPixels = 50.0;
  // FlashPainter uses Y-Up coordinate system (0,0 in center, +Y is Up).
  // So Gravity must be negative to pull things down.
  static final v.Vector2 standardGravity = v.Vector2(0, -9.81 * 100);

  // Body Types
  static const int staticBody = 0;
  static const int kinematicBody = 1;
  static const int dynamicBody = 2;

  // Shapes
  static const int circle = 0;
  static const int box = 1;
}

class FPhysicsBody extends FNode {
  final double width;
  final double height;
  final double rotation;
  Color color;

  // Internal body ID from native physics
  final BodyId bodyId;
  final int shapeType; // Store the shape type for correct rendering
  final WorldId _world;

  // -- Signals --

  /// Emitted when this body collides
  final FSignal<FPhysicsBody> collision = FSignal();

  /// Emitted on every physics update
  final FSignal<FPhysicsBody> physicsProcess = FSignal();

  /// Emitted on the frame this body starts touching something.
  final FSignal<FPhysicsBody> collisionEntered = FSignal();

  /// Emitted on the frame this body stops touching everything.
  final FSignal<FPhysicsBody> collisionExited = FSignal();

  bool _wasColliding = false;

  /// Whether the native solver reported contacts for this body last frame.
  bool get isColliding => _wasColliding;

  // Mutable debug flag
  bool debugDraw;

  FPhysicsBody({
    required WorldId world,
    int type = 2, // DYNAMIC
    this.shapeType = FPhysics.circle,
    double x = 0,
    double y = 0,
    this.width = 50,
    this.height = 50,
    this.rotation = 0,
    super.name = 'PhysicsBody',
    this.color = Colors.white,
    this.debugDraw = false,
    double restitution = 0.5,
    double friction = 0.1,
    int categoryBits = 0x0001,
    int maskBits = 0xFFFF,
  }) : _world = world,
       bodyId = FPhysicsSystem.createBody(
         world,
         type,
         shapeType,
         x,
         y,
         width,
         height,
         rotation,
         categoryBits,
         maskBits,
       ) {
    this.restitution = restitution;
    this.friction = friction;
    _syncFromPhysics();
  }

  /// Get/Set Collision Category Bits
  int get categoryBits => FPhysicsSystem.getCategoryBits(_world, bodyId);
  set categoryBits(int value) => FPhysicsSystem.setCategoryBits(_world, bodyId, value);

  /// Get/Set Collision Mask Bits
  int get maskBits => FPhysicsSystem.getMaskBits(_world, bodyId);
  set maskBits(int value) => FPhysicsSystem.setMaskBits(_world, bodyId, value);

  /// Get/Set Restitution (Bounciness) directly on native body
  double get restitution => FPhysicsSystem.getRestitution(_world, bodyId);
  set restitution(double value) => FPhysicsSystem.setRestitution(_world, bodyId, value);

  /// Get/Set Friction directly on native body
  double get friction => FPhysicsSystem.getFriction(_world, bodyId);
  set friction(double value) => FPhysicsSystem.setFriction(_world, bodyId, value);

  /// Get the native physics world pointer
  WorldId get world => _world;

  @override
  void draw(Canvas canvas) {
    if (!debugDraw) return;

    final paint = Paint()..color = color;

    if (shapeType == FPhysics.circle) {
      canvas.drawCircle(Offset.zero, width / 2, paint);
    } else {
      final visibleRect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
      canvas.drawRect(visibleRect, paint);
    }
  }

  @override
  void process(double dt) {
    _syncFromPhysics();
    physicsProcess.emit(this);
  }

  void setVelocity(double vx, double vy) {
    FPhysicsSystem.setBodyVelocity(_world, bodyId, vx, vy);
  }

  void applyForce(double fx, double fy) {
    FPhysicsSystem.applyForce(_world, bodyId, fx, fy);
  }

  void applyTorque(double torque) {
    FPhysicsSystem.applyTorque(_world, bodyId, torque);
  }

  void _syncFromPhysics() {
    final pos = FPhysicsSystem.getBodyPosition(_world, bodyId);
    final rot = FPhysicsSystem.getRotation(_world, bodyId);

    if (pos.dx.isNaN || pos.dy.isNaN || rot.isNaN) {
      return;
    }

    transform.position = v.Vector3(pos.dx, pos.dy, 0);
    transform.rotation = v.Vector3(0, 0, rot);

    // Contact feedback from the native core. It reports a count, not the
    // counterpart body, so enter/exit are derived from the count going
    // non-zero and back.
    final touching = FPhysicsSystem.getCollisionCount(_world, bodyId) > 0;
    if (touching) {
      collision.emit(this);
      if (!_wasColliding) collisionEntered.emit(this);
    } else if (_wasColliding) {
      collisionExited.emit(this);
    }
    _wasColliding = touching;
  }

  @override
  Rect? get bounds {
    // If shape is circle, we still return a square bounding box for culling.
    return Rect.fromCenter(center: Offset.zero, width: width, height: height);
  }
}

class FSoftBody extends FNode {
  final int id;
  final WorldId world;
  final int pointCount;
  final List<Offset> points;

  FSoftBody({
    required this.world,
    required List<Offset> initialPoints,
    double pressure = 1.0,
    double stiffness = 1.0,
    super.name = 'SoftBody',
  }) : pointCount = initialPoints.length,
       points = List.from(initialPoints),
       id = _createNative(world, initialPoints, pressure, stiffness);

  static int _createNative(WorldId world, List<Offset> initialPoints, double pressure, double stiffness) {
    return FPhysicsSystem.createSoftBody(world, initialPoints, pressure: pressure, stiffness: stiffness);
  }

  void setParams(double pressure, double stiffness) {
    FPhysicsSystem.setSoftBodyParams(world, id, pressure, stiffness);
  }

  @override
  void process(double dt) {
    _syncFromNative();
  }

  /// Scratch buffers for the batch read, sized once per soft body.
  late final Pointer<Float> _pointsX = calloc<Float>(pointCount);
  late final Pointer<Float> _pointsY = calloc<Float>(pointCount);

  void _syncFromNative() {
    // One crossing for the whole body. Reading point by point cost an FFI call
    // plus two calloc/free pairs each — for a 32-point body across four soft
    // bodies that was 128 calls and 512 heap operations every frame.
    final count = native.getSoftBodyPoints(world, id, _pointsX, _pointsY, pointCount);
    for (int i = 0; i < count; i++) {
      points[i] = Offset(_pointsX[i], _pointsY[i]);
    }
  }

  @override
  void dispose() {
    calloc.free(_pointsX);
    calloc.free(_pointsY);
    super.dispose();
  }

  @override
  void draw(Canvas canvas) {
    // Basic debug draw
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();
    }
    canvas.drawPath(path, paint);
  }
}

/// Helper class for defining collision layers (Legacy/UI compatibility)
class FCollisionLayer {
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
