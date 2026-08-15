#include "physics.h"
#include "broadphase.h"
#include "joints.h"
#include <cmath>
#include <cstdlib>
#include <algorithm>
#include <map>
#include <vector>

#define PI 3.14159265359f

struct Vec2 {
    float x, y;
    Vec2 operator+(const Vec2& v) const { return {x + v.x, y + v.y}; }
    Vec2 operator-(const Vec2& v) const { return {x - v.x, y - v.y}; }
    Vec2 operator*(float s) const { return {x * s, y * s}; }
    float dot(const Vec2& v) const { return x * v.x + y * v.y; }
    float cross(const Vec2& v) const { return x * v.y - y * v.x; }
    float lengthSq() const { return x * x + y * y; }
    float length() const { return std::sqrt(lengthSq()); }
};

inline Vec2 cross(Vec2 v, float s) { return {s * v.y, -s * v.x}; }
inline Vec2 cross(float s, Vec2 v) { return {-s * v.y, s * v.x}; }
inline Vec2 rotate(Vec2 v, float angle) {
    float c = std::cos(angle);
    float s = std::sin(angle);
    return { v.x * c - v.y * s, v.x * s + v.y * c };
}

// Internal cache for warm starting
// Key: (minId << 32) | maxId
// Value: Stored impulses for the contact point
struct CachedImpulse {
    float normalImpulse;
    float tangentImpulse;
};
using ImpulseCache = std::map<uint64_t, CachedImpulse>;

// Key layout: [minId:24][maxId:24][pointIndex:8], order-independent in the
// body pair. The previous packing was (minId<<32)|(maxId<<4)|j, whose maxId
// field overlapped minId's bits once maxId reached 2^28 — a silent collision
// that would hand a contact the wrong cached impulse.
static inline uint64_t contact_cache_key(uint32_t bodyA, uint32_t bodyB, int pointIndex) {
    uint64_t lo = std::min(bodyA, bodyB);
    uint64_t hi = std::max(bodyA, bodyB);
    return (lo << 40) | (hi << 8) | (uint64_t)(pointIndex & 0xFF);
}

extern "C" {

FLASH_API PhysicsWorld* create_physics_world(int maxBodies) {
    // Use calloc to ensure all fields are zeroed (prevents uninitialized garbage)
    PhysicsWorld* world = (PhysicsWorld*)calloc(1, sizeof(PhysicsWorld));
    if (!world) return NULL;

    world->bodies = (NativeBody*)calloc(maxBodies, sizeof(NativeBody));
    world->maxBodies = maxBodies;
    world->activeCount = 0;
    
    world->maxManifolds = maxBodies * 2; 
    world->manifolds = (ContactManifold*)calloc(world->maxManifolds, sizeof(ContactManifold));
    world->activeManifolds = 0;
    
    // Initialize contact constraints
    world->maxConstraints = maxBodies * 4;
    world->constraints = (ContactConstraint*)calloc(world->maxConstraints, sizeof(ContactConstraint));
    world->activeConstraints = 0;
    
    world->gravityX = 0;
    world->gravityY = -9.81f * 100.0f;
    
    // Box2D-inspired solver configuration
    world->velocityIterations = 8;
    world->positionIterations = 10;
    world->enableWarmStarting = 1;
    world->contactHertz = 120.0f;
    world->contactDampingRatio = 1.0f;
    world->restitutionThreshold = 1.0f * 100.0f;
    world->maxLinearVelocity = 2000.0f * 100.0f;
    
    // Initialize soft bodies
    world->maxSoftBodies = 64; // Increased capacity
    world->softBodies = (NativeSoftBody*)calloc(world->maxSoftBodies, sizeof(NativeSoftBody));
    world->activeSoftBodies = 0;

    // Create dynamic AABB tree for broadphase
    world->tree = create_dynamic_tree(maxBodies * 2);
    
    // Initialize Box2D joints
    world->maxBoxJoints = 200;
    world->boxJoints = (Joint*)calloc(world->maxBoxJoints, sizeof(Joint));
    world->activeBoxJoints = 0;
    
    return world;
}

FLASH_API void destroy_physics_world(PhysicsWorld* world) {
    if (!world) return;

    // Every block below is allocated with calloc() in create_physics_world /
    // create_soft_body, so it must be released with free(). Mixing the
    // malloc family with delete is undefined behaviour.
    free(world->bodies);
    free(world->manifolds);
    free(world->constraints);
    destroy_dynamic_tree(world->tree);
    free(world->boxJoints);

    for (int i = 0; i < world->activeSoftBodies; ++i) {
        free(world->softBodies[i].points);
        free(world->softBodies[i].constraints);
    }
    free(world->softBodies);

    // The warm-start cache is a real C++ object (new'd std::map), so it is
    // the one allocation here that genuinely needs delete.
    delete static_cast<ImpulseCache*>(world->warmStartCache);

    free(world);
}

struct CollisionManifold {
    Vec2 normal;
    float penetration;
    Vec2 contacts[2];
    int contactCount;
    bool collided;
};

// --- Collision Detection (SAT & Math) ---

CollisionManifold detectCircleCircle(NativeBody& a, NativeBody& b) {
    Vec2 posA = {a.x, a.y};
    Vec2 posB = {b.x, b.y};
    Vec2 d = posB - posA;
    float distSq = d.lengthSq();
    float radiusSum = a.radius + b.radius;

    if (distSq >= radiusSum * radiusSum) return {{0,0}, 0, {{0,0}}, 0, false};

    float dist = std::sqrt(distSq);
    CollisionManifold m;
    m.collided = true;
    m.contactCount = 1;

    if (dist == 0) {
        m.penetration = a.radius;
        m.normal = {0, 1};
        m.contacts[0] = posA;
    } else {
        m.penetration = radiusSum - dist;
        m.normal = d * (1.0f / dist);
        m.contacts[0] = posB - (m.normal * b.radius);
    }
    return m;
}

// Corners and axes of an oriented box, built once per body.
struct BoxFrame {
    Vec2 corners[4];
    Vec2 axisX, axisY;
};

static inline BoxFrame make_box_frame(const NativeBody& body) {
    // One sin/cos for the whole body. The previous version called rotate()
    // — and therefore cos+sin — for all four corners on each of four axes,
    // for both bodies: 64 trig calls per pair where 4 suffice.
    const float c = std::cos(body.rotation);
    const float s = std::sin(body.rotation);
    const float hw = body.width * 0.5f;
    const float hh = body.height * 0.5f;

    BoxFrame f;
    f.axisX = { c, s };
    f.axisY = { -s, c };

    const Vec2 ex = { c * hw,  s * hw };   // half-extent along local X
    const Vec2 ey = { -s * hh, c * hh };   // half-extent along local Y
    const Vec2 pos = { body.x, body.y };

    f.corners[0] = pos - ex - ey;
    f.corners[1] = pos + ex - ey;
    f.corners[2] = pos + ex + ey;
    f.corners[3] = pos - ex + ey;
    return f;
}

static inline void project_frame(const BoxFrame& f, Vec2 axis, float& min, float& max) {
    min = max = axis.dot(f.corners[0]);
    for (int i = 1; i < 4; ++i) {
        const float p = axis.dot(f.corners[i]);
        if (p < min) min = p;
        if (p > max) max = p;
    }
}

CollisionManifold detectBoxBox(NativeBody& a, NativeBody& b) {
    const BoxFrame fa = make_box_frame(a);
    const BoxFrame fb = make_box_frame(b);

    float minOverlap = 1e10f;
    Vec2 bestAxis;
    NativeBody* ref = &a;
    NativeBody* inc = &b;
    const BoxFrame* incFrame = &fb;

    const Vec2 axes[4] = { fa.axisX, fa.axisY, fb.axisX, fb.axisY };

    for (int i = 0; i < 4; ++i) {
        float minA, maxA, minB, maxB;
        project_frame(fa, axes[i], minA, maxA);
        project_frame(fb, axes[i], minB, maxB);

        float overlap = std::min(maxA, maxB) - std::max(minA, minB);
        if (overlap <= 0) return {{0,0}, 0, {{0,0}}, 0, false};

        if (overlap < minOverlap) {
            minOverlap = overlap;
            bestAxis = axes[i];
            if (i < 2) { ref = &a; inc = &b; incFrame = &fb; }
            else       { ref = &b; inc = &a; incFrame = &fa; }
        }
    }

    Vec2 d = {b.x - a.x, b.y - a.y};
    if (bestAxis.dot(d) < 0) bestAxis = bestAxis * -1.0f;

    CollisionManifold m;
    m.collided = true;
    m.normal = bestAxis;
    m.penetration = minOverlap;
    m.contactCount = 0;

    // Stable Multi-point Contact: vertices of 'inc' that overlap 'ref' on bestAxis.
    // Corners are reused from the frame built at the top — no more trig here.
    const Vec2* v_inc = incFrame->corners;

    float minA, maxA;
    project_frame(ref == &a ? fa : fb, bestAxis, minA, maxA);

    for (int i = 0; i < 4; ++i) {
        float p = bestAxis.dot(v_inc[i]);
        // If vertex is inside reference body's SAT projection (with slop)
        if (p <= maxA + 0.01f) {
            m.contacts[m.contactCount++] = v_inc[i] + (bestAxis * (minOverlap * 0.5f));
            if (m.contactCount >= 2) break;
        }
    }
    
    if (m.contactCount == 0) {
        // Fallback for safety
        m.contactCount = 1;
        m.contacts[0] = {inc->x, inc->y};
    }
    return m;
}

// Box2D's softness calculation for spring-damped constraints
inline Softness makeSoftness(float hertz, float dampingRatio, float h) {
    if (hertz == 0.0f) {
        return {0.0f, 0.0f, 0.0f};
    }
    
    float omega = 2.0f * PI * hertz;
    float a1 = 2.0f * dampingRatio + h * omega;
    float a2 = h * omega * a1;
    float a3 = 1.0f / (1.0f + a2);
    
    // bias = omega / (2 * zeta + h * omega)
    // massScale = h * omega * (2 * zeta + h * omega) / (1 + h * omega * (2 * zeta + h * omega))
    // impulseScale = 1 / (1 + h * omega * (2 * zeta + h * omega))
    
    Softness soft;
    soft.biasRate = omega / a1;
    soft.massScale = a2 * a3;
    soft.impulseScale = a3;
    return soft;
}

CollisionManifold detectCircleBox(NativeBody& circle, NativeBody& box) {
    Vec2 pc = {circle.x, circle.y};
    Vec2 pb = {box.x, box.y};
    
    Vec2 d = pc - pb;
    Vec2 localD = rotate(d, -box.rotation);

    float hw = box.width * 0.5f;
    float hh = box.height * 0.5f;

    Vec2 closest = { std::max(-hw, std::min(hw, localD.x)), std::max(-hh, std::min(hh, localD.y)) };
    Vec2 localNormal = localD - closest;
    float distSq = localNormal.lengthSq();
    float r = circle.radius;

    if (distSq > r * r && (std::abs(localD.x) > hw || std::abs(localD.y) > hh)) return {{0,0}, 0, {{0,0}}, 0, false};

    float dist = std::sqrt(distSq);
    CollisionManifold m;
    m.collided = true;
    m.contactCount = 1;
    
    if (dist > 0.0001f) {
        m.normal = rotate(localNormal, box.rotation) * (1.0f / dist);
    } else {
        float dx = hw - std::abs(localD.x);
        float dy = hh - std::abs(localD.y);
        if (dx < dy) {
            m.normal = rotate({(localD.x > 0) ? 1.0f : -1.0f, 0}, box.rotation);
            dist = -dx;
        } else {
            m.normal = rotate({0, (localD.y > 0) ? 1.0f : -1.0f}, box.rotation);
            dist = -dy;
        }
    }
    
    m.penetration = r - dist;
    m.contacts[0] = pb + rotate(closest, box.rotation);
    return m;
}

// --- Solver ---

void step_soft_body(PhysicsWorld* world, float dt);

FLASH_API void step_physics(PhysicsWorld* world, float dt) {
    if (!world || dt <= 0) return;

    // Step Soft Bodies
    step_soft_body(world, dt);

    if (world->activeCount == 0) return;

    // Phase 1: Update Broadphase Tree
    for (int i = 0; i < world->activeCount; ++i) {
        NativeBody& b = world->bodies[i];
        b.collision_count = 0;
        if (b.type == STATIC) continue;
        
        AABB aabb = calculate_body_aabb(b);
        // Important: Update proxyId as tree_insert_leaf returns a new ID
        b.proxyId = tree_update_leaf(world->tree, b.proxyId, aabb);
    }

    world->activeConstraints = 0;
    const int maxPairs = world->maxBodies * 8; // Increased for complex scenes
    BroadphasePair* pairs = new BroadphasePair[maxPairs];
    int pairCount = query_tree_pairs(world->tree, pairs, maxPairs);

    Softness contactSoftness = makeSoftness(world->contactHertz, world->contactDampingRatio, dt);

    for (int p = 0; p < pairCount && world->activeConstraints < world->maxConstraints; ++p) {
        int i = pairs[p].bodyA;
        int j = pairs[p].bodyB;
        
        NativeBody& a = world->bodies[i];
        NativeBody& b = world->bodies[j];
        if (a.type == STATIC && b.type == STATIC) continue;
        if (!((a.maskBits & b.categoryBits) != 0 && (b.maskBits & a.categoryBits) != 0)) continue;

        CollisionManifold m = {{0,0}, 0, {{0,0}}, 0, false};
        if (a.shapeType == SHAPE_CIRCLE && b.shapeType == SHAPE_CIRCLE) m = detectCircleCircle(a, b);
        else if (a.shapeType == SHAPE_BOX && b.shapeType == SHAPE_BOX) m = detectBoxBox(a, b);
        else if (a.shapeType == SHAPE_CIRCLE) m = detectCircleBox(a, b);
        else { m = detectCircleBox(b, a); }

        if (!m.collided) continue;
        if (a.shapeType == SHAPE_CIRCLE && b.shapeType == SHAPE_BOX) m.normal = m.normal * -1.0f;

        ContactConstraint& constraint = world->constraints[world->activeConstraints++];
        constraint.bodyA = i;
        constraint.bodyB = j;
        constraint.normalX = m.normal.x;
        constraint.normalY = m.normal.y;
        constraint.friction = std::sqrt(a.friction * b.friction);
        
        // Restitution with threshold
        float relV = (Vec2{b.vx, b.vy} - Vec2{a.vx, a.vy}).dot(m.normal);
        constraint.restitution = (relV < -world->restitutionThreshold) ? std::max(a.restitution, b.restitution) : 0.0f;
        
        constraint.pointCount = m.contactCount;
        constraint.softness = contactSoftness;

        for (int c = 0; c < m.contactCount; ++c) {
            ContactConstraintPoint& cp = constraint.points[c];
            cp.anchorAx = m.contacts[c].x - a.x;
            cp.anchorAy = m.contacts[c].y - a.y;
            cp.anchorBx = m.contacts[c].x - b.x;
            cp.anchorBy = m.contacts[c].y - b.y;
            cp.baseSeparation = -m.penetration;
            
            Vec2 ra = {cp.anchorAx, cp.anchorAy}, rb = {cp.anchorBx, cp.anchorBy}, normal = {m.normal.x, m.normal.y};
            float raN = ra.cross(normal), rbN = rb.cross(normal);
            float kN = a.inverseMass + b.inverseMass + raN * raN * a.inverseInertia + rbN * rbN * b.inverseInertia + contactSoftness.massScale;
            cp.normalMass = kN > 0.0f ? 1.0f / kN : 0.0f;

            Vec2 tangent = {-normal.y, normal.x};
            float raT = ra.cross(tangent), rbT = rb.cross(tangent);
            float kT = a.inverseMass + b.inverseMass + raT * raT * a.inverseInertia + rbT * rbT * b.inverseInertia;
            cp.tangentMass = kT > 0.0f ? 1.0f / kT : 0.0f;
            cp.normalImpulse = cp.tangentImpulse = 0.0f;
        }
        a.collision_count++; b.collision_count++;
    }
    delete[] pairs;

    // Phase 2: Integrate Velocities & Apply Sleep
    for (int i = 0; i < world->activeCount; ++i) {
        NativeBody& b = world->bodies[i];
        if (b.type == STATIC) continue;
        
        // Sleep check
        if (b.vx * b.vx + b.vy * b.vy < 0.2f && std::abs(b.angularVelocity) < 0.2f && 
            b.forceX == 0 && b.forceY == 0 && b.torque == 0) {
            b.sleepTime += dt;
        } else {
            b.sleepTime = 0.0f;
            b.isAwake = 1;
        }

        if (b.sleepTime > 1.0f) {
            b.isAwake = 0;
            b.vx = b.vy = b.angularVelocity = 0;
            continue;
        }

        b.vx += (world->gravityX + b.forceX * b.inverseMass) * dt;
        b.vy += (world->gravityY + b.forceY * b.inverseMass) * dt;
        b.angularVelocity += (b.torque * b.inverseInertia) * dt;
        
        // Damping for stability (Reduced from 0.99 to 0.999 to allow gravity to be snappy)
        b.vx *= 0.999f;
        b.vy *= 0.999f;
        b.angularVelocity *= 0.999f;

        b.forceX = b.forceY = b.torque = 0;
    }

    // Phase 3: Solve Velocity Constraints
    init_joint_velocity_constraints(world, dt);

    ImpulseCache* cache = (ImpulseCache*)world->warmStartCache;
    if (!cache) {
        cache = new ImpulseCache();
        world->warmStartCache = cache;
    }
    
    // warm start
    if (world->enableWarmStarting) {
        for (int i = 0; i < world->activeConstraints; i++) {
             ContactConstraint& c = world->constraints[i];
             NativeBody& a = world->bodies[c.bodyA];
             NativeBody& b = world->bodies[c.bodyB];
             
             for (int j = 0; j < c.pointCount; j++) {
                 ContactConstraintPoint& cp = c.points[j];
                 // Typically manifolds persist but points might shift.
                 // For now, assume point index stability (Box2D style requires feature IDs, we use simple index)
                 uint64_t key = contact_cache_key(c.bodyA, c.bodyB, j);

                 auto it = cache->find(key);
                 if (it != cache->end()) {
                     CachedImpulse& imp = it->second;
                     cp.normalImpulse = imp.normalImpulse;
                     cp.tangentImpulse = imp.tangentImpulse;
                     
                     // Apply cached impulses for warm start
                     Vec2 normal = {c.normalX, c.normalY}, tangent = {-c.normalY, c.normalX};
                     Vec2 ra = {cp.anchorAx, cp.anchorAy}, rb = {cp.anchorBx, cp.anchorBy};
                     
                     Vec2 P = normal * cp.normalImpulse + tangent * cp.tangentImpulse;
                     
                     if (a.type != STATIC) { 
                         a.vx -= P.x * a.inverseMass; 
                         a.vy -= P.y * a.inverseMass; 
                         a.angularVelocity -= ra.cross(P) * a.inverseInertia; 
                     }
                     if (b.type != STATIC) { 
                         b.vx += P.x * b.inverseMass; 
                         b.vy += P.y * b.inverseMass; 
                         b.angularVelocity += rb.cross(P) * b.inverseInertia; 
                     }
                 } else {
                     cp.normalImpulse = 0.0f;
                     cp.tangentImpulse = 0.0f;
                 }
             }
        }
    }
    
    for (int iter = 0; iter < world->velocityIterations; ++iter) {
        for (int i = 0; i < world->activeConstraints; ++i) {
            ContactConstraint& c = world->constraints[i];
            NativeBody& a = world->bodies[c.bodyA], &b = world->bodies[c.bodyB];
            if (!a.isAwake && !b.isAwake) continue;

            // Simple Wake-up
            a.isAwake = b.isAwake = 1;
            a.sleepTime = b.sleepTime = 0;

            Vec2 normal = {c.normalX, c.normalY}, tangent = {-c.normalY, c.normalX};
            for (int j = 0; j < c.pointCount; ++j) {
                ContactConstraintPoint& cp = c.points[j];
                Vec2 ra = {cp.anchorAx, cp.anchorAy}, rb = {cp.anchorBx, cp.anchorBy};
                Vec2 dv = (Vec2{b.vx, b.vy} + cross(b.angularVelocity, rb)) - (Vec2{a.vx, a.vy} + cross(a.angularVelocity, ra));
                
                // Normal Impulse with Restitution Bias
                float vn = dv.dot(normal);
                float bias = c.softness.massScale * c.softness.biasRate * cp.baseSeparation;
                if (c.restitution > 0) bias -= c.restitution * vn; // Add bounce

                float lambda = -cp.normalMass * (c.softness.massScale * vn + bias) - c.softness.impulseScale * cp.normalImpulse;
                float oldImpulse = cp.normalImpulse;
                cp.normalImpulse = std::max(oldImpulse + lambda, 0.0f);
                lambda = cp.normalImpulse - oldImpulse;

                Vec2 P = normal * lambda;
                if (a.type != STATIC) { a.vx -= P.x * a.inverseMass; a.vy -= P.y * a.inverseMass; a.angularVelocity -= ra.cross(P) * a.inverseInertia; }
                if (b.type != STATIC) { b.vx += P.x * b.inverseMass; b.vy += P.y * b.inverseMass; b.angularVelocity += rb.cross(P) * b.inverseInertia; }

                // Friction Impulse
                dv = (Vec2{b.vx, b.vy} + cross(b.angularVelocity, rb)) - (Vec2{a.vx, a.vy} + cross(a.angularVelocity, ra));
                float lambdaT = -cp.tangentMass * dv.dot(tangent);
                float maxF = c.friction * cp.normalImpulse;
                oldImpulse = cp.tangentImpulse;
                cp.tangentImpulse = std::max(-maxF, std::min(oldImpulse + lambdaT, maxF));
                lambdaT = cp.tangentImpulse - oldImpulse;

                Vec2 Pt = tangent * lambdaT;
                if (a.type != STATIC) { a.vx -= Pt.x * a.inverseMass; a.vy -= Pt.y * a.inverseMass; a.angularVelocity -= ra.cross(Pt) * a.inverseInertia; }
                if (b.type != STATIC) { b.vx += Pt.x * b.inverseMass; b.vy += Pt.y * b.inverseMass; b.angularVelocity += rb.cross(Pt) * b.inverseInertia; }
            }
        }
        solve_joint_velocity_constraints(world);
    }
    
    // Store impulses for next frame.
    // Rebuild from scratch: the cache must hold only pairs that are actually
    // touching this step. Without the clear it grows without bound, keeping an
    // entry for every pair that has ever collided during the session.
    cache->clear();
    if (world->enableWarmStarting) {
         for (int i = 0; i < world->activeConstraints; ++i) {
            ContactConstraint& c = world->constraints[i];
            for (int j = 0; j < c.pointCount; ++j) {
                 ContactConstraintPoint& cp = c.points[j];
                 (*cache)[contact_cache_key(c.bodyA, c.bodyB, j)] = {cp.normalImpulse, cp.tangentImpulse};
            }
         }
    }

    // Phase 4: Integrate Positions
    for (int i = 0; i < world->activeCount; ++i) {
        NativeBody& b = world->bodies[i];
        if (b.type == STATIC || !b.isAwake) continue;
        b.x += b.vx * dt; b.y += b.vy * dt; b.rotation += b.angularVelocity * dt;
    }

    // Phase 5: Position Correction (pseudo-impulse for rotation stability)
    //
    // This used to re-run the entire narrow phase — SAT and all — inside every
    // position iteration. With 4 iterations and 2 sub-steps that meant the same
    // box pair went through detectBoxBox eight times per frame, purely to
    // re-derive a penetration depth.
    //
    // The constraint already carries what is needed: the contact anchors
    // relative to each body centre, and baseSeparation from manifold time. At
    // that moment the two anchor points coincide in world space, so the current
    // separation is baseSeparation plus however far the anchors have drifted
    // apart along the normal. That is a dot product, and it shrinks as the
    // solver pushes the bodies apart — which is exactly the feedback the
    // re-detection was providing.
    //
    // This is how Box2D's position solver works, and it is why those fields
    // exist on ContactConstraintPoint.
    const float slop = 0.01f, baumgarte = 0.2f;
    for (int iter = 0; iter < world->positionIterations; ++iter) {
        for (int i = 0; i < world->activeConstraints; ++i) {
            ContactConstraint& c = world->constraints[i];
            NativeBody& a = world->bodies[c.bodyA], &b = world->bodies[c.bodyB];
            if (!a.isAwake && !b.isAwake) continue;
            if (c.pointCount == 0) continue;

            const Vec2 normal = { c.normalX, c.normalY };
            const Vec2 posA = { a.x, a.y };
            const Vec2 posB = { b.x, b.y };

            for (int j = 0; j < c.pointCount; ++j) {
                ContactConstraintPoint& cp = c.points[j];
                const Vec2 ra = { cp.anchorAx, cp.anchorAy };
                const Vec2 rb = { cp.anchorBx, cp.anchorBy };

                // Anchors coincided when the manifold was built, so the drift
                // along the normal is the separation gained since then.
                const float drift = ((posB + rb) - (posA + ra)).dot(normal);
                const float separation = cp.baseSeparation + drift;

                const float C = std::max(-separation - slop, 0.0f) * baumgarte;
                if (C <= 0.0f) continue;

                const float raN = ra.cross(normal), rbN = rb.cross(normal);
                const float k = a.inverseMass + b.inverseMass +
                                raN * raN * a.inverseInertia + rbN * rbN * b.inverseInertia;
                if (k <= 1e-6f) continue;

                const Vec2 P = normal * (C / k);
                if (a.type != STATIC) { a.x -= P.x * a.inverseMass; a.y -= P.y * a.inverseMass; a.rotation -= ra.cross(P) * a.inverseInertia; }
                if (b.type != STATIC) { b.x += P.x * b.inverseMass; b.y += P.y * b.inverseMass; b.rotation += rb.cross(P) * b.inverseInertia; }
            }
        }
        solve_joint_position_constraints(world);
    }
}

// Version handshake. Dart uses this as a cheap, side-effect-free probe to
// decide whether the native core is available (see FlashNative.isAvailable).
// Bump when the exported ABI changes.
FLASH_API int32_t get_physics_version() {
    return FLASH_ABI_VERSION;
}

FLASH_API int32_t create_body(PhysicsWorld* world, int type, int shapeType, float x, float y, float w, float h, float rotation, uint32_t categoryBits, uint32_t maskBits) {
    if (!world || world->activeCount >= world->maxBodies) return -1;
    
    int32_t id = world->activeCount++;
    NativeBody& b = world->bodies[id];
    b.id = id;
    b.type = type;
    b.shapeType = shapeType;
    b.x = x;
    b.y = y;
    b.rotation = rotation;
    b.vx = b.vy = b.angularVelocity = 0;
    b.forceX = b.forceY = b.torque = 0;
    b.width = w;
    b.height = h;
    b.radius = (w < h ? w : h) / 2.0f;
    b.mass = (type == STATIC) ? 0.0f : 1.0f;
    b.inverseMass = (type == STATIC) ? 0.0f : 1.0f / b.mass;
    
    // Calculate Inertia
    if (type == STATIC) {
        b.inertia = b.inverseInertia = 0;
    } else {
        if (shapeType == SHAPE_BOX) b.inertia = (1.0f / 12.0f) * b.mass * (w * w + h * h);
        else b.inertia = 0.5f * b.mass * (b.radius * b.radius);
        b.inverseInertia = 1.0f / b.inertia;
    }
    
    b.restitution = 0.2f;
    b.friction = 0.4f;
    b.isSensor = false;
    b.isBullet = false;  // Default: no continuous collision
    b.sleepTime = 0.0f;  // Initialize sleep timer
    b.collision_count = 0;
    b.categoryBits = categoryBits;
    b.maskBits = maskBits;
    
    // Broadphase Proxy
    AABB aabb = calculate_body_aabb(b);
    b.proxyId = tree_insert_leaf(world->tree, id, aabb);
    
    b.isAwake = 1;
    b.islandId = -1;

    return id;
}

FLASH_API int32_t create_soft_body(PhysicsWorld* world, int pointCount, float* initialX, float* initialY, float pressure, float stiffness) {
    if (!world || world->activeSoftBodies >= world->maxSoftBodies) return -1;
    
    int32_t id = world->activeSoftBodies++;
    NativeSoftBody& sb = world->softBodies[id];
    sb.id = id;
    sb.pointCount = pointCount;
    // Use calloc
    sb.points = (SoftBodyPoint*)calloc(pointCount, sizeof(SoftBodyPoint));
    if (!sb.points) return -1;
    sb.pressure = pressure;
    sb.friction = 0.4f;
    sb.restitution = 0.2f;

    float area = 0;
    for (int i = 0; i < pointCount; i++) {
        sb.points[i].x = initialX[i];
        sb.points[i].y = initialY[i];
        sb.points[i].oldX = initialX[i];
        sb.points[i].oldY = initialY[i];
        sb.points[i].vx = sb.points[i].vy = 0;
        sb.points[i].ax = sb.points[i].ay = 0;
        sb.points[i].mass = 1.0f;
        sb.points[i].invMass = 1.0f;

        // Area calculation for pressure (Shoelace formula)
        int next = (i + 1) % pointCount;
        area += (initialX[i] * initialY[next] - initialX[next] * initialY[i]);
    }
    sb.targetArea = std::abs(area) * 0.5f;

    // Create neighbor constraints
    sb.constraintCount = pointCount + (pointCount / 2); // Perimeter + some interior supports
    // Debug print
    sb.constraints = (SoftBodyConstraint*)calloc(sb.constraintCount, sizeof(SoftBodyConstraint));
    
    int cIdx = 0;
    for (int i = 0; i < pointCount; i++) {
        // Perimeter
        sb.constraints[cIdx].p1 = i;
        sb.constraints[cIdx].p2 = (i + 1) % pointCount;
        float dx = initialX[i] - initialX[(i + 1) % pointCount];
        float dy = initialY[i] - initialY[(i + 1) % pointCount];
        sb.constraints[cIdx].restLength = std::sqrt(dx * dx + dy * dy);
        sb.constraints[cIdx].stiffness = stiffness;
        cIdx++;
    }

    for (int i = 0; i < pointCount / 2; i++) {
        // Cross supports
        sb.constraints[cIdx].p1 = i;
        sb.constraints[cIdx].p2 = (i + pointCount / 2) % pointCount;
        float dx = initialX[i] - initialX[(i + pointCount / 2) % pointCount];
        float dy = initialY[i] - initialY[(i + pointCount / 2) % pointCount];
        sb.constraints[cIdx].restLength = std::sqrt(dx * dx + dy * dy);
        sb.constraints[cIdx].stiffness = stiffness * 0.1f; // Interior is softer
        cIdx++;
    }

    return id;
}

FLASH_API void get_soft_body_point(PhysicsWorld* world, int32_t sbId, int pointIdx, float* x, float* y) {
    if (world && sbId >= 0 && sbId < world->activeSoftBodies) {
        NativeSoftBody& sb = world->softBodies[sbId];
        if (pointIdx >= 0 && pointIdx < sb.pointCount) {
            *x = sb.points[pointIdx].x;
            *y = sb.points[pointIdx].y;
        }
    }
}

FLASH_API void set_soft_body_point(PhysicsWorld* world, int32_t sbId, int pointIdx, float x, float y) {
    if (!world || sbId < 0 || sbId >= world->activeSoftBodies) return;
    if (pointIdx < 0 || pointIdx >= world->softBodies[sbId].pointCount) return;

    NativeSoftBody& sb = world->softBodies[sbId];
    sb.points[pointIdx].x = x;
    sb.points[pointIdx].y = y;
    
    // Also reset velocity to zero to prevent explosions when dragging
    sb.points[pointIdx].oldX = x;
    sb.points[pointIdx].oldY = y;
    sb.points[pointIdx].vx = 0;
    sb.points[pointIdx].vx = 0;
    sb.points[pointIdx].vy = 0;
}

FLASH_API void set_soft_body_params(PhysicsWorld* world, int32_t sbId, float pressure, float stiffness) {
    if (!world || sbId < 0 || sbId >= world->activeSoftBodies) return;
    
    NativeSoftBody& sb = world->softBodies[sbId];
    sb.pressure = pressure;
    
    // Update constraint stiffness
    for (int i = 0; i < sb.constraintCount; i++) {
        // Interior constraints (last third roughly) are usually softer, but for simplicity we re-apply logic
        // logic from create: stiffness * 0.1f for interior, stiffness for perimeter.
        // We know perimeter is first 'pointCount' constraints.
        
        bool isPerimeter = i < sb.pointCount;
        sb.constraints[i].stiffness = isPerimeter ? stiffness : (stiffness * 0.1f);
    }
}

// --- Soft Body Simulation ---

void step_soft_body(PhysicsWorld* world, float dt) {
    for (int i = 0; i < world->activeSoftBodies; i++) {
        NativeSoftBody& sb = world->softBodies[i];
        
        // 1. Gravity & Integration
        for (int pIdx = 0; pIdx < sb.pointCount; pIdx++) {
            SoftBodyPoint& p = sb.points[pIdx];
            
            p.ax = world->gravityX;
            p.ay = world->gravityY;

            float vx = (p.x - p.oldX) * 0.99f; // Slight damping
            float vy = (p.y - p.oldY) * 0.99f;
            
            p.oldX = p.x;
            p.oldY = p.y;
            
            p.x += vx + p.ax * dt * dt;
            p.y += vy + p.ay * dt * dt;
        }

        // 2. Constraints (multiple iterations for stiffness)
        for (int iter = 0; iter < 10; iter++) {
            for (int cIdx = 0; cIdx < sb.constraintCount; cIdx++) {
                SoftBodyConstraint& c = sb.constraints[cIdx];
                SoftBodyPoint& p1 = sb.points[c.p1];
                SoftBodyPoint& p2 = sb.points[c.p2];
                
                float dx = p2.x - p1.x;
                float dy = p2.y - p1.y;
                float dist = std::sqrt(dx * dx + dy * dy);
                if (dist < 0.0001f) continue;
                
                float diff = (dist - c.restLength) / dist;
                float offX = dx * 0.5f * diff * c.stiffness;
                float offY = dy * 0.5f * diff * c.stiffness;
                
                p1.x += offX;
                p1.y += offY;
                p2.x -= offX;
                p2.y -= offY;
            }

            // 3. Pressure
            float area = 0;
            for (int pIdx = 0; pIdx < sb.pointCount; pIdx++) {
                int next = (pIdx + 1) % sb.pointCount;
                area += (sb.points[pIdx].x * sb.points[next].y - sb.points[next].x * sb.points[pIdx].y);
            }
            area = std::abs(area) * 0.5f;
            float areaDiff = sb.targetArea - area;

            for (int pIdx = 0; pIdx < sb.pointCount; pIdx++) {
                int prev = (pIdx - 1 + sb.pointCount) % sb.pointCount;
                int next = (pIdx + 1) % sb.pointCount;
                
                float nx = sb.points[next].y - sb.points[prev].y;
                float ny = -(sb.points[next].x - sb.points[prev].x);
                float nLen = std::sqrt(nx * nx + ny * ny);
                if (nLen > 0.0001f) {
                    nx /= nLen;
                    ny /= nLen;
                    
                    // Force = AreaDiff * Pressure
                    float force = areaDiff * sb.pressure * 0.00001f;
                    sb.points[pIdx].x += nx * force;
                    sb.points[pIdx].y += ny * force;
                }
            }
        }

        // 4. Collision with Rigid Bodies
        for (int bIdx = 0; bIdx < world->activeCount; bIdx++) {
            NativeBody& b = world->bodies[bIdx];

            if (b.type == 0 && b.shapeType == 1 && b.width > 1000) {
                // Optimization: For huge static ground, use simple plane check if possible?
                // Actually, let's just do generic checks.
            }

            for (int pIdx = 0; pIdx < sb.pointCount; pIdx++) {
                SoftBodyPoint& p = sb.points[pIdx];

                if (b.shapeType == 0) { // Circle
                    float dx = p.x - b.x;
                    float dy = p.y - b.y;
                    float distSq = dx * dx + dy * dy;
                    float r = b.radius + 2.0f; // Add small radius to point
                    if (distSq < r * r) {
                        float dist = std::sqrt(distSq);
                        float pen = r - dist;
                        if (dist > 0.0001f) {
                            float nx = dx / dist;
                            float ny = dy / dist;
                            
                            // Push point out
                            p.x += nx * pen;
                            p.y += ny * pen;
                            
                            // Simple friction
                            float vx = p.x - p.oldX;
                            float vy = p.y - p.oldY;
                            p.oldX += vx * 0.1f; // Friction
                            p.oldY += vy * 0.1f;
                        }
                    }
                } else if (b.shapeType == 1) { // Box
                    // Transform point to box local space
                    float c = std::cos(-b.rotation);
                    float s = std::sin(-b.rotation);
                    
                    float dx = p.x - b.x;
                    float dy = p.y - b.y;
                    
                    float localX = dx * c - dy * s;
                    float localY = dx * s + dy * c;
                    
                    float hw = b.width * 0.5f;
                    float hh = b.height * 0.5f;
                    
                    // AABB Check in local space (with small point radius)
                    float pointRadius = 2.0f;
                    if (localX > -hw - pointRadius && localX < hw + pointRadius &&
                        localY > -hh - pointRadius && localY < hh + pointRadius) {
                        
                        // Find closest edge
                        float dLeft = localX - (-hw - pointRadius);
                        float dRight = (hw + pointRadius) - localX;
                        float dBottom = localY - (-hh - pointRadius);
                        float dTop = (hh + pointRadius) - localY;
                        
                        float minPen = std::min({dLeft, dRight, dBottom, dTop});
                        
                        float nLocalX = 0, nLocalY = 0;
                        if (minPen == dLeft) nLocalX = -1; // Push left? No, towards positive. Wait. 
                        // localX is > left edge. value is positive. so push RIGHT? No. 
                        // If inside, we want to push towards the CLOSEST OUTSIDE.
                        
                        if (minPen == dLeft) nLocalX = -1; // Wrong sign logic often. Let's think.
                        // inside box X = 0. left wall at -10. dist = 10. we want to push LEFT to get out? No, that's far.
                        // We want to push to closest edge.
                        
                        if (minPen == dLeft) nLocalX = -1; // Actually, if we are just barely inside left wall, localX is approx -hw.
                        // We want to push to -hw. So direction is NEGATIVE X?
                        
                        // Let's standardise:
                        // Penetration is ALWAYS positive depth.
                        // Normal points FROM box TO point.
                        
                        if (minPen == dLeft) nLocalX = -1; 
                        else if (minPen == dRight) nLocalX = 1;
                        else if (minPen == dBottom) nLocalY = -1;
                        else if (minPen == dTop) nLocalY = 1;
                        
                        // Transform normal back to world
                        float c_rot = std::cos(b.rotation);
                        float s_rot = std::sin(b.rotation);
                        
                        float worldNx = nLocalX * c_rot - nLocalY * s_rot;
                        float worldNy = nLocalX * s_rot + nLocalY * c_rot;
                        
                        // Push point
                        p.x += worldNx * minPen;
                        p.y += worldNy * minPen;
                        
                        // Friction/Velocity modification
                        // Dampen tangential velocity
                        // This is a naive friction model but works for "sticking"
                        p.oldX = p.x - (p.x - p.oldX) * 0.5f; 
                        p.oldY = p.y - (p.y - p.oldY) * 0.5f;
                    }
                }
            }
        }

        // 5. Primitive World Bounds (Keep it inside a box for now)
        for (int pIdx = 0; pIdx < sb.pointCount; pIdx++) {
            SoftBodyPoint& p = sb.points[pIdx];
            if (p.x < -1000) p.x = -1000;
            if (p.x > 1000) p.x = 1000;
            if (p.y < -1000) p.y = -1000;
            if (p.y > 1000) p.y = 1000;
        }
    }
}

FLASH_API void apply_force(PhysicsWorld* world, int32_t bodyId, float fx, float fy) {
    if (world && bodyId >= 0 && bodyId < world->activeCount) {
        NativeBody& b = world->bodies[bodyId];
        b.forceX += fx;
        b.forceY += fy;
        b.isAwake = 1;
        b.sleepTime = 0.0f;
    }
}

FLASH_API void apply_torque(PhysicsWorld* world, int32_t bodyId, float torque) {
    if (world && bodyId >= 0 && bodyId < world->activeCount) {
        NativeBody& b = world->bodies[bodyId];
        b.torque += torque;
        b.isAwake = 1;
        b.sleepTime = 0.0f;
    }
}

FLASH_API void set_body_velocity(PhysicsWorld* world, int32_t bodyId, float vx, float vy) {
    if (world && bodyId >= 0 && bodyId < world->activeCount) {
        NativeBody& b = world->bodies[bodyId];
        b.vx = vx;
        b.vy = vy;
        b.isAwake = 1;
        b.sleepTime = 0.0f;
    }
}

FLASH_API void get_body_position(PhysicsWorld* world, int32_t bodyId, float* x, float* y) {
    if (world && bodyId >= 0 && bodyId < world->activeCount) {
        *x = world->bodies[bodyId].x;
        *y = world->bodies[bodyId].y;
    }
}

// --- RayCasting Implementation ---

bool intersectRayCircle(float startX, float startY, float dx, float dy, 
                       float cx, float cy, float r, 
                       float& outFraction, float& outNx, float& outNy) {
    float fx = startX - cx;
    float fy = startY - cy;
    
    float a = dx * dx + dy * dy;
    float b = 2.0f * (fx * dx + fy * dy);
    float c = (fx * fx + fy * fy) - r * r;
    
    float discriminant = b * b - 4.0f * a * c;
    if (discriminant < 0.0f) return false;
    
    discriminant = std::sqrt(discriminant);
    float t1 = (-b - discriminant) / (2.0f * a);
    
    if (t1 >= 0.0f && t1 <= 1.0f) {
        outFraction = t1;
        float hitX = startX + dx * t1;
        float hitY = startY + dy * t1;
        
        float dist = std::sqrt((hitX - cx)*(hitX - cx) + (hitY - cy)*(hitY - cy));
        outNx = (hitX - cx) / dist;
        outNy = (hitY - cy) / dist;
        return true;
    }
    return false;
}

bool intersectRayAABB(float startX, float startY, float dx, float dy, 
                      float minX, float minY, float maxX, float maxY,
                      float& outFraction, float& outNx, float& outNy) {
    float tMin = 0.0f;
    float tMax = 1.0f;
    
    float nx = 0.0f, ny = 0.0f;
    
    // X Axis
    if (std::abs(dx) < 1e-6f) {
        if (startX < minX || startX > maxX) return false;
    } else {
        float invD = 1.0f / dx;
        float t1 = (minX - startX) * invD;
        float t2 = (maxX - startX) * invD;
        float s = 1.0f;
        
        if (t1 > t2) { std::swap(t1, t2); s = -1.0f; }
        
        if (t1 > tMin) {
            tMin = t1;
            nx = -s; ny = 0.0f;
        }
        tMax = std::min(tMax, t2);
        if (tMin > tMax) return false;
    }
    
    // Y Axis
    if (std::abs(dy) < 1e-6f) {
        if (startY < minY || startY > maxY) return false;
    } else {
        float invD = 1.0f / dy;
        float t1 = (minY - startY) * invD;
        float t2 = (maxY - startY) * invD;
        float s = 1.0f;
        
        if (t1 > t2) { std::swap(t1, t2); s = -1.0f; }
        
        if (t1 > tMin) {
            tMin = t1;
            nx = 0.0f; ny = -s;
        }
        tMax = std::min(tMax, t2);
        if (tMin > tMax) return false;
    }
    
    outFraction = tMin;
    outNx = nx;
    outNy = ny;
    return true;
}

FLASH_API RayCastHit ray_cast(PhysicsWorld* world, float startX, float startY, float endX, float endY) {
    RayCastHit closest;
    closest.hit = 0;
    closest.fraction = 1.0f;
    closest.bodyId = -1;
    
    if (!world) return closest;
    
    float dx = endX - startX;
    float dy = endY - startY;
    
    for (int i = 0; i < world->activeCount; ++i) {
        NativeBody& b = world->bodies[i];
        
        float hitFraction = 1.0f;
        float nx = 0, ny = 0;
        bool hit = false;
        
        if (b.shapeType == SHAPE_CIRCLE) {
             hit = intersectRayCircle(startX, startY, dx, dy, b.x, b.y, b.radius, hitFraction, nx, ny);
        } else if (b.shapeType == SHAPE_BOX) {
            // Transform Ray to Box Local Space
            float c = std::cos(-b.rotation);
            float s = std::sin(-b.rotation);
            
            float localStartX = (startX - b.x) * c - (startY - b.y) * s;
            float localStartY = (startX - b.x) * s + (startY - b.y) * c;
            
            float localDx = dx * c - dy * s;
            float localDy = dx * s + dy * c;
            
            float hw = b.width * 0.5f;
            float hh = b.height * 0.5f;
            
            if (intersectRayAABB(localStartX, localStartY, localDx, localDy, 
                                -hw, -hh, hw, hh, hitFraction, nx, ny)) {
                
                // Transform normal back to world space
                float c_rot = std::cos(b.rotation); // Assuming previous c was cos(-rot) = cos(rot)
                float s_rot = std::sin(b.rotation); // existing s was sin(-rot) = -sin(rot)
                
                // Manually recalculate C/S for clarity
                c_rot = c;
                s_rot = -s;
                
                float worldNx = nx * c_rot - ny * s_rot;
                float worldNy = nx * s_rot + ny * c_rot;
                                
                nx = worldNx;
                ny = worldNy;
                hit = true;
            }
        }
        
        if (hit && hitFraction < closest.fraction) {
            closest.fraction = hitFraction;
            closest.hit = 1;
            closest.bodyId = b.id;
            closest.normalX = nx;
            closest.normalY = ny;
            closest.x = startX + dx * hitFraction;
            closest.y = startY + dy * hitFraction;
        }
    }
    
    return closest;
}

}
