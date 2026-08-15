import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:flash/src/core/native/flash_native.dart';
import 'package:flash/src/core/native/flash_native_bindings.dart';

/// Guards the Dart <-> C++ struct layouts against silent drift.
///
/// The bindings mirror the C++ structs field by field and read them through
/// raw pointers. Add, reorder or resize a field on one side only and nothing
/// fails to compile — Dart simply reads the wrong bytes, and the symptom
/// surfaces somewhere unrelated: a body at the wrong position, a garbage
/// world matrix, a collision count that is really a category bitmask.
///
/// `PhysicsWorld` is the sharpest edge. The Dart mirror deliberately stops
/// after `activeSoftBodies` and omits the trailing `tree`, `boxJoints`,
/// `maxBoxJoints`, `activeBoxJoints` and `warmStartCache` fields, which is
/// safe *only* because they sit at the end. Insert a field in the middle of
/// the C++ struct and every Dart read past that point is wrong. The offset
/// checks below are what make that loud.
void main() {
  // Keep in sync with FlashStructId in src/native/abi_probe.cpp.
  const structNativeParticle = 0;
  const structParticleEmitter = 1;
  const structNativeTransform = 2;
  const structNativeNode = 3;
  const structNativeScene = 4;
  const structPhysicsWorld = 5;
  const structNativeBody = 6;
  const structRayCastHit = 7;
  const structJointDef = 8;

  // Keep in sync with FlashFieldId in src/native/abi_probe.cpp.
  const fieldBodyX = 0;
  const fieldBodyRotation = 1;
  const fieldBodyCollisionCount = 2;
  const fieldBodyCategoryBits = 3;
  const fieldWorldBodies = 4;
  const fieldWorldGravityX = 5;
  const fieldWorldContactHertz = 6;
  const fieldWorldSoftBodies = 7;
  const fieldNodeWorldMatrix = 8;
  const fieldNodeParentId = 9;
  const fieldNodeAlive = 10;
  const fieldSceneNodes = 11;
  const fieldSceneTotalUpdates = 12;
  const fieldSceneFreeCount = 13;
  const fieldEmitterParticles = 14;
  const fieldEmitterActiveCount = 15;
  const fieldEmitterShapeType = 16;
  const fieldRayHit = 17;

  setUpAll(() {
    expect(
      FlashNative.isAvailable,
      isTrue,
      reason: 'ABI checks need the native core: ${FlashNative.unavailableReason}',
    );
  });

  test('ABI version matches between Dart and C++', () {
    expect(getPhysicsVersion(), kFlashAbiVersion);
  });

  group('struct sizes agree with C++', () {
    void checkSize(String name, int id, int dartSize) {
      test(name, () {
        expect(
          dartSize,
          getStructSize(id),
          reason: '$name is $dartSize bytes in Dart but ${getStructSize(id)} in C++',
        );
      });
    }

    checkSize('NativeParticle', structNativeParticle, sizeOf<NativeParticle>());
    checkSize('ParticleEmitter', structParticleEmitter, sizeOf<ParticleEmitter>());
    checkSize('NativeTransform', structNativeTransform, sizeOf<NativeTransform>());
    checkSize('NativeNode', structNativeNode, sizeOf<NativeNode>());
    checkSize('NativeScene', structNativeScene, sizeOf<NativeScene>());
    checkSize('NativeBody', structNativeBody, sizeOf<NativeBody>());
    checkSize('RayCastHit', structRayCastHit, sizeOf<RayCastHit>());
    checkSize('JointDef', structJointDef, sizeOf<JointDef>());
  });

  test('PhysicsWorld Dart mirror is a prefix of the C++ struct', () {
    // Intentionally smaller: Dart omits the trailing internal solver fields.
    // It must never be larger, and the shared prefix must line up (checked by
    // the offset test below).
    expect(
      sizeOf<PhysicsWorld>(),
      lessThanOrEqualTo(getStructSize(structPhysicsWorld)),
      reason: 'the Dart PhysicsWorld mirror has outgrown the C++ struct',
    );
  });

  group('field offsets agree with C++', () {
    test('NativeBody', () {
      // x is the 4th field: id(4) + type(4) + shapeType(4) = 12
      expect(getFieldOffset(fieldBodyX), 12);
      // rotation follows x and y
      expect(getFieldOffset(fieldBodyRotation), getFieldOffset(fieldBodyX) + 8);
      // These two must not swap: reading one as the other is a classic
      // silent-corruption bug.
      expect(getFieldOffset(fieldBodyCollisionCount), lessThan(getFieldOffset(fieldBodyCategoryBits)));
    });

    test('PhysicsWorld prefix', () {
      expect(getFieldOffset(fieldWorldBodies), 0);
      // gravityX follows bodies(8) + maxBodies(4) + activeCount(4)
      expect(getFieldOffset(fieldWorldGravityX), 16);
      expect(getFieldOffset(fieldWorldContactHertz), greaterThan(getFieldOffset(fieldWorldGravityX)));
      expect(getFieldOffset(fieldWorldSoftBodies), greaterThan(getFieldOffset(fieldWorldContactHertz)));
    });

    test('NativeNode', () {
      // worldMatrix is what FNode reads every frame.
      expect(getFieldOffset(fieldNodeWorldMatrix), greaterThan(0));
      expect(getFieldOffset(fieldNodeParentId), greaterThan(getFieldOffset(fieldNodeWorldMatrix)));
      // alive was appended for the free list; it must stay last.
      expect(getFieldOffset(fieldNodeAlive), greaterThan(getFieldOffset(fieldNodeParentId)));
      expect(getFieldOffset(fieldNodeAlive), lessThan(getStructSize(structNativeNode)));
    });

    test('NativeScene', () {
      expect(getFieldOffset(fieldSceneNodes), 0);
      expect(getFieldOffset(fieldSceneTotalUpdates), greaterThan(0));
      expect(getFieldOffset(fieldSceneFreeCount), greaterThan(getFieldOffset(fieldSceneTotalUpdates)));
    });

    test('ParticleEmitter', () {
      expect(getFieldOffset(fieldEmitterParticles), 0);
      expect(getFieldOffset(fieldEmitterActiveCount), greaterThan(0));
      expect(getFieldOffset(fieldEmitterShapeType), greaterThan(getFieldOffset(fieldEmitterActiveCount)));
    });

    test('RayCastHit', () {
      // `hit` is the flag every raycast call branches on.
      expect(getFieldOffset(fieldRayHit), sizeOf<RayCastHit>() - 4);
    });
  });
}
