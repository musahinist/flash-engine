#ifndef FLASH_PHYSICS_H
#define FLASH_PHYSICS_H

#include <stdint.h>
#include <vector>
#include "flash_export.h"

// Bumped whenever the exported C ABI changes (struct layout, signatures).
// Dart mirrors this in FlashNative and checks it at load time.
#define FLASH_ABI_VERSION 1

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

struct SoftBodyPoint {
    float x, y;
    float oldX, oldY;
    float vx, vy;
    float ax, ay;
    float mass;
    float invMass;
};

struct SoftBodyConstraint {
    int p1, p2;
    float restLength;
    float stiffness;
};

struct NativeSoftBody {
    uint32_t id;
    SoftBodyPoint* points;
    int pointCount;
    SoftBodyConstraint* constraints;
    int constraintCount;
    float pressure;
    float targetArea;
    float friction;
    float restitution;
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
    int isSensor;        // Set by create_body; the solver does not act on it yet
    int isBullet;        // Reserved for CCD, which is not implemented
    int collision_count;
    float sleepTime;     // Time body has been at rest
    uint32_t categoryBits;
    uint32_t maskBits;
    int32_t proxyId;
    int isAwake;
    int islandId;        // Reserved for island/sleep grouping, not implemented
};

// Manifold for persistent contact tracking (Warm Starting)
struct ContactManifold {
    uint32_t bodyA;
    uint32_t bodyB;
    float normalImpulse;
    float tangentImpulse;
    int active; // Using int for stable FFI alignment
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

    NativeSoftBody* softBodies;
    int maxSoftBodies;
    int activeSoftBodies;
    
    // Broadphase dynamic tree
    struct DynamicTree* tree;
    
    // Native Box2D-style Joints
    struct Joint* boxJoints;
    int maxBoxJoints;
    int activeBoxJoints;

    // Internal cache for warm starting (C++ std::map<uint64_t, ...>*)
    void* warmStartCache;

    // Broadphase pair scratch, owned for the life of the world. This was a
    // new[]/delete[] pair on every step_physics call.
    struct BroadphasePair* pairScratch;
    int maxPairs;
};

FLASH_API PhysicsWorld* create_physics_world(int maxBodies);
FLASH_API void destroy_physics_world(PhysicsWorld* world);
FLASH_API void step_physics(PhysicsWorld* world, float dt);
FLASH_API int32_t create_body(PhysicsWorld* world, int type, int shapeType, float x, float y, float w, float h, float rotation, uint32_t categoryBits, uint32_t maskBits);
FLASH_API int32_t get_physics_version();
FLASH_API void apply_force(PhysicsWorld* world, int32_t bodyId, float fx, float fy);
FLASH_API void apply_torque(PhysicsWorld* world, int32_t bodyId, float torque);
FLASH_API void set_body_velocity(PhysicsWorld* world, int32_t bodyId, float vx, float vy);
FLASH_API void get_body_position(PhysicsWorld* world, int32_t bodyId, float* x, float* y);

// Soft Body functions
FLASH_API int32_t create_soft_body(PhysicsWorld* world, int pointCount, float* initialX, float* initialY, float pressure, float stiffness);
FLASH_API void get_soft_body_point(PhysicsWorld* world, int32_t sbId, int pointIdx, float* x, float* y);

/// Copies every point of a soft body in one call. Reading them one at a time
/// cost an FFI crossing plus two calloc/free pairs *per point, per frame*.
/// Returns the number written.
FLASH_API int32_t get_soft_body_points(PhysicsWorld* world, int32_t sbId, float* outX, float* outY, int32_t maxPoints);
FLASH_API void set_soft_body_point(PhysicsWorld* world, int32_t sbId, int pointIdx, float x, float y);
FLASH_API void set_soft_body_params(PhysicsWorld* world, int32_t sbId, float pressure, float stiffness);

// RayCasting
struct RayCastHit {
    int32_t bodyId;
    float x;
    float y;
    float normalX;
    float normalY;
    float fraction; // 0.0 to 1.0 along the ray
    int hit; // boolean flag
};

FLASH_API RayCastHit ray_cast(PhysicsWorld* world, float startX, float startY, float endX, float endY);

}

#endif
