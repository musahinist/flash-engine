import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../graph/node.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../native/particles_ffi.dart';

/// Core physics constants and utilities
class FlashPhysics {
  /// Default conversion factor: 100 pixels = 1 meter
  static double pixelsPerMeter = 100.0;

  /// Standard downward gravity in pixels/s^2 (multiplied by 100)
  static v.Vector2 get standardGravity => v.Vector2(0, -981.0);

  // Shape Types
  static const int circle = 0;
  static const int box = 1;
}

class FlashPhysicsSystem {
  late final Pointer<PhysicsWorld> world;
  final int maxBodies;

  FlashPhysicsSystem({v.Vector2? gravity, this.maxBodies = 1000}) {
    // Ensure native core is initialized before creating the world
    FlashNativeParticles.init();

    final createFunc = FlashNativeParticles.createPhysicsWorld;
    if (createFunc == null) {
      throw StateError('FlashPhysicsSystem: Failed to initialize native physics core.');
    }
    world = createFunc(maxBodies);

    if (gravity != null) {
      world.ref.gravityX = gravity.x;
      world.ref.gravityY = gravity.y;
    }
  }

  void update(double dt) {
    final stepFunc = FlashNativeParticles.stepPhysics;
    if (stepFunc != null) {
      stepFunc(world, dt);
    }
  }

  void dispose() {
    final destroyFunc = FlashNativeParticles.destroyPhysicsWorld;
    if (destroyFunc != null) {
      destroyFunc(world);
    }
  }
}

class FlashPhysicsBody extends FlashNode {
  final Pointer<PhysicsWorld> _world;
  final int bodyId;

  /// Callback when a collision occurs.
  void Function(FlashPhysicsBody)? onCollision;

  /// Callback on every physics update.
  void Function(FlashPhysicsBody)? onUpdate;

  // Temporary buffers to avoid allocation in sync
  static final Pointer<Float> _posX = calloc<Float>();
  static final Pointer<Float> _posY = calloc<Float>();

  FlashPhysicsBody({
    required Pointer<PhysicsWorld> world,
    int type = 2, // DYNAMIC
    int shapeType = FlashPhysics.circle,
    double x = 0,
    double y = 0,
    double width = 50,
    double height = 50,
    double rotation = 0,
    super.name = 'PhysicsBody',
  }) : _world = world,
       bodyId = FlashNativeParticles.createBody!(world, type, shapeType, x, y, width, height, rotation) {
    _syncFromPhysics();
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

  void _syncFromPhysics() {
    FlashNativeParticles.getBodyPosition!(_world, bodyId, _posX, _posY);

    final bodyPtr = _world.ref.bodies.elementAt(bodyId);
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
    for (final layer in layers) mask |= layer;
    return mask;
  }
}
