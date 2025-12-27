#include "physics.h"
#include "broadphase.h"
#include "joints.h"
#include <cmath>
#include <algorithm>
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

#include <map>

// Internal cache for warm starting
// Key: (minId << 32) | maxId
// Value: Stored impulses for the contact point
struct CachedImpulse {
    float normalImpulse;
    float tangentImpulse;
};
using ImpulseCache = std::map<uint64_t, CachedImpulse>;

extern "C" {

PhysicsWorld* create_physics_world(int maxBodies) {
    PhysicsWorld* world = new PhysicsWorld();
    world->bodies = new NativeBody[maxBodies];
    world->maxBodies = maxBodies;
    world->activeCount = 0;
    
    world->maxManifolds = maxBodies * 2; // Conservative estimate
    world->manifolds = new ContactManifold[world->maxManifolds];
    world->activeManifolds = 0;
    
    // Initialize contact constraints
    world->maxConstraints = maxBodies * 4;
    world->constraints = new ContactConstraint[world->maxConstraints];
    world->activeConstraints = 0;
    
    world->gravityX = 0;
    world->gravityY = -9.81f * 100.0f; // Y-Up coordinate system: Gravity is negative 
    
    // Box2D-inspired solver configuration
    world->velocityIterations = 8;  // Box2D default
    world->positionIterations = 10;  // Stronger position correction (was 3)
    world->enableWarmStarting = 1;  // Enable by default
    world->contactHertz = 120.0f;    // 120 Hz for Rigid contacts (was 30.0f)
    world->contactDampingRatio = 1.0f; // Critical damping (was 0.8f) to kill vibration
    world->restitutionThreshold = 1.0f * 100.0f; // 1 m/s in pixels
    world->maxLinearVelocity = 2000.0f * 100.0f;  // 2000 m/s in pixels (prevent clamping issues)
    
    // Create spatial hash grid for broadphase
    // Default world bounds: -10000 to 10000 pixels, 200 pixel cells
    world->spatialGrid = create_spatial_grid(-10000.0f, -10000.0f, 10000.0f, 10000.0f, 200.0f);
    
    // Initialize Box2D joints
    world->maxBoxJoints = 100;  // Support up to 100 joints
    world->boxJoints = new Joint[world->maxBoxJoints];
    world->activeBoxJoints = 0;
    
    return world;
}

void destroy_physics_world(PhysicsWorld* world) {
    if (!world) return;
    delete[] world->bodies;
    delete[] world->manifolds;
    delete[] world->constraints;
    destroy_spatial_grid(world->spatialGrid);
    delete[] world->boxJoints;
    delete world;
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

// Simple SAT helper for OBB vs OBB (Not fully exhaustive, but sufficient for high-quality box physics)
CollisionManifold detectBoxBox(NativeBody& a, NativeBody& b) {
    auto project = [](NativeBody& body, Vec2 axis, float& min, float& max) {
        float hw = body.width * 0.5f;
        float hh = body.height * 0.5f;
        Vec2 pos = {body.x, body.y};
        Vec2 v[4] = {
            pos + rotate({-hw, -hh}, body.rotation),
            pos + rotate({ hw, -hh}, body.rotation),
            pos + rotate({ hw,  hh}, body.rotation),
            pos + rotate({-hw,  hh}, body.rotation)
        };
        min = max = axis.dot(v[0]);
        for (int i = 1; i < 4; ++i) {
            float p = axis.dot(v[i]);
            if (p < min) min = p;
            if (p > max) max = p;
        }
    };

    float minOverlap = 1e10f;
    Vec2 bestAxis;
    NativeBody* ref = &a;
    NativeBody* inc = &b;

    Vec2 axes[4] = {
        rotate({1, 0}, a.rotation),
        rotate({0, 1}, a.rotation),
        rotate({1, 0}, b.rotation),
        rotate({0, 1}, b.rotation)
    };

    for (int i = 0; i < 4; ++i) {
        float minA, maxA, minB, maxB;
        project(a, axes[i], minA, maxA);
        project(b, axes[i], minB, maxB);

        float overlap = std::min(maxA, maxB) - std::max(minA, minB);
        if (overlap <= 0) return {{0,0}, 0, {{0,0}}, 0, false};

        if (overlap < minOverlap) {
            minOverlap = overlap;
            bestAxis = axes[i];
            if (i < 2) { ref = &a; inc = &b; }
            else { ref = &b; inc = &a; }
        }
    }

    Vec2 d = {b.x - a.x, b.y - a.y};
    if (bestAxis.dot(d) < 0) bestAxis = bestAxis * -1.0f;

    CollisionManifold m;
    m.collided = true;
    m.normal = bestAxis;
    m.penetration = minOverlap;
    m.contactCount = 1;

    // Contact Point: Deepest vertex of incident body into reference body
    float hw = inc->width * 0.5f;
    float hh = inc->height * 0.5f;
    Vec2 incPos = {inc->x, inc->y};
    Vec2 incVerts[4] = {
        incPos + rotate({-hw, -hh}, inc->rotation),
        incPos + rotate({ hw, -hh}, inc->rotation),
        incPos + rotate({ hw,  hh}, inc->rotation),
        incPos + rotate({-hw,  hh}, inc->rotation)
    };

    float minDot = 1e10f;
    Vec2 deepest;
    for(int i=0; i<4; ++i) {
        float dot = bestAxis.dot(incVerts[i]);
        if (dot < minDot) {
            minDot = dot;
            deepest = incVerts[i];
        }
    }
    m.contacts[0] = deepest + (bestAxis * (minOverlap * 0.5f));
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


void step_physics(PhysicsWorld* world, float dt) {
    if (!world || world->activeCount == 0 || dt <= 0) return;

    // Calculate softness for this time step
    Softness contactSoftness = makeSoftness(world->contactHertz, world->contactDampingRatio, dt);
    
    // Phase 1: Integrate forces and velocities
    for (int i = 0; i < world->activeCount; ++i) {
        NativeBody& b = world->bodies[i];
        if (b.type == STATIC) continue;

        // Apply gravity and forces
        b.vx += (world->gravityX + b.forceX * b.inverseMass) * dt;
        b.vy += (world->gravityY + b.forceY * b.inverseMass) * dt;
        b.angularVelocity += (b.torque * b.inverseInertia) * dt;
        
        // Clamp velocity for stability
        float speedSq = b.vx * b.vx + b.vy * b.vy;
        if (speedSq > world->maxLinearVelocity * world->maxLinearVelocity) {
            float speed = std::sqrt(speedSq);
            float ratio = world->maxLinearVelocity / speed;
            b.vx *= ratio;
            b.vy *= ratio;
        }
        
        b.forceX = b.forceY = b.torque = 0;
        b.collision_count = 0;
    }

    // Phase 2: Build contact constraints using broadphase
    world->activeConstraints = 0;
    
    // Clear and populate spatial grid
    clear_spatial_grid(world->spatialGrid);
    for (int i = 0; i < world->activeCount; ++i) {
        NativeBody& body = world->bodies[i];
        AABB aabb = calculate_body_aabb(body);
        insert_into_grid(world->spatialGrid, i, aabb);
    }
    
    // Query broadphase for potential collision pairs
    const int maxPairs = world->maxConstraints;
    BroadphasePair* pairs = new BroadphasePair[maxPairs];
    int pairCount = query_grid_pairs(world->spatialGrid, pairs, maxPairs);
    
    // Process each potential collision pair
    for (int p = 0; p < pairCount && world->activeConstraints < world->maxConstraints; ++p) {
        int i = pairs[p].bodyA;
        int j = pairs[p].bodyB;
        
        NativeBody& a = world->bodies[i];
        NativeBody& b = world->bodies[j];
        if (a.type == STATIC && b.type == STATIC) continue;

        // Detect collision
        CollisionManifold m = {{0,0}, 0, {{0,0}}, 0, false};
        if (a.shapeType == SHAPE_CIRCLE && b.shapeType == SHAPE_CIRCLE) m = detectCircleCircle(a, b);
        else if (a.shapeType == SHAPE_BOX && b.shapeType == SHAPE_BOX) m = detectBoxBox(a, b);
        else if (a.shapeType == SHAPE_CIRCLE) m = detectCircleBox(a, b);
        else { m = detectCircleBox(b, a); } // Correct normal (A->B) returned directly

        if (!m.collided) continue;
        
        // Fix normal direction for circle-box
        if (a.shapeType == SHAPE_CIRCLE && b.shapeType == SHAPE_BOX) {
            m.normal = m.normal * -1.0f;
        }

        // Create contact constraint
        ContactConstraint& constraint = world->constraints[world->activeConstraints++];
        constraint.bodyA = i;
        constraint.bodyB = j;
        constraint.normalX = m.normal.x;
        constraint.normalY = m.normal.y;
        constraint.friction = std::sqrt(a.friction * b.friction);
        constraint.restitution = std::max(a.restitution, b.restitution);
        constraint.pointCount = m.contactCount;
        constraint.softness = contactSoftness;
        constraint.rollingResistance = 0.0f;

        // Prepare contact points
        for (int c = 0; c < m.contactCount; ++c) {
            ContactConstraintPoint& cp = constraint.points[c];
            
            // Anchor points (relative to body centers)
            cp.anchorAx = m.contacts[c].x - a.x;
            cp.anchorAy = m.contacts[c].y - a.y;
            cp.anchorBx = m.contacts[c].x - b.x;
            cp.anchorBy = m.contacts[c].y - b.y;
            
            cp.baseSeparation = -m.penetration;
            
            // Calculate effective masses
            Vec2 ra = {cp.anchorAx, cp.anchorAy};
            Vec2 rb = {cp.anchorBx, cp.anchorBy};
            Vec2 normal = {m.normal.x, m.normal.y};
            
            float raCrossN = ra.cross(normal);
            float rbCrossN = rb.cross(normal);
            float kNormal = a.inverseMass + b.inverseMass + 
                           raCrossN * raCrossN * a.inverseInertia + 
                           rbCrossN * rbCrossN * b.inverseInertia;
            
            // Apply softness to effective mass
            kNormal += contactSoftness.massScale;
            cp.normalMass = kNormal > 0.0f ? 1.0f / kNormal : 0.0f;
            
            // Tangent mass
            Vec2 tangent = {-normal.y, normal.x};
            float raCrossT = ra.cross(tangent);
            float rbCrossT = rb.cross(tangent);
            float kTangent = a.inverseMass + b.inverseMass +
                            raCrossT * raCrossT * a.inverseInertia +
                            rbCrossT * rbCrossT * b.inverseInertia;
            cp.tangentMass = kTangent > 0.0f ? 1.0f / kTangent : 0.0f;
            
            // Initialize impulses (will be set by warm starting or zero)
            cp.normalImpulse = 0.0f;
            cp.tangentImpulse = 0.0f;
        }
        
        a.collision_count++;
        b.collision_count++;
    }
    
    delete[] pairs;

    // Phase 3: Warm start (apply cached impulses)
    if (world->enableWarmStarting) {
        for (int i = 0; i < world->activeConstraints; ++i) {
            ContactConstraint& c = world->constraints[i];
            NativeBody& a = world->bodies[c.bodyA];
            NativeBody& b = world->bodies[c.bodyB];
            Vec2 normal = {c.normalX, c.normalY};
            Vec2 tangent = {-normal.y, normal.x};
            
            for (int j = 0; j < c.pointCount; ++j) {
                ContactConstraintPoint& cp = c.points[j];
                Vec2 ra = {cp.anchorAx, cp.anchorAy};
                Vec2 rb = {cp.anchorBx, cp.anchorBy};
                
                // Scale cached impulses by softness
                Vec2 P = normal * (cp.normalImpulse * c.softness.impulseScale) + 
                        tangent * (cp.tangentImpulse * c.softness.impulseScale);
                
                if (a.type == DYNAMIC) {
                    a.vx -= P.x * a.inverseMass;
                    a.vy -= P.y * a.inverseMass;
                    a.angularVelocity -= ra.cross(P) * a.inverseInertia;
                }
                if (b.type == DYNAMIC) {
                    b.vx += P.x * b.inverseMass;
                    b.vy += P.y * b.inverseMass;
                    b.angularVelocity += rb.cross(P) * b.inverseInertia;
                }
            }
        }
    }
    
    // Phase 3.5: Initialize joint constraints
    init_joint_velocity_constraints(world, dt);

    // Phase 4: Velocity iterations (sequential impulse solver)
    for (int iter = 0; iter < world->velocityIterations; ++iter) {
        for (int i = 0; i < world->activeConstraints; ++i) {
            ContactConstraint& c = world->constraints[i];
            NativeBody& a = world->bodies[c.bodyA];
            NativeBody& b = world->bodies[c.bodyB];
            Vec2 normal = {c.normalX, c.normalY};
            Vec2 tangent = {-normal.y, normal.x};
            
            for (int j = 0; j < c.pointCount; ++j) {
                ContactConstraintPoint& cp = c.points[j];
                Vec2 ra = {cp.anchorAx, cp.anchorAy};
                Vec2 rb = {cp.anchorBx, cp.anchorBy};
                
                // Relative velocity at contact point
                Vec2 va = {a.vx, a.vy};
                Vec2 vb = {b.vx, b.vy};
                Vec2 dv = (vb + cross(b.angularVelocity, rb)) - (va + cross(a.angularVelocity, ra));
                
                // Solve normal constraint
                float vn = dv.dot(normal);
                
                // Calculate velocity bias (Baumgarte) matching Box2D
                // Box2D: velocityBias = softness.massScale * softness.biasRate * s
                // s is penetration (negative separation)
                // cp.baseSeparation is negative for penetration
                float separation = -cp.baseSeparation; // Convert to positive penetration? No, Box2D s is separation (negative for penetration)
                // Actually constraint->points[j].baseSeparation in Box2D is separation.
                // Box2D: s = separation - constraint->points[j].baseSeparation ? No.
                // s is separation.
                
                // In my code: cp.baseSeparation = -m.penetration; (so it's negative)
                // Box2D logic: velocityBias = b2MaxFloat( softness.massScale * softness.biasRate * s, -contactSpeed );
                
                float bias = c.softness.massScale * c.softness.biasRate * cp.baseSeparation;
                
                // Box2D Solver: 
                // float impulse = -cp->normalMass * ( massScale * vn + velocityBias ) - impulseScale * cp->normalImpulse;
                
                float lambda = -cp.normalMass * (c.softness.massScale * vn + bias) - c.softness.impulseScale * cp.normalImpulse;
                
                // Clamp accumulated impulse
                float newImpulse = std::max(cp.normalImpulse + lambda, 0.0f);
                lambda = newImpulse - cp.normalImpulse;
                cp.normalImpulse = newImpulse;
                
                // Apply impulse
                Vec2 P = normal * lambda;
                if (a.type == DYNAMIC) {
                    a.vx -= P.x * a.inverseMass;
                    a.vy -= P.y * a.inverseMass;
                    a.angularVelocity -= ra.cross(P) * a.inverseInertia;
                }
                if (b.type == DYNAMIC) {
                    b.vx += P.x * b.inverseMass;
                    b.vy += P.y * b.inverseMass;
                    b.angularVelocity += rb.cross(P) * b.inverseInertia;
                }
                
                // Solve friction constraint
                dv = (Vec2{b.vx, b.vy} + cross(b.angularVelocity, rb)) - 
                     (Vec2{a.vx, a.vy} + cross(a.angularVelocity, ra));
                float vt = dv.dot(tangent);
                float lambdaT = -cp.tangentMass * vt;
                
                // Coulomb friction
                float maxFriction = c.friction * cp.normalImpulse;
                float newImpulseT = std::max(-maxFriction, std::min(cp.tangentImpulse + lambdaT, maxFriction));
                lambdaT = newImpulseT - cp.tangentImpulse;
                cp.tangentImpulse = newImpulseT;
                
                // Apply friction impulse
                Vec2 Pt = tangent * lambdaT;
                if (a.type == DYNAMIC) {
                    a.vx -= Pt.x * a.inverseMass;
                    a.vy -= Pt.y * a.inverseMass;
                    a.angularVelocity -= ra.cross(Pt) * a.inverseInertia;
                }
                if (b.type == DYNAMIC) {
                    b.vx += Pt.x * b.inverseMass;
                    b.vy += Pt.y * b.inverseMass;
                    b.angularVelocity += rb.cross(Pt) * b.inverseInertia;
                }
            }
        }
        
        // Solve joint velocity constraints
        solve_joint_velocity_constraints(world);
    }

    // Phase 5: Integrate positions
    for (int i = 0; i < world->activeCount; ++i) {
        NativeBody& b = world->bodies[i];
        if (b.type == STATIC) continue;
        b.x += b.vx * dt;
        b.y += b.vy * dt;
        b.rotation += b.angularVelocity * dt;
    }

    // Phase 6: Position correction (non-linear Gauss-Seidel)
    const float slop = 0.005f;  // Smaller slop for tighter correction
    const float baumgarte = 0.4f;  // More aggressive correction (was 0.2)
    
    for (int iter = 0; iter < world->positionIterations; ++iter) {
        for (int i = 0; i < world->activeConstraints; ++i) {
            ContactConstraint& c = world->constraints[i];
            NativeBody& a = world->bodies[c.bodyA];
            NativeBody& b = world->bodies[c.bodyB];
            
            // Re-evaluate collision for current positions
            CollisionManifold m = {{0,0}, 0, {{0,0}}, 0, false};
            if (a.shapeType == SHAPE_CIRCLE && b.shapeType == SHAPE_CIRCLE) m = detectCircleCircle(a, b);
            else if (a.shapeType == SHAPE_BOX && b.shapeType == SHAPE_BOX) m = detectBoxBox(a, b);
            else if (a.shapeType == SHAPE_CIRCLE) m = detectCircleBox(a, b);
            else { m = detectCircleBox(b, a); } // Correct normal (A->B) returned directly
            
            if (!m.collided) continue;
            
            if (a.shapeType == SHAPE_CIRCLE && b.shapeType == SHAPE_BOX) {
                m.normal = m.normal * -1.0f;
            }
            
            // Apply position correction
            float correction = std::max(m.penetration - slop, 0.0f) * baumgarte;
            float totalInvMass = a.inverseMass + b.inverseMass;
            if (totalInvMass > 0.0f) {
                Vec2 impulse = m.normal * (correction / totalInvMass);
                if (a.type == DYNAMIC) {
                    a.x -= impulse.x * a.inverseMass;
                    a.y -= impulse.y * a.inverseMass;
                }
                if (b.type == DYNAMIC) {
                    b.x += impulse.x * b.inverseMass;
                    b.y += impulse.y * b.inverseMass;
                }
            }
        }
    }
    
    // Phase 6.5: Solve joint position constraints
    solve_joint_position_constraints(world);
}

int32_t create_body(PhysicsWorld* world, int type, int shapeType, float x, float y, float w, float h, float rotation) {
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

    return id;
}

void apply_force(PhysicsWorld* world, int32_t bodyId, float fx, float fy) {
    if (world && bodyId >= 0 && bodyId < world->activeCount) {
        world->bodies[bodyId].forceX += fx;
        world->bodies[bodyId].forceY += fy;
    }
}

void apply_torque(PhysicsWorld* world, int32_t bodyId, float torque) {
    if (world && bodyId >= 0 && bodyId < world->activeCount) {
        world->bodies[bodyId].torque += torque;
    }
}

void set_body_velocity(PhysicsWorld* world, int32_t bodyId, float vx, float vy) {
    if (world && bodyId >= 0 && bodyId < world->activeCount) {
        world->bodies[bodyId].vx = vx;
        world->bodies[bodyId].vy = vy;
    }
}

void get_body_position(PhysicsWorld* world, int32_t bodyId, float* x, float* y) {
    if (world && bodyId >= 0 && bodyId < world->activeCount) {
        *x = world->bodies[bodyId].x;
        *y = world->bodies[bodyId].y;
    }
}

}
