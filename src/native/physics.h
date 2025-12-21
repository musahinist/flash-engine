#ifndef FLASH_PHYSICS_H
#define FLASH_PHYSICS_H

#include <stdint.h>
#include <vector>

extern "C" {

enum BodyType {
    STATIC = 0,
    KINEMATIC = 1,
    DYNAMIC = 2
};

enum ShapeType {
    SHAPE_CIRCLE = 0,
    SHAPE_BOX = 1
};

struct NativeBody {
    uint32_t id;
    int type;
    int shapeType;
    float x, y, rotation;
    float vx, vy, angularVelocity;
    float forceX, forceY, torque;
    float mass, inverseMass;
    float inertia, inverseInertia;
    float restitution;
    float friction;
    float width, height, radius;
    int isSensor; // Using int for stable FFI alignment
    int collision_count;
};

// Manifold for persistent contact tracking (Warm Starting)
struct ContactManifold {
    uint32_t bodyA;
    uint32_t bodyB;
    float normalImpulse;
    float tangentImpulse;
    int active; // Using int for stable FFI alignment
};

struct NativeJoint {
    int type; // 0 = Distance Joint
    uint32_t bodyA;
    uint32_t bodyB;
    float targetDistance;
    float impulse;
};

struct PhysicsWorld {
    NativeBody* bodies;
    int maxBodies;
    int activeCount;
    float gravityX, gravityY;
    int velocityIterations;
    int positionIterations;
    
    // Internal solver state (keep at end to avoid shifting offsets for Dart FFI)
    ContactManifold* manifolds;
    int maxManifolds;
    int activeManifolds;

    NativeJoint* joints;
    int maxJoints;
    int activeJoints;
};

PhysicsWorld* create_physics_world(int maxBodies);
void destroy_physics_world(PhysicsWorld* world);
void step_physics(PhysicsWorld* world, float dt);
int32_t create_body(PhysicsWorld* world, int type, int shapeType, float x, float y, float w, float h, float rotation);
void apply_force(PhysicsWorld* world, int32_t bodyId, float fx, float fy);
void apply_torque(PhysicsWorld* world, int32_t bodyId, float torque);
void set_body_velocity(PhysicsWorld* world, int32_t bodyId, float vx, float vy);
void get_body_position(PhysicsWorld* world, int32_t bodyId, float* x, float* y);
int32_t create_joint(PhysicsWorld* world, int type, uint32_t bodyA, uint32_t bodyB, float distance);

}

#endif
