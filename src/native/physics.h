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

// Softness parameters for spring-damped constraints (Box2D-inspired)
struct Softness {
    float biasRate;      // Bias velocity coefficient
    float massScale;     // Mass scale for soft constraints
    float impulseScale;  // Impulse scale for warm starting
};

// Contact constraint point with accumulated impulses
struct ContactConstraintPoint {
    float anchorAx, anchorAy;  // Contact point relative to body A
    float anchorBx, anchorBy;  // Contact point relative to body B
    float baseSeparation;      // Initial separation distance
    float normalImpulse;       // Accumulated normal impulse
    float tangentImpulse;      // Accumulated tangent impulse
    float normalMass;          // Effective mass in normal direction
    float tangentMass;         // Effective mass in tangent direction
};

// Contact constraint for advanced solver
struct ContactConstraint {
    uint32_t bodyA;
    uint32_t bodyB;
    ContactConstraintPoint points[2];
    float normalX, normalY;    // Contact normal
    float friction;
    float restitution;
    float rollingResistance;
    int pointCount;
    Softness softness;
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
    int isSensor;        // Using int for stable FFI alignment
    int isBullet;        // Enable continuous collision detection
    int collision_count;
    float sleepTime;     // Time body has been at rest
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
    
    // Solver configuration (Box2D-inspired)
    int enableWarmStarting;      // Enable warm starting for faster convergence
    float contactHertz;          // Contact constraint frequency (Hz)
    float contactDampingRatio;   // Contact damping ratio (0-1)
    float restitutionThreshold;  // Minimum velocity for restitution
    float maxLinearVelocity;     // Maximum linear velocity (for stability)
    
    // Internal solver state (keep at end to avoid shifting offsets for Dart FFI)
    ContactManifold* manifolds;
    int maxManifolds;
    int activeManifolds;
    
    ContactConstraint* constraints;
    int maxConstraints;
    int activeConstraints;

    NativeJoint* joints;
    int maxJoints;
    int activeJoints;
    
    // Broadphase spatial grid
    struct SpatialHashGrid* spatialGrid;
    
    // Box2D joints
    struct Joint* boxJoints;
    int maxBoxJoints;
    int activeBoxJoints;
};

PhysicsWorld* create_physics_world(int maxBodies);
void destroy_physics_world(PhysicsWorld* world);
void step_physics(PhysicsWorld* world, float dt);
int32_t create_body(PhysicsWorld* world, int type, int shapeType, float x, float y, float w, float h, float rotation);
void apply_force(PhysicsWorld* world, int32_t bodyId, float fx, float fy);
void apply_torque(PhysicsWorld* world, int32_t bodyId, float torque);
void set_body_velocity(PhysicsWorld* world, int32_t bodyId, float vx, float vy);
void get_body_position(PhysicsWorld* world, int32_t bodyId, float* x, float* y);

}

#endif
