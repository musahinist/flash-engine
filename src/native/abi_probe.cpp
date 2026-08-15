// ABI introspection for the Dart bindings.
//
// The Dart side mirrors these C++ structs field by field and reads them
// through raw pointers. If a field is added, reordered or resized on one side
// only, nothing fails to compile — Dart just reads the wrong bytes, and the
// symptom shows up somewhere unrelated (a body at the wrong position, a
// garbage matrix). `test/native_abi_test.dart` calls these to catch that.

#include "flash_export.h"
#include "physics.h"
#include "particles.h"
#include "nodes.h"
#include "joints.h"

#include <stddef.h>
#include <stdint.h>

extern "C" {

// Keep in sync with FlashStruct in test/native_abi_test.dart.
enum FlashStructId {
    kStructNativeParticle = 0,
    kStructParticleEmitter = 1,
    kStructNativeTransform = 2,
    kStructNativeNode = 3,
    kStructNativeScene = 4,
    kStructPhysicsWorld = 5,
    kStructNativeBody = 6,
    kStructRayCastHit = 7,
    kStructJointDef = 8,
};

FLASH_API int32_t get_struct_size(int32_t structId) {
    switch (structId) {
        case kStructNativeParticle:  return (int32_t)sizeof(NativeParticle);
        case kStructParticleEmitter: return (int32_t)sizeof(ParticleEmitter);
        case kStructNativeTransform: return (int32_t)sizeof(NativeTransform);
        case kStructNativeNode:      return (int32_t)sizeof(NativeNode);
        case kStructNativeScene:     return (int32_t)sizeof(NativeScene);
        case kStructPhysicsWorld:    return (int32_t)sizeof(PhysicsWorld);
        case kStructNativeBody:      return (int32_t)sizeof(NativeBody);
        case kStructRayCastHit:      return (int32_t)sizeof(RayCastHit);
        case kStructJointDef:        return (int32_t)sizeof(JointDef);
        default:                     return -1;
    }
}

// Offsets of the fields Dart actually reaches into. Sizes alone would miss a
// same-size reordering.
enum FlashFieldId {
    kFieldBodyX = 0,
    kFieldBodyRotation = 1,
    kFieldBodyCollisionCount = 2,
    kFieldBodyCategoryBits = 3,
    kFieldWorldBodies = 4,
    kFieldWorldGravityX = 5,
    kFieldWorldContactHertz = 6,
    kFieldWorldSoftBodies = 7,
    kFieldNodeWorldMatrix = 8,
    kFieldNodeParentId = 9,
    kFieldNodeAlive = 10,
    kFieldSceneNodes = 11,
    kFieldSceneTotalUpdates = 12,
    kFieldSceneFreeCount = 13,
    kFieldEmitterParticles = 14,
    kFieldEmitterActiveCount = 15,
    kFieldEmitterShapeType = 16,
    kFieldRayHit = 17,
};

FLASH_API int32_t get_field_offset(int32_t fieldId) {
    switch (fieldId) {
        case kFieldBodyX:              return (int32_t)offsetof(NativeBody, x);
        case kFieldBodyRotation:       return (int32_t)offsetof(NativeBody, rotation);
        case kFieldBodyCollisionCount: return (int32_t)offsetof(NativeBody, collision_count);
        case kFieldBodyCategoryBits:   return (int32_t)offsetof(NativeBody, categoryBits);
        case kFieldWorldBodies:        return (int32_t)offsetof(PhysicsWorld, bodies);
        case kFieldWorldGravityX:      return (int32_t)offsetof(PhysicsWorld, gravityX);
        case kFieldWorldContactHertz:  return (int32_t)offsetof(PhysicsWorld, contactHertz);
        case kFieldWorldSoftBodies:    return (int32_t)offsetof(PhysicsWorld, softBodies);
        case kFieldNodeWorldMatrix:    return (int32_t)offsetof(NativeNode, worldMatrix);
        case kFieldNodeParentId:       return (int32_t)offsetof(NativeNode, parentId);
        case kFieldNodeAlive:          return (int32_t)offsetof(NativeNode, alive);
        case kFieldSceneNodes:         return (int32_t)offsetof(NativeScene, nodes);
        case kFieldSceneTotalUpdates:  return (int32_t)offsetof(NativeScene, totalUpdates);
        case kFieldSceneFreeCount:     return (int32_t)offsetof(NativeScene, freeCount);
        case kFieldEmitterParticles:   return (int32_t)offsetof(ParticleEmitter, particles);
        case kFieldEmitterActiveCount: return (int32_t)offsetof(ParticleEmitter, activeCount);
        case kFieldEmitterShapeType:   return (int32_t)offsetof(ParticleEmitter, shapeType);
        case kFieldRayHit:             return (int32_t)offsetof(RayCastHit, hit);
        default:                       return -1;
    }
}

}
