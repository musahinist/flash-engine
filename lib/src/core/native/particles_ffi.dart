import 'dart:ffi';
import 'dart:io';

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

  // Note: Internal solver state (manifolds, constraints, joints) are pointers
  // managed by C++ and not directly accessed from Dart
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
  external int isSensor;
  @Int32()
  external int isBullet; // Enable continuous collision detection
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
  @Int32()
  external int islandId;
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

// Typedefs for the C functions
typedef UpdateParticlesC = Void Function(Pointer<ParticleEmitter> emitter, Float dt);
typedef UpdateParticlesDart = void Function(Pointer<ParticleEmitter> emitter, double dt);

typedef SpawnParticleC =
    Void Function(
      Pointer<ParticleEmitter> emitter,
      Float x,
      Float y,
      Float z,
      Float vx,
      Float vy,
      Float vz,
      Float maxLife,
      Float size,
      Uint32 color,
    );
typedef SpawnParticleDart =
    void Function(
      Pointer<ParticleEmitter> emitter,
      double x,
      double y,
      double z,
      double vx,
      double vy,
      double vz,
      double maxLife,
      double size,
      int color,
    );

typedef FillVertexBufferC =
    Int32 Function(
      Pointer<ParticleEmitter> emitter,
      Pointer<Float> matrix,
      Pointer<Float> vertices,
      Pointer<Uint32> colors,
      Int32 maxRenderCount,
    );
typedef FillVertexBufferDart =
    int Function(
      Pointer<ParticleEmitter> emitter,
      Pointer<Float> matrix,
      Pointer<Float> vertices,
      Pointer<Uint32> colors,
      int maxRenderCount,
    );

class FlashNativeParticles {
  static DynamicLibrary? _lib;

  // Particle Functions
  static void Function(Pointer<ParticleEmitter>, double)? updateParticles;
  static void Function(Pointer<ParticleEmitter>, double, double, double, double, double, double, double, double, int)?
  spawnParticle;
  static int Function(Pointer<ParticleEmitter>, Pointer<Float>, Pointer<Float>, Pointer<Uint32>, int)? fillVertexBuffer;

  // Physics Functions
  static Pointer<PhysicsWorld> Function(int)? createPhysicsWorld;
  static void Function(Pointer<PhysicsWorld>)? destroyPhysicsWorld;
  static void Function(Pointer<PhysicsWorld>, double)? stepPhysics;
  static int Function(Pointer<PhysicsWorld>, int, int, double, double, double, double, double, int, int)? createBody;
  static void Function(Pointer<PhysicsWorld>, int, double, double)? applyForce;
  static void Function(Pointer<PhysicsWorld>, int, double)? applyTorque;
  static void Function(Pointer<PhysicsWorld>, int, double, double)? setBodyVelocity;
  static void Function(Pointer<PhysicsWorld>, int, Pointer<Float>, Pointer<Float>)? getBodyPosition;

  // RayCast
  static RayCastHit Function(Pointer<PhysicsWorld>, double, double, double, double)? rayCast;

  static const String _libName = 'libflash_core.dylib';

  static void init() {
    if (_lib != null) return;

    // Determine library path
    // iOS Simulator support: Load the custom-built simulator dylib via absolute path
    if (Platform.isIOS) {
      // Note: This relies on the Simulator having access to the host filesystem (Debug mode)
      final simLibPath = '/Users/mshn/Documents/flash/lib/src/core/native/bin/libflash_core_sim.dylib';
      _lib = DynamicLibrary.open(simLibPath);
    } else {
      String libPath;
      if (Platform.isMacOS) {
        libPath = '/Users/mshn/Documents/flash/lib/src/core/native/bin/$_libName';
      } else if (Platform.isLinux || Platform.isAndroid) {
        libPath = '/Users/mshn/Documents/flash/lib/src/core/native/bin/user/libflash_core.so';
      } else if (Platform.isWindows) {
        libPath = 'C:\\Users\\mshn\\Documents\\flash\\lib\\src\\core\\native\\bin\\libflash_core.dll';
      } else {
        throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
      }
      _lib = DynamicLibrary.open(libPath);
    }

    // Particle Lookups
    updateParticles = _lib!.lookupFunction<UpdateParticlesC, UpdateParticlesDart>('update_particles');
    spawnParticle = _lib!.lookupFunction<SpawnParticleC, SpawnParticleDart>('spawn_particle');
    fillVertexBuffer = _lib!.lookupFunction<FillVertexBufferC, FillVertexBufferDart>('fill_vertex_buffer');

    // Physics Lookups
    createPhysicsWorld = _lib!
        .lookupFunction<Pointer<PhysicsWorld> Function(Int32), Pointer<PhysicsWorld> Function(int)>(
          'create_physics_world',
        );
    destroyPhysicsWorld = _lib!
        .lookupFunction<Void Function(Pointer<PhysicsWorld>), void Function(Pointer<PhysicsWorld>)>(
          'destroy_physics_world',
        );
    stepPhysics = _lib!
        .lookupFunction<Void Function(Pointer<PhysicsWorld>, Float), void Function(Pointer<PhysicsWorld>, double)>(
          'step_physics',
        );
    createBody = _lib!
        .lookupFunction<
          Int32 Function(Pointer<PhysicsWorld>, Int32, Int32, Float, Float, Float, Float, Float, Uint32, Uint32),
          int Function(Pointer<PhysicsWorld>, int, int, double, double, double, double, double, int, int)
        >('create_body');
    applyForce = _lib!
        .lookupFunction<
          Void Function(Pointer<PhysicsWorld>, Int32, Float, Float),
          void Function(Pointer<PhysicsWorld>, int, double, double)
        >('apply_force');
    applyTorque = _lib!
        .lookupFunction<
          Void Function(Pointer<PhysicsWorld>, Int32, Float),
          void Function(Pointer<PhysicsWorld>, int, double)
        >('apply_torque');
    setBodyVelocity = _lib!
        .lookupFunction<
          Void Function(Pointer<PhysicsWorld>, Int32, Float, Float),
          void Function(Pointer<PhysicsWorld>, int, double, double)
        >('set_body_velocity');
    getBodyPosition = _lib!
        .lookupFunction<
          Void Function(Pointer<PhysicsWorld>, Int32, Pointer<Float>, Pointer<Float>),
          void Function(Pointer<PhysicsWorld>, int, Pointer<Float>, Pointer<Float>)
        >('get_body_position');

    // RayCast Binding
    rayCast = _lib!
        .lookupFunction<
          RayCastHit Function(Pointer<PhysicsWorld>, Float, Float, Float, Float),
          RayCastHit Function(Pointer<PhysicsWorld>, double, double, double, double)
        >('ray_cast');

    print('Native Core Library loaded successfully');
  }
}
