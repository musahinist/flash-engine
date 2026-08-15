import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/native/flash_native_bindings.dart' as native;
import 'package:vector_math/vector_math_64.dart' as v;

/// Emission moved from one FFI call per particle to one call per burst, with
/// the randomisation and spread rotation done natively.
///
/// The old path did, per particle: five or six `Random` calls, a `Vector3`, two
/// `Matrix4.rotation*` constructions, and a ten-argument FFI call. At the
/// engine's stated 1M-particle target that is roughly 500,000 crossings and two
/// million allocations a second — no amount of native speed absorbs that.
///
/// The randomness now comes from a native xorshift rather than Dart's `Random`,
/// so exact particle positions differ from before. What has to hold is that
/// every value stays inside the configured range.
void main() {
  /// Reads a particle straight out of the native buffer.
  ({double vx, double vy, double vz, double maxLife, double size, int color}) particleAt(
    FParticleEmitter emitter,
    int index,
  ) {
    final base = emitter.nativeParticles;
    final p = Pointer<native.NativeParticle>.fromAddress(
      base.address + index * sizeOf<native.NativeParticle>(),
    ).ref;
    return (vx: p.vx, vy: p.vy, vz: p.vz, maxLife: p.maxLife, size: p.size, color: p.color);
  }

  test('a burst fills the buffer in a single call', () {
    final emitter = FParticleEmitter(
      config: ParticleEmitterConfig(emissionRate: 6000, maxParticles: 100),
    );
    addTearDown(emitter.dispose);

    // 6000/s at 1/60 s is 100 particles — the whole buffer, in one crossing.
    emitter.process(1 / 60);
    expect(emitter.activeCount, 100);
  });

  test('emitted values stay inside the configured ranges', () {
    final config = ParticleEmitterConfig(
      emissionRate: 3000,
      maxParticles: 500,
      lifetimeMin: 1.5,
      lifetimeMax: 2.5,
      sizeMin: 4,
      sizeMax: 9,
      velocityMin: v.Vector3(-10, 20, -5),
      velocityMax: v.Vector3(10, 40, 5),
      spreadAngle: 0, // no rotation, so velocities must land in the raw box
      // process() integrates a frame straight after emitting, so gravity is
      // zeroed here to keep the assertion about emission alone.
      gravity: v.Vector3.zero(),
      startColor: const Color(0xFF123456),
    );
    final emitter = FParticleEmitter(config: config);
    addTearDown(emitter.dispose);

    emitter.process(1 / 60);
    expect(emitter.activeCount, greaterThan(0));

    for (int i = 0; i < emitter.activeCount; i++) {
      final p = particleAt(emitter, i);
      expect(p.maxLife, inInclusiveRange(1.5, 2.5), reason: 'lifetime out of range at $i');
      expect(p.size, inInclusiveRange(4, 9), reason: 'size out of range at $i');
      expect(p.vx, inInclusiveRange(-10, 10), reason: 'vx out of range at $i');
      expect(p.vy, inInclusiveRange(20, 40), reason: 'vy out of range at $i');
      expect(p.vz, inInclusiveRange(-5, 5), reason: 'vz out of range at $i');
      expect(p.color, 0xFF123456);
    }
  });

  test('values actually vary — the burst is not one particle repeated', () {
    final emitter = FParticleEmitter(
      config: ParticleEmitterConfig(
        emissionRate: 3000,
        maxParticles: 200,
        sizeMin: 1,
        sizeMax: 50,
      ),
    );
    addTearDown(emitter.dispose);

    emitter.process(1 / 60);
    final sizes = {for (int i = 0; i < emitter.activeCount; i++) particleAt(emitter, i).size};
    expect(sizes.length, greaterThan(10), reason: 'sizes barely varied: $sizes');
  });

  test('spread rotation keeps speed but changes direction', () {
    // The rotation should redistribute velocity, not inflate it.
    final base = v.Vector3(0, 100, 0);
    final emitter = FParticleEmitter(
      config: ParticleEmitterConfig(
        emissionRate: 3000,
        maxParticles: 300,
        velocityMin: base,
        velocityMax: base,
        spreadAngle: 0.6,
        gravity: v.Vector3.zero(),
      ),
    );
    addTearDown(emitter.dispose);

    emitter.process(1 / 60);
    var anyDeflected = false;
    for (int i = 0; i < emitter.activeCount; i++) {
      final p = particleAt(emitter, i);
      final speed = v.Vector3(p.vx, p.vy, p.vz).length;
      expect(speed, closeTo(100, 0.5), reason: 'rotation changed speed at $i');
      if (p.vx.abs() > 1 || p.vz.abs() > 1) anyDeflected = true;
    }
    expect(anyDeflected, isTrue, reason: 'spreadAngle had no effect');
  });

  test('emission stops at capacity instead of spinning', () {
    // The accumulator used to keep growing while the buffer was full, so the
    // next frame with room would dump an unbounded backlog.
    final emitter = FParticleEmitter(
      config: ParticleEmitterConfig(emissionRate: 100000, maxParticles: 50),
    );
    addTearDown(emitter.dispose);

    for (int i = 0; i < 10; i++) {
      emitter.process(1 / 60);
    }
    expect(emitter.activeCount, 50);
  });

  test('the native emit call is bounded by the buffer', () {
    final emitter = FParticleEmitter(config: ParticleEmitterConfig(maxParticles: 10));
    addTearDown(emitter.dispose);

    final params = emitter.debugEmitParams;
    final spawned = native.emitParticles(emitter.nativeEmitterPointer, params, 1000, 42);
    expect(spawned, 10, reason: 'emit_particles overran the buffer');
    expect(emitter.activeCount, 10);
  });
}
