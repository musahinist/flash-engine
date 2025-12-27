import 'dart:math';
import 'dart:ui';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math_64.dart';
import '../graph/node.dart';
import '../native/particles_ffi.dart';

/// Individual particle data
class FParticle {
  Vector3 position;
  Vector3 velocity;
  double life; // Remaining life (0-1)
  double maxLife; // Initial lifetime in seconds
  double size;
  double rotation;
  double rotationSpeed;
  Color color;
  Color endColor;

  FParticle({
    required this.position,
    required this.velocity,
    required this.maxLife,
    required this.size,
    required this.color,
    Color? endColor,
    this.rotation = 0,
    this.rotationSpeed = 0,
  }) : life = 1.0,
       endColor = endColor ?? color.withValues(alpha: 0);

  /// Current interpolated color based on life
  Color get currentColor {
    return Color.lerp(endColor, color, life) ?? color;
  }

  /// Current size (can shrink over lifetime)
  double get currentSize => size * life;
}

/// Configuration for particle emission
class ParticleEmitterConfig {
  /// Particles emitted per second
  final double emissionRate;

  /// Particle lifetime range (min, max) in seconds
  final double lifetimeMin;
  final double lifetimeMax;

  /// Initial velocity range
  final Vector3 velocityMin;
  final Vector3 velocityMax;

  /// Gravity applied to particles
  final Vector3 gravity;

  /// Size range (min, max)
  final double sizeMin;
  final double sizeMax;

  /// Start and end colors
  final Color startColor;
  final Color endColor;

  /// Spread angle in radians (0 = straight, PI = hemisphere)
  final double spreadAngle;

  /// Whether to emit continuously
  final bool loop;

  /// Maximum particles alive at once
  final int maxParticles;

  /// Rotation speed range (radians/sec)
  final double rotationSpeedMin;
  final double rotationSpeedMax;

  /// Particle shape (0=Quad, 1=Hexagon, 2=Octagon, 3=Round(12))
  final int shapeType;

  ParticleEmitterConfig({
    this.emissionRate = 50,
    this.lifetimeMin = 0.5,
    this.lifetimeMax = 2.0,
    Vector3? velocityMin,
    Vector3? velocityMax,
    Vector3? gravity,
    this.sizeMin = 5,
    this.sizeMax = 15,
    this.startColor = const Color(0xFFFFAA00),
    this.endColor = const Color(0x00FF0000),
    this.spreadAngle = 0.5,
    this.loop = true,
    this.maxParticles = 500,
    this.rotationSpeedMin = 0,
    this.rotationSpeedMax = 0,
    this.shapeType = 0,
  }) : velocityMin = velocityMin ?? Vector3(0, 50, 0),
       velocityMax = velocityMax ?? Vector3(0, 100, 0),
       gravity = gravity ?? Vector3(0, -100, 0);

  /// Fire preset
  static final fire = ParticleEmitterConfig(
    emissionRate: 80,
    lifetimeMin: 0.3,
    lifetimeMax: 1.0,
    velocityMin: Vector3(-20, 80, 0),
    velocityMax: Vector3(20, 150, 0),
    gravity: Vector3(0, 50, 0), // Fire rises
    sizeMin: 8,
    sizeMax: 20,
    startColor: const Color(0xFFFFDD00),
    endColor: const Color(0x00FF4400),
    spreadAngle: 0.3,
    shapeType: 1, // Hexagon
  );

  /// Smoke preset
  static final smoke = ParticleEmitterConfig(
    emissionRate: 30,
    lifetimeMin: 1.0,
    lifetimeMax: 3.0,
    velocityMin: Vector3(-10, 30, 0),
    velocityMax: Vector3(10, 60, 0),
    gravity: Vector3(0, 20, 0),
    sizeMin: 15,
    sizeMax: 40,
    startColor: const Color(0xAA666666),
    endColor: const Color(0x00333333),
    spreadAngle: 0.4,
    shapeType: 3, // Round (12 sides) for soft look
  );

  /// Sparkle preset
  static final sparkle = ParticleEmitterConfig(
    emissionRate: 100,
    lifetimeMin: 0.2,
    lifetimeMax: 0.8,
    velocityMin: Vector3(-100, -100, -50),
    velocityMax: Vector3(100, 100, 50),
    gravity: Vector3(0, 0, 0),
    sizeMin: 2,
    sizeMax: 6,
    startColor: const Color(0xFFFFFFFF),
    endColor: const Color(0x00FFFF00),
    spreadAngle: 3.14,
    rotationSpeedMin: -5,
    rotationSpeedMax: 5,
    shapeType: 4, // Triangle for tiny performance bits
  );

  /// Explosion preset (burst, no loop)
  static final explosion = ParticleEmitterConfig(
    emissionRate: 500, // High burst rate
    lifetimeMin: 0.3,
    lifetimeMax: 1.0,
    velocityMin: Vector3(-200, -200, -100),
    velocityMax: Vector3(200, 200, 100),
    gravity: Vector3(0, -150, 0),
    sizeMin: 5,
    sizeMax: 15,
    startColor: const Color(0xFFFFAA00),
    endColor: const Color(0x00FF0000),
    spreadAngle: 3.14,
    loop: false,
    maxParticles: 200,
    shapeType: 1, // Hexagon
  );

  /// Snow preset
  static final snow = ParticleEmitterConfig(
    emissionRate: 40,
    lifetimeMin: 3.0,
    lifetimeMax: 6.0,
    velocityMin: Vector3(-20, -50, 0),
    velocityMax: Vector3(20, -80, 0),
    gravity: Vector3(0, -10, 0),
    sizeMin: 3,
    sizeMax: 8,
    startColor: const Color(0xFFFFFFFF),
    endColor: const Color(0x00FFFFFF),
    spreadAngle: 0.2,
    rotationSpeedMin: -2,
    rotationSpeedMax: 2,
    shapeType: 2, // Octagon for icy crystals
  );

  /// Rain preset
  static final rain = ParticleEmitterConfig(
    emissionRate: 150,
    lifetimeMin: 0.5,
    lifetimeMax: 1.2,
    velocityMin: Vector3(-10, -400, 0),
    velocityMax: Vector3(10, -500, 0),
    gravity: Vector3(0, -200, 0),
    sizeMin: 2,
    sizeMax: 4,
    startColor: const Color(0xAA88CCFF),
    endColor: const Color(0x0088CCFF),
    spreadAngle: 0.05,
    shapeType: 4, // Triangle (streaks)
  );

  /// Confetti preset (colorful celebration)
  static final confetti = ParticleEmitterConfig(
    emissionRate: 80,
    lifetimeMin: 2.0,
    lifetimeMax: 4.0,
    velocityMin: Vector3(-150, 50, -50),
    velocityMax: Vector3(150, 200, 50),
    gravity: Vector3(0, -80, 0),
    sizeMin: 5,
    sizeMax: 12,
    startColor: const Color(0xFFFF69B4), // Pink
    endColor: const Color(0x00FFD700), // Gold fade
    spreadAngle: 0.8,
    rotationSpeedMin: -8,
    rotationSpeedMax: 8,
    shapeType: 0, // Quad is perfect for paper scraps
  );

  /// Magic/fairy dust preset
  static final magic = ParticleEmitterConfig(
    emissionRate: 60,
    lifetimeMin: 0.5,
    lifetimeMax: 1.5,
    velocityMin: Vector3(-30, 20, -30),
    velocityMax: Vector3(30, 80, 30),
    gravity: Vector3(0, 30, 0), // Floats up
    sizeMin: 3,
    sizeMax: 8,
    startColor: const Color(0xFFAA55FF), // Purple
    endColor: const Color(0x00FF55AA), // Pink fade
    spreadAngle: 1.0,
    rotationSpeedMin: -3,
    rotationSpeedMax: 3,
    shapeType: 2, // Octagon
  );

  /// Bubbles preset
  static final bubbles = ParticleEmitterConfig(
    emissionRate: 20,
    lifetimeMin: 2.0,
    lifetimeMax: 5.0,
    velocityMin: Vector3(-15, 30, -10),
    velocityMax: Vector3(15, 60, 10),
    gravity: Vector3(0, 20, 0), // Floats up
    sizeMin: 8,
    sizeMax: 25,
    startColor: const Color(0x88AADDFF),
    endColor: const Color(0x00FFFFFF),
    spreadAngle: 0.3,
    shapeType: 3, // Round (12 sides) mandatory for bubbles
  );

  /// Dust/debris preset
  static final dust = ParticleEmitterConfig(
    emissionRate: 25,
    lifetimeMin: 1.5,
    lifetimeMax: 3.0,
    velocityMin: Vector3(-50, -20, -30),
    velocityMax: Vector3(50, 30, 30),
    gravity: Vector3(0, -30, 0),
    sizeMin: 2,
    sizeMax: 6,
    startColor: const Color(0xAA886644),
    endColor: const Color(0x00554433),
    spreadAngle: 1.5,
    rotationSpeedMin: -2,
    rotationSpeedMax: 2,
    shapeType: 4, // Triangle
  );

  /// Fireflies preset (glowing dots)
  static final fireflies = ParticleEmitterConfig(
    emissionRate: 15,
    lifetimeMin: 2.0,
    lifetimeMax: 4.0,
    velocityMin: Vector3(-20, -10, -20),
    velocityMax: Vector3(20, 20, 20),
    gravity: Vector3(0, 5, 0),
    sizeMin: 3,
    sizeMax: 6,
    startColor: const Color(0xFFAAFF44),
    endColor: const Color(0x0044FF44),
    spreadAngle: 2.0,
    shapeType: 1, // Hexagon
  );

  /// Meteor/comet trail preset
  static final meteor = ParticleEmitterConfig(
    emissionRate: 120,
    lifetimeMin: 0.2,
    lifetimeMax: 0.5,
    velocityMin: Vector3(-10, -5, -5),
    velocityMax: Vector3(10, 5, 5),
    gravity: Vector3(0, 0, 0),
    sizeMin: 4,
    sizeMax: 12,
    startColor: const Color(0xFFFFCC00),
    endColor: const Color(0x00FF4400),
    spreadAngle: 0.2,
    shapeType: 4, // Triangle
  );

  /// Healing/buff effect preset
  static final heal = ParticleEmitterConfig(
    emissionRate: 40,
    lifetimeMin: 0.8,
    lifetimeMax: 1.5,
    velocityMin: Vector3(-20, 80, -20),
    velocityMax: Vector3(20, 120, 20),
    gravity: Vector3(0, 50, 0),
    sizeMin: 5,
    sizeMax: 12,
    startColor: const Color(0xFF44FF88),
    endColor: const Color(0x0088FF44),
    spreadAngle: 0.5,
    shapeType: 2, // Octagon
  );

  /// Electric/lightning sparks preset
  static final electric = ParticleEmitterConfig(
    emissionRate: 150,
    lifetimeMin: 0.05,
    lifetimeMax: 0.2,
    velocityMin: Vector3(-200, -200, -100),
    velocityMax: Vector3(200, 200, 100),
    gravity: Vector3(0, 0, 0),
    sizeMin: 2,
    sizeMax: 5,
    startColor: const Color(0xFF88DDFF),
    endColor: const Color(0x00FFFFFF),
    spreadAngle: 3.14,
    shapeType: 4, // Triangle
  );

  /// Blood/damage effect preset
  static final blood = ParticleEmitterConfig(
    emissionRate: 80,
    lifetimeMin: 0.3,
    lifetimeMax: 0.8,
    velocityMin: Vector3(-100, 50, -50),
    velocityMax: Vector3(100, 150, 50),
    gravity: Vector3(0, -300, 0),
    sizeMin: 3,
    sizeMax: 8,
    startColor: const Color(0xFFCC0000),
    endColor: const Color(0x00880000),
    spreadAngle: 0.8,
    shapeType: 1, // Hexagon
  );

  /// Lava bubbling effect preset
  static final lava = ParticleEmitterConfig(
    emissionRate: 25,
    lifetimeMin: 0.8,
    lifetimeMax: 2.0,
    velocityMin: Vector3(-15, 30, -15),
    velocityMax: Vector3(15, 80, 15),
    gravity: Vector3(0, -50, 0), // Slow fall back
    sizeMin: 12,
    sizeMax: 30,
    startColor: const Color(0xFFFF4400), // Bright orange
    endColor: const Color(0x00CC2200), // Dark red fade
    spreadAngle: 0.4,
    shapeType: 2, // Octagon
  );

  /// Poison/toxic effect preset
  static final poison = ParticleEmitterConfig(
    emissionRate: 35,
    lifetimeMin: 1.0,
    lifetimeMax: 2.5,
    velocityMin: Vector3(-25, 20, -25),
    velocityMax: Vector3(25, 60, 25),
    gravity: Vector3(0, 15, 0), // Floats up slowly
    sizeMin: 8,
    sizeMax: 18,
    startColor: const Color(0xAA44FF00), // Toxic green
    endColor: const Color(0x00228800),
    spreadAngle: 0.6,
    shapeType: 2, // Octagon
  );

  /// Steam/vapor effect preset
  static final steam = ParticleEmitterConfig(
    emissionRate: 50,
    lifetimeMin: 0.8,
    lifetimeMax: 2.0,
    velocityMin: Vector3(-30, 40, -20),
    velocityMax: Vector3(30, 100, 20),
    gravity: Vector3(0, 30, 0), // Rises
    sizeMin: 15,
    sizeMax: 35,
    startColor: const Color(0x66FFFFFF),
    endColor: const Color(0x00DDDDDD),
    spreadAngle: 0.5,
    shapeType: 3, // Round for gas clouds
  );
}

// ... (FlashParticle class can remain if used for high-level callbacks, but we'll focus on the emitter)

/// Particle emitter node (High Performance Native Version)
class FParticleEmitter extends FNode {
  late final Pointer<ParticleEmitter> _nativeEmitter;
  final int maxParticles;
  final Random _random = Random();

  ParticleEmitterConfig config;
  bool emitting;
  double _emissionAccumulator = 0;

  FParticleEmitter({ParticleEmitterConfig? config, this.emitting = true, super.name = 'ParticleEmitter'})
    : config = config ?? ParticleEmitterConfig(),
      maxParticles = config?.maxParticles ?? 1000 {
    // Ensure native core is initialized
    FlashNativeParticles.init();
    _nativeEmitter = calloc<ParticleEmitter>();

    // Allocate shared memory for particles
    _nativeEmitter.ref.particles = calloc<NativeParticle>(maxParticles);
    _nativeEmitter.ref.maxParticles = maxParticles;
    _nativeEmitter.ref.activeCount = 0;
    _nativeEmitter.ref.shapeType = this.config.shapeType;

    _updateNativeGravity();
  }

  int get shapeType => _nativeEmitter.ref.shapeType;
  set shapeType(int value) => _nativeEmitter.ref.shapeType = value;

  void _updateNativeGravity() {
    _nativeEmitter.ref.gravityX = config.gravity.x;
    _nativeEmitter.ref.gravityY = config.gravity.y;
    _nativeEmitter.ref.gravityZ = config.gravity.z;
  }

  /// Direct access to native particles for the renderer
  Pointer<NativeParticle> get nativeParticles => _nativeEmitter.ref.particles;
  Pointer<ParticleEmitter> get nativeEmitterPointer => _nativeEmitter;
  int get activeCount => _nativeEmitter.ref.activeCount;

  @override
  void update(double dt) {
    super.update(dt);

    // Update native gravity in case it changed
    _updateNativeGravity();

    // 1. Emit new particles
    if (emitting && (config.loop || activeCount == 0)) {
      _emissionAccumulator += dt * config.emissionRate;
      while (_emissionAccumulator >= 1 && activeCount < maxParticles) {
        _spawnParticle();
        _emissionAccumulator -= 1;
      }
    }

    // 2. Call Native C++ update logic
    FlashNativeParticles.updateParticles!(_nativeEmitter, dt);
  }

  void _spawnParticle() {
    final lifetime = _randomRange(config.lifetimeMin, config.lifetimeMax);
    final size = _randomRange(config.sizeMin, config.sizeMax);

    final baseVelocity = Vector3(
      _randomRange(config.velocityMin.x, config.velocityMax.x),
      _randomRange(config.velocityMin.y, config.velocityMax.y),
      _randomRange(config.velocityMin.z, config.velocityMax.z),
    );

    if (config.spreadAngle > 0) {
      final spreadX = _randomRange(-config.spreadAngle, config.spreadAngle);
      final spreadZ = _randomRange(-config.spreadAngle, config.spreadAngle);
      final rotX = Matrix4.rotationX(spreadX);
      final rotZ = Matrix4.rotationZ(spreadZ);
      baseVelocity.applyMatrix4(rotX);
      baseVelocity.applyMatrix4(rotZ);
    }

    // Pass to C++
    FlashNativeParticles.spawnParticle!(
      _nativeEmitter,
      worldPosition.x,
      worldPosition.y,
      worldPosition.z,
      baseVelocity.x,
      baseVelocity.y,
      baseVelocity.z,
      lifetime,
      size,
      config.startColor.value,
    );
  }

  double _randomRange(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  bool _disposed = false;
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // IMPORTANT: Free native memory!
    calloc.free(_nativeEmitter.ref.particles);
    calloc.free(_nativeEmitter);
    super.dispose();
  }
}
