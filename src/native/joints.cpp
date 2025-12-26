#include "joints.h"
#include "physics.h"
#include <cmath>
#include <algorithm>

extern "C" {

// Helper: Get body from world
static inline NativeBody* get_body(PhysicsWorld* world, uint32_t id) {
    if (id >= (uint32_t)world->activeCount) return nullptr;
    return &world->bodies[id];
}

// Create joint
int create_joint(PhysicsWorld* world, JointDef* def) {
    if (!world || !def || world->activeBoxJoints >= world->maxBoxJoints) {
        return -1;
    }
    
    int jointId = world->activeBoxJoints++;
    Joint* joint = &world->boxJoints[jointId];
    
    joint->type = def->type;
    joint->bodyA = def->bodyA;
    joint->bodyB = def->bodyB;
    joint->localAnchorAx = def->anchorAx;
    joint->localAnchorAy = def->anchorAy;
    joint->localAnchorBx = def->anchorBx;
    joint->localAnchorBy = def->anchorBy;
    joint->impulse = 0.0f;
    joint->motorImpulse = 0.0f;
    
    // Initialize joint-specific parameters
    switch (def->type) {
        case DISTANCE_JOINT:
            joint->distance.length = def->length;
            joint->distance.frequency = def->frequency;
            joint->distance.dampingRatio = def->dampingRatio;
            joint->distance.gamma = 0.0f;
            joint->distance.biasCoeff = 0.0f;
            break;
            
        case REVOLUTE_JOINT:
            joint->revolute.referenceAngle = def->referenceAngle;
            joint->revolute.enableLimit = def->enableLimit;
            joint->revolute.lowerAngle = def->lowerAngle;
            joint->revolute.upperAngle = def->upperAngle;
            joint->revolute.enableMotor = def->enableMotor;
            joint->revolute.motorSpeed = def->motorSpeed;
            joint->revolute.maxMotorTorque = def->maxMotorTorque;
            joint->revolute.angle = 0.0f;
            break;
            
        case PRISMATIC_JOINT:
            joint->prismatic.axisx = def->axisx;
            joint->prismatic.axisy = def->axisy;
            joint->prismatic.lowerTranslation = def->lowerTranslation;
            joint->prismatic.upperTranslation = def->upperTranslation;
            joint->prismatic.enableLimit = def->enableLimit;
            joint->prismatic.enableMotor = def->enableMotor;
            joint->prismatic.motorSpeed = def->motorSpeed;
            joint->prismatic.maxMotorForce = def->maxMotorForce;
            joint->prismatic.translation = 0.0f;
            break;
            
        case WELD_JOINT:
            joint->weld.stiffness = def->stiffness;
            joint->weld.damping = def->damping;
            joint->weld.gamma = 0.0f;
            joint->weld.biasCoeff = 0.0f;
            joint->weld.impulseX = 0.0f;
            joint->weld.impulseY = 0.0f;
            joint->weld.angularImpulse = 0.0f;
            break;
    }
    
    return jointId;
}

void destroy_joint(PhysicsWorld* world, int jointId) {
    if (!world || jointId < 0 || jointId >= world->activeBoxJoints) return;
    
    // Swap with last joint and decrease count
    if (jointId < world->activeBoxJoints - 1) {
        world->boxJoints[jointId] = world->boxJoints[world->activeBoxJoints - 1];
    }
    world->activeBoxJoints--;
}

// Initialize velocity constraints
void init_joint_velocity_constraints(PhysicsWorld* world, float dt) {
    for (int i = 0; i < world->activeBoxJoints; ++i) {
        Joint* joint = &world->boxJoints[i];
        NativeBody* bodyA = get_body(world, joint->bodyA);
        NativeBody* bodyB = get_body(world, joint->bodyB);
        
        if (!bodyA || !bodyB) continue;
        
        if (joint->type == DISTANCE_JOINT) {
            // Calculate softness parameters
            float freq = joint->distance.frequency;
            float damp = joint->distance.dampingRatio;
            
            if (freq > 0.0f) {
                const float PI = 3.14159265359f;
                float omega = 2.0f * PI * freq;
                float d = 2.0f * damp * omega;
                float k = omega * omega;
                
                joint->distance.gamma = dt * (d + dt * k);
                if (joint->distance.gamma > 0.0f) {
                    joint->distance.gamma = 1.0f / joint->distance.gamma;
                }
                joint->distance.biasCoeff = k * joint->distance.gamma;
            } else {
                joint->distance.gamma = 0.0f;
                joint->distance.biasCoeff = 0.0f;
            }
        }
    }
}

// Distance joint velocity solver
void solve_distance_joint_velocity(Joint* joint, PhysicsWorld* world) {
    NativeBody* bodyA = get_body(world, joint->bodyA);
    NativeBody* bodyB = get_body(world, joint->bodyB);
    
    if (!bodyA || !bodyB) return;
    
    // Rotate anchors to world space
    float cosA = std::cos(bodyA->rotation);
    float sinA = std::sin(bodyA->rotation);
    float cosB = std::cos(bodyB->rotation);
    float sinB = std::sin(bodyB->rotation);
    
    float rAx = cosA * joint->localAnchorAx - sinA * joint->localAnchorAy;
    float rAy = sinA * joint->localAnchorAx + cosA * joint->localAnchorAy;
    float rBx = cosB * joint->localAnchorBx - sinB * joint->localAnchorBy;
    float rBy = sinB * joint->localAnchorBx + cosB * joint->localAnchorBy;
    
    // Calculate world anchor positions
    float pAx = bodyA->x + rAx;
    float pAy = bodyA->y + rAy;
    float pBx = bodyB->x + rBx;
    float pBy = bodyB->y + rBy;
    
    // Distance vector
    float dx = pBx - pAx;
    float dy = pBy - pAy;
    float length = std::sqrt(dx * dx + dy * dy);
    
    if (length < 0.001f) return;
    
    // Normalize
    float nx = dx / length;
    float ny = dy / length;
    
    // Relative velocity
    float vAx = bodyA->vx + (-bodyA->angularVelocity * rAy);
    float vAy = bodyA->vy + (bodyA->angularVelocity * rAx);
    float vBx = bodyB->vx + (-bodyB->angularVelocity * rBy);
    float vBy = bodyB->vy + (bodyB->angularVelocity * rBx);
    
    float dvx = vBx - vAx;
    float dvy = vBy - vAy;
    float vn = dvx * nx + dvy * ny;
    
    // Effective mass
    float raCrossN = rAx * ny - rAy * nx;
    float rbCrossN = rBx * ny - rBy * nx;
    float kNormal = bodyA->inverseMass + bodyB->inverseMass +
                   raCrossN * raCrossN * bodyA->inverseInertia +
                   rbCrossN * rbCrossN * bodyB->inverseInertia;
    
    kNormal += joint->distance.gamma;
    joint->effectiveMass = kNormal > 0.0f ? 1.0f / kNormal : 0.0f;
    
    // Bias (position error)
    float C = length - joint->distance.length;
    float bias = joint->distance.biasCoeff * C;
    
    // Compute impulse
    float lambda = -joint->effectiveMass * (vn + bias + joint->distance.gamma * joint->impulse);
    joint->impulse += lambda;
    
    // Apply impulse
    float Px = lambda * nx;
    float Py = lambda * ny;
    
    if (bodyA->type == DYNAMIC) {
        bodyA->vx -= Px * bodyA->inverseMass;
        bodyA->vy -= Py * bodyA->inverseMass;
        bodyA->angularVelocity -= (rAx * Py - rAy * Px) * bodyA->inverseInertia;
    }
    if (bodyB->type == DYNAMIC) {
        bodyB->vx += Px * bodyB->inverseMass;
        bodyB->vy += Py * bodyB->inverseMass;
        bodyB->angularVelocity += (rBx * Py - rBy * Px) * bodyB->inverseInertia;
    }
}

// Solve all joint velocity constraints
void solve_joint_velocity_constraints(PhysicsWorld* world) {
    for (int i = 0; i < world->activeBoxJoints; ++i) {
        Joint* joint = &world->boxJoints[i];
        
        switch (joint->type) {
            case DISTANCE_JOINT:
                solve_distance_joint_velocity(joint, world);
                break;
            case REVOLUTE_JOINT:
                solve_revolute_joint_velocity(joint, world);
                break;
            case PRISMATIC_JOINT:
                solve_prismatic_joint_velocity(joint, world);
                break;
            case WELD_JOINT:
                solve_weld_joint_velocity(joint, world);
                break;
        }
    }
}

// Distance joint position solver
void solve_distance_joint_position(Joint* joint, PhysicsWorld* world) {
    NativeBody* bodyA = get_body(world, joint->bodyA);
    NativeBody* bodyB = get_body(world, joint->bodyB);
    
    if (!bodyA || !bodyB) return;
    if (joint->distance.frequency > 0.0f) return; // Soft constraint, skip position solve
    
    // Rotate anchors to world space
    float cosA = std::cos(bodyA->rotation);
    float sinA = std::sin(bodyA->rotation);
    float cosB = std::cos(bodyB->rotation);
    float sinB = std::sin(bodyB->rotation);
    
    float rAx = cosA * joint->localAnchorAx - sinA * joint->localAnchorAy;
    float rAy = sinA * joint->localAnchorAx + cosA * joint->localAnchorAy;
    float rBx = cosB * joint->localAnchorBx - sinB * joint->localAnchorBy;
    float rBy = sinB * joint->localAnchorBx + cosB * joint->localAnchorBy;
    
    // Calculate world anchor positions
    float pAx = bodyA->x + rAx;
    float pAy = bodyA->y + rAy;
    float pBx = bodyB->x + rBx;
    float pBy = bodyB->y + rBy;
    
    // Distance vector
    float dx = pBx - pAx;
    float dy = pBy - pAy;
    float length = std::sqrt(dx * dx + dy * dy);
    
    if (length < 0.001f) return;
    
    // Position error
    float C = length - joint->distance.length;
    C = std::max(-0.2f, std::min(C, 0.2f)); // Clamp
    
    // Normalize
    float nx = dx / length;
    float ny = dy / length;
    
    // Effective mass
    float raCrossN = rAx * ny - rAy * nx;
    float rbCrossN = rBx * ny - rBy * nx;
    float kNormal = bodyA->inverseMass + bodyB->inverseMass +
                   raCrossN * raCrossN * bodyA->inverseInertia +
                   rbCrossN * rbCrossN * bodyB->inverseInertia;
    
    float impulse = kNormal > 0.0f ? -C / kNormal : 0.0f;
    
    float Px = impulse * nx;
    float Py = impulse * ny;
    
    if (bodyA->type == DYNAMIC) {
        bodyA->x -= Px * bodyA->inverseMass;
        bodyA->y -= Py * bodyA->inverseMass;
    }
    if (bodyB->type == DYNAMIC) {
        bodyB->x += Px * bodyB->inverseMass;
        bodyB->y += Py * bodyB->inverseMass;
    }
}

// Solve all joint position constraints
void solve_joint_position_constraints(PhysicsWorld* world) {
    for (int i = 0; i < world->activeBoxJoints; ++i) {
        Joint* joint = &world->boxJoints[i];
        
        switch (joint->type) {
            case DISTANCE_JOINT:
                solve_distance_joint_position(joint, world);
                break;
            case REVOLUTE_JOINT:
                solve_revolute_joint_position(joint, world);
                break;
            case PRISMATIC_JOINT:
                solve_prismatic_joint_position(joint, world);
                break;
            case WELD_JOINT:
                solve_weld_joint_position(joint, world);
                break;
        }
    }
}

// Revolute joint velocity solver
void solve_revolute_joint_velocity(Joint* joint, PhysicsWorld* world) {
    NativeBody* bodyA = get_body(world, joint->bodyA);
    NativeBody* bodyB = get_body(world, joint->bodyB);
    
    if (!bodyA || !bodyB) return;
    
    // Rotate anchors to world space
    float cosA = std::cos(bodyA->rotation);
    float sinA = std::sin(bodyA->rotation);
    float cosB = std::cos(bodyB->rotation);
    float sinB = std::sin(bodyB->rotation);
    
    float rAx = cosA * joint->localAnchorAx - sinA * joint->localAnchorAy;
    float rAy = sinA * joint->localAnchorAx + cosA * joint->localAnchorAy;
    float rBx = cosB * joint->localAnchorBx - sinB * joint->localAnchorBy;
    float rBy = sinB * joint->localAnchorBx + cosB * joint->localAnchorBy;
    
    // Point-to-point constraint (keeps anchors together)
    float vAx = bodyA->vx + (-bodyA->angularVelocity * rAy);
    float vAy = bodyA->vy + (bodyA->angularVelocity * rAx);
    float vBx = bodyB->vx + (-bodyB->angularVelocity * rBy);
    float vBy = bodyB->vy + (bodyB->angularVelocity * rBx);
    
    float dvx = vBx - vAx;
    float dvy = vBy - vAy;
    
    // Effective mass for linear constraint
    float k11 = bodyA->inverseMass + bodyB->inverseMass + 
                rAy * rAy * bodyA->inverseInertia + rBy * rBy * bodyB->inverseInertia;
    float k22 = bodyA->inverseMass + bodyB->inverseMass + 
                rAx * rAx * bodyA->inverseInertia + rBx * rBx * bodyB->inverseInertia;
    float k12 = -rAy * rAx * bodyA->inverseInertia - rBy * rBx * bodyB->inverseInertia;
    
    float det = k11 * k22 - k12 * k12;
    if (det > 0.0f) {
        det = 1.0f / det;
        float lambdaX = -det * (k22 * dvx - k12 * dvy);
        float lambdaY = -det * (k11 * dvy - k12 * dvx);
        
        if (bodyA->type == DYNAMIC) {
            bodyA->vx -= lambdaX * bodyA->inverseMass;
            bodyA->vy -= lambdaY * bodyA->inverseMass;
            bodyA->angularVelocity -= (rAx * lambdaY - rAy * lambdaX) * bodyA->inverseInertia;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->vx += lambdaX * bodyB->inverseMass;
            bodyB->vy += lambdaY * bodyB->inverseMass;
            bodyB->angularVelocity += (rBx * lambdaY - rBy * lambdaX) * bodyB->inverseInertia;
        }
    }
    
    // Motor
    if (joint->revolute.enableMotor) {
        float angularVel = bodyB->angularVelocity - bodyA->angularVelocity;
        float motorLambda = (joint->revolute.motorSpeed - angularVel) * joint->effectiveMass;
        
        float oldMotorImpulse = joint->motorImpulse;
        float maxImpulse = joint->revolute.maxMotorTorque * 0.016f; // Assume 60 FPS
        joint->motorImpulse = std::max(-maxImpulse, std::min(oldMotorImpulse + motorLambda, maxImpulse));
        motorLambda = joint->motorImpulse - oldMotorImpulse;
        
        if (bodyA->type == DYNAMIC) {
            bodyA->angularVelocity -= motorLambda * bodyA->inverseInertia;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->angularVelocity += motorLambda * bodyB->inverseInertia;
        }
    }
    
    // Angle limits
    if (joint->revolute.enableLimit) {
        float angle = bodyB->rotation - bodyA->rotation - joint->revolute.referenceAngle;
        
        // Normalize angle to [-PI, PI]
        const float PI = 3.14159265359f;
        while (angle > PI) angle -= 2.0f * PI;
        while (angle < -PI) angle += 2.0f * PI;
        
        float C = 0.0f;
        if (angle < joint->revolute.lowerAngle) {
            C = angle - joint->revolute.lowerAngle;
        } else if (angle > joint->revolute.upperAngle) {
            C = angle - joint->revolute.upperAngle;
        }
        
        if (C != 0.0f) {
            float angularVel = bodyB->angularVelocity - bodyA->angularVelocity;
            float limitLambda = -angularVel * joint->effectiveMass - 0.2f * C / 0.016f;
            
            if (bodyA->type == DYNAMIC) {
                bodyA->angularVelocity -= limitLambda * bodyA->inverseInertia;
            }
            if (bodyB->type == DYNAMIC) {
                bodyB->angularVelocity += limitLambda * bodyB->inverseInertia;
            }
        }
    }
}

void solve_revolute_joint_position(Joint* joint, PhysicsWorld* world) {
    NativeBody* bodyA = get_body(world, joint->bodyA);
    NativeBody* bodyB = get_body(world, joint->bodyB);
    
    if (!bodyA || !bodyB) return;
    
    // Rotate anchors
    float cosA = std::cos(bodyA->rotation);
    float sinA = std::sin(bodyA->rotation);
    float cosB = std::cos(bodyB->rotation);
    float sinB = std::sin(bodyB->rotation);
    
    float rAx = cosA * joint->localAnchorAx - sinA * joint->localAnchorAy;
    float rAy = sinA * joint->localAnchorAx + cosA * joint->localAnchorAy;
    float rBx = cosB * joint->localAnchorBx - sinB * joint->localAnchorBy;
    float rBy = sinB * joint->localAnchorBx + cosB * joint->localAnchorBy;
    
    // Position error
    float Cx = (bodyB->x + rBx) - (bodyA->x + rAx);
    float Cy = (bodyB->y + rBy) - (bodyA->y + rAy);
    
    // Clamp
    float length = std::sqrt(Cx * Cx + Cy * Cy);
    if (length > 0.2f) {
        Cx *= 0.2f / length;
        Cy *= 0.2f / length;
    }
    
    // Solve
    float k11 = bodyA->inverseMass + bodyB->inverseMass + 
                rAy * rAy * bodyA->inverseInertia + rBy * rBy * bodyB->inverseInertia;
    float k22 = bodyA->inverseMass + bodyB->inverseMass + 
                rAx * rAx * bodyA->inverseInertia + rBx * rBx * bodyB->inverseInertia;
    float k12 = -rAy * rAx * bodyA->inverseInertia - rBy * rBx * bodyB->inverseInertia;
    
    float det = k11 * k22 - k12 * k12;
    if (det > 0.0f) {
        det = 1.0f / det;
        float impulseX = -det * (k22 * Cx - k12 * Cy);
        float impulseY = -det * (k11 * Cy - k12 * Cx);
        
        if (bodyA->type == DYNAMIC) {
            bodyA->x -= impulseX * bodyA->inverseMass;
            bodyA->y -= impulseY * bodyA->inverseMass;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->x += impulseX * bodyB->inverseMass;
            bodyB->y += impulseY * bodyB->inverseMass;
        }
    }
}

// Prismatic joint velocity solver
void solve_prismatic_joint_velocity(Joint* joint, PhysicsWorld* world) {
    NativeBody* bodyA = get_body(world, joint->bodyA);
    NativeBody* bodyB = get_body(world, joint->bodyB);
    
    if (!bodyA || !bodyB) return;
    
    // Rotate anchors and axis to world space
    float cosA = std::cos(bodyA->rotation);
    float sinA = std::sin(bodyA->rotation);
    float cosB = std::cos(bodyB->rotation);
    float sinB = std::sin(bodyB->rotation);
    
    float rAx = cosA * joint->localAnchorAx - sinA * joint->localAnchorAy;
    float rAy = sinA * joint->localAnchorAx + cosA * joint->localAnchorAy;
    float rBx = cosB * joint->localAnchorBx - sinB * joint->localAnchorBy;
    float rBy = sinB * joint->localAnchorBx + cosB * joint->localAnchorBy;
    
    // World axis
    float axisx = cosA * joint->prismatic.axisx - sinA * joint->prismatic.axisy;
    float axisy = sinA * joint->prismatic.axisx + cosA * joint->prismatic.axisy;
    
    // Perpendicular axis
    float perpx = -axisy;
    float perpy = axisx;
    
    // Relative velocity
    float vAx = bodyA->vx + (-bodyA->angularVelocity * rAy);
    float vAy = bodyA->vy + (bodyA->angularVelocity * rAx);
    float vBx = bodyB->vx + (-bodyB->angularVelocity * rBy);
    float vBy = bodyB->vy + (bodyB->angularVelocity * rBx);
    
    float dvx = vBx - vAx;
    float dvy = vBy - vAy;
    
    // Perpendicular constraint (no movement perpendicular to axis)
    float vPerp = dvx * perpx + dvy * perpy;
    float raCrossPerp = rAx * perpy - rAy * perpx;
    float rbCrossPerp = rBx * perpy - rBy * perpx;
    
    float kPerp = bodyA->inverseMass + bodyB->inverseMass +
                  raCrossPerp * raCrossPerp * bodyA->inverseInertia +
                  rbCrossPerp * rbCrossPerp * bodyB->inverseInertia;
    
    if (kPerp > 0.0f) {
        float lambdaPerp = -vPerp / kPerp;
        float Px = lambdaPerp * perpx;
        float Py = lambdaPerp * perpy;
        
        if (bodyA->type == DYNAMIC) {
            bodyA->vx -= Px * bodyA->inverseMass;
            bodyA->vy -= Py * bodyA->inverseMass;
            bodyA->angularVelocity -= raCrossPerp * lambdaPerp * bodyA->inverseInertia;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->vx += Px * bodyB->inverseMass;
            bodyB->vy += Py * bodyB->inverseMass;
            bodyB->angularVelocity += rbCrossPerp * lambdaPerp * bodyB->inverseInertia;
        }
    }
    
    // Angular constraint (keep same rotation)
    float angularVel = bodyB->angularVelocity - bodyA->angularVelocity;
    float kAngular = bodyA->inverseInertia + bodyB->inverseInertia;
    
    if (kAngular > 0.0f) {
        float lambdaAngular = -angularVel / kAngular;
        
        if (bodyA->type == DYNAMIC) {
            bodyA->angularVelocity -= lambdaAngular * bodyA->inverseInertia;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->angularVelocity += lambdaAngular * bodyB->inverseInertia;
        }
    }
    
    // Motor (along axis)
    if (joint->prismatic.enableMotor) {
        float vAxis = dvx * axisx + dvy * axisy;
        float raCrossAxis = rAx * axisy - rAy * axisx;
        float rbCrossAxis = rBx * axisy - rBy * axisx;
        
        float kAxis = bodyA->inverseMass + bodyB->inverseMass +
                     raCrossAxis * raCrossAxis * bodyA->inverseInertia +
                     rbCrossAxis * rbCrossAxis * bodyB->inverseInertia;
        
        if (kAxis > 0.0f) {
            float motorLambda = (joint->prismatic.motorSpeed - vAxis) / kAxis;
            
            float oldMotorImpulse = joint->motorImpulse;
            float maxImpulse = joint->prismatic.maxMotorForce * 0.016f;
            joint->motorImpulse = std::max(-maxImpulse, std::min(oldMotorImpulse + motorLambda, maxImpulse));
            motorLambda = joint->motorImpulse - oldMotorImpulse;
            
            float Px = motorLambda * axisx;
            float Py = motorLambda * axisy;
            
            if (bodyA->type == DYNAMIC) {
                bodyA->vx -= Px * bodyA->inverseMass;
                bodyA->vy -= Py * bodyA->inverseMass;
                bodyA->angularVelocity -= raCrossAxis * motorLambda * bodyA->inverseInertia;
            }
            if (bodyB->type == DYNAMIC) {
                bodyB->vx += Px * bodyB->inverseMass;
                bodyB->vy += Py * bodyB->inverseMass;
                bodyB->angularVelocity += rbCrossAxis * motorLambda * bodyB->inverseInertia;
            }
        }
    }
}

void solve_prismatic_joint_position(Joint* joint, PhysicsWorld* world) {
    NativeBody* bodyA = get_body(world, joint->bodyA);
    NativeBody* bodyB = get_body(world, joint->bodyB);
    
    if (!bodyA || !bodyB) return;
    
    // Rotate anchors and axis
    float cosA = std::cos(bodyA->rotation);
    float sinA = std::sin(bodyA->rotation);
    float cosB = std::cos(bodyB->rotation);
    float sinB = std::sin(bodyB->rotation);
    
    float rAx = cosA * joint->localAnchorAx - sinA * joint->localAnchorAy;
    float rAy = sinA * joint->localAnchorAx + cosA * joint->localAnchorAy;
    float rBx = cosB * joint->localAnchorBx - sinB * joint->localAnchorBy;
    float rBy = sinB * joint->localAnchorBx + cosB * joint->localAnchorBy;
    
    float axisx = cosA * joint->prismatic.axisx - sinA * joint->prismatic.axisy;
    float axisy = sinA * joint->prismatic.axisx + cosA * joint->prismatic.axisy;
    
    float perpx = -axisy;
    float perpy = axisx;
    
    // Position error perpendicular to axis
    float dx = (bodyB->x + rBx) - (bodyA->x + rAx);
    float dy = (bodyB->y + rBy) - (bodyA->y + rAy);
    float CPerp = dx * perpx + dy * perpy;
    
    // Clamp
    if (CPerp > 0.2f) CPerp = 0.2f;
    if (CPerp < -0.2f) CPerp = -0.2f;
    
    // Solve perpendicular constraint
    float raCrossPerp = rAx * perpy - rAy * perpx;
    float rbCrossPerp = rBx * perpy - rBy * perpx;
    float kPerp = bodyA->inverseMass + bodyB->inverseMass +
                  raCrossPerp * raCrossPerp * bodyA->inverseInertia +
                  rbCrossPerp * rbCrossPerp * bodyB->inverseInertia;
    
    if (kPerp > 0.0f) {
        float impulse = -CPerp / kPerp;
        float Px = impulse * perpx;
        float Py = impulse * perpy;
        
        if (bodyA->type == DYNAMIC) {
            bodyA->x -= Px * bodyA->inverseMass;
            bodyA->y -= Py * bodyA->inverseMass;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->x += Px * bodyB->inverseMass;
            bodyB->y += Py * bodyB->inverseMass;
        }
    }
}

// Weld joint velocity solver
void solve_weld_joint_velocity(Joint* joint, PhysicsWorld* world) {
    NativeBody* bodyA = get_body(world, joint->bodyA);
    NativeBody* bodyB = get_body(world, joint->bodyB);
    
    if (!bodyA || !bodyB) return;
    
    // Rotate anchors
    float cosA = std::cos(bodyA->rotation);
    float sinA = std::sin(bodyA->rotation);
    float cosB = std::cos(bodyB->rotation);
    float sinB = std::sin(bodyB->rotation);
    
    float rAx = cosA * joint->localAnchorAx - sinA * joint->localAnchorAy;
    float rAy = sinA * joint->localAnchorAx + cosA * joint->localAnchorAy;
    float rBx = cosB * joint->localAnchorBx - sinB * joint->localAnchorBy;
    float rBy = sinB * joint->localAnchorBx + cosB * joint->localAnchorBy;
    
    // Linear constraint (point-to-point)
    float vAx = bodyA->vx + (-bodyA->angularVelocity * rAy);
    float vAy = bodyA->vy + (bodyA->angularVelocity * rAx);
    float vBx = bodyB->vx + (-bodyB->angularVelocity * rBy);
    float vBy = bodyB->vy + (bodyB->angularVelocity * rBx);
    
    float dvx = vBx - vAx;
    float dvy = vBy - vAy;
    
    // Effective mass matrix for linear constraint
    float k11 = bodyA->inverseMass + bodyB->inverseMass + 
                rAy * rAy * bodyA->inverseInertia + rBy * rBy * bodyB->inverseInertia;
    float k22 = bodyA->inverseMass + bodyB->inverseMass + 
                rAx * rAx * bodyA->inverseInertia + rBx * rBx * bodyB->inverseInertia;
    float k12 = -rAy * rAx * bodyA->inverseInertia - rBy * rBx * bodyB->inverseInertia;
    
    float det = k11 * k22 - k12 * k12;
    if (det > 0.0f) {
        det = 1.0f / det;
        float lambdaX = -det * (k22 * dvx - k12 * dvy);
        float lambdaY = -det * (k11 * dvy - k12 * dvx);
        
        joint->weld.impulseX += lambdaX;
        joint->weld.impulseY += lambdaY;
        
        if (bodyA->type == DYNAMIC) {
            bodyA->vx -= lambdaX * bodyA->inverseMass;
            bodyA->vy -= lambdaY * bodyA->inverseMass;
            bodyA->angularVelocity -= (rAx * lambdaY - rAy * lambdaX) * bodyA->inverseInertia;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->vx += lambdaX * bodyB->inverseMass;
            bodyB->vy += lambdaY * bodyB->inverseMass;
            bodyB->angularVelocity += (rBx * lambdaY - rBy * lambdaX) * bodyB->inverseInertia;
        }
    }
    
    // Angular constraint (keep same rotation)
    float angularVel = bodyB->angularVelocity - bodyA->angularVelocity;
    float kAngular = bodyA->inverseInertia + bodyB->inverseInertia;
    
    if (kAngular > 0.0f) {
        float lambdaAngular = -angularVel / kAngular;
        joint->weld.angularImpulse += lambdaAngular;
        
        if (bodyA->type == DYNAMIC) {
            bodyA->angularVelocity -= lambdaAngular * bodyA->inverseInertia;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->angularVelocity += lambdaAngular * bodyB->inverseInertia;
        }
    }
}

void solve_weld_joint_position(Joint* joint, PhysicsWorld* world) {
    NativeBody* bodyA = get_body(world, joint->bodyA);
    NativeBody* bodyB = get_body(world, joint->bodyB);
    
    if (!bodyA || !bodyB) return;
    
    // Rotate anchors
    float cosA = std::cos(bodyA->rotation);
    float sinA = std::sin(bodyA->rotation);
    float cosB = std::cos(bodyB->rotation);
    float sinB = std::sin(bodyB->rotation);
    
    float rAx = cosA * joint->localAnchorAx - sinA * joint->localAnchorAy;
    float rAy = sinA * joint->localAnchorAx + cosA * joint->localAnchorAy;
    float rBx = cosB * joint->localAnchorBx - sinB * joint->localAnchorBy;
    float rBy = sinB * joint->localAnchorBx + cosB * joint->localAnchorBy;
    
    // Linear position error
    float Cx = (bodyB->x + rBx) - (bodyA->x + rAx);
    float Cy = (bodyB->y + rBy) - (bodyA->y + rAy);
    
    // Clamp
    float length = std::sqrt(Cx * Cx + Cy * Cy);
    if (length > 0.2f) {
        Cx *= 0.2f / length;
        Cy *= 0.2f / length;
    }
    
    // Solve linear constraint
    float k11 = bodyA->inverseMass + bodyB->inverseMass + 
                rAy * rAy * bodyA->inverseInertia + rBy * rBy * bodyB->inverseInertia;
    float k22 = bodyA->inverseMass + bodyB->inverseMass + 
                rAx * rAx * bodyA->inverseInertia + rBx * rBx * bodyB->inverseInertia;
    float k12 = -rAy * rAx * bodyA->inverseInertia - rBy * rBx * bodyB->inverseInertia;
    
    float det = k11 * k22 - k12 * k12;
    if (det > 0.0f) {
        det = 1.0f / det;
        float impulseX = -det * (k22 * Cx - k12 * Cy);
        float impulseY = -det * (k11 * Cy - k12 * Cx);
        
        if (bodyA->type == DYNAMIC) {
            bodyA->x -= impulseX * bodyA->inverseMass;
            bodyA->y -= impulseY * bodyA->inverseMass;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->x += impulseX * bodyB->inverseMass;
            bodyB->y += impulseY * bodyB->inverseMass;
        }
    }
    
    // Angular position error
    float angleError = bodyB->rotation - bodyA->rotation;
    
    // Normalize to [-PI, PI]
    const float PI = 3.14159265359f;
    while (angleError > PI) angleError -= 2.0f * PI;
    while (angleError < -PI) angleError += 2.0f * PI;
    
    // Clamp
    if (angleError > 0.2f) angleError = 0.2f;
    if (angleError < -0.2f) angleError = -0.2f;
    
    // Solve angular constraint
    float kAngular = bodyA->inverseInertia + bodyB->inverseInertia;
    if (kAngular > 0.0f) {
        float angularImpulse = -angleError / kAngular;
        
        if (bodyA->type == DYNAMIC) {
            bodyA->rotation -= angularImpulse * bodyA->inverseInertia;
        }
        if (bodyB->type == DYNAMIC) {
            bodyB->rotation += angularImpulse * bodyB->inverseInertia;
        }
    }
}

}
