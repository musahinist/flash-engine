#ifndef FLASH_JOINTS_H
#define FLASH_JOINTS_H

#include <stdint.h>

extern "C" {

// Joint types
enum JointType {
    DISTANCE_JOINT = 0,   // Rope/spring - maintains distance
    REVOLUTE_JOINT = 1,   // Hinge/pivot - rotates around point
    PRISMATIC_JOINT = 2,  // Slider - moves along axis
    WELD_JOINT = 3        // Fixed - rigid connection
};

// Joint definition for creation
struct JointDef {
    JointType type;
    uint32_t bodyA;
    uint32_t bodyB;
    
    // Anchor points (local coordinates relative to body centers)
    float anchorAx, anchorAy;
    float anchorBx, anchorBy;
    
    // Distance joint parameters
    float length;           // Target distance
    float frequency;        // Spring frequency (Hz)
    float dampingRatio;     // Damping ratio (0-1)
    
    // Revolute joint parameters
    float referenceAngle;   // Initial angle offset
    int enableLimit;        // Enable angle limits
    float lowerAngle;       // Lower angle limit (radians)
    float upperAngle;       // Upper angle limit (radians)
    int enableMotor;        // Enable motor
    float motorSpeed;       // Target motor speed (rad/s)
    float maxMotorTorque;   // Maximum motor torque
    
    // Prismatic joint parameters
    float axisx, axisy;     // Slide axis (normalized)
    float lowerTranslation; // Lower translation limit
    float upperTranslation; // Upper translation limit
    float maxMotorForce;    // Maximum motor force
    
    // Weld joint parameters
    float stiffness;        // Joint stiffness (0 = rigid, >0 = soft)
    float damping;          // Joint damping
};

// Joint runtime state
struct Joint {
    JointType type;
    uint32_t bodyA;
    uint32_t bodyB;
    
    // Local anchor points
    float localAnchorAx, localAnchorAy;
    float localAnchorBx, localAnchorBy;
    
    // Constraint solver state
    float impulse;          // Accumulated constraint impulse
    float motorImpulse;     // Accumulated motor impulse
    float effectiveMass;    // Cached effective mass
    float bias;             // Position error bias
    
    // Joint-specific parameters
    union {
        struct {
            float length;
            float frequency;
            float dampingRatio;
            float gamma;        // Softness parameter
            float biasCoeff;    // Bias coefficient
        } distance;
        
        struct {
            float referenceAngle;
            int enableLimit;
            float lowerAngle;
            float upperAngle;
            int enableMotor;
            float motorSpeed;
            float maxMotorTorque;
            float angle;        // Current angle
        } revolute;
        
        struct {
            float axisx, axisy;
            float lowerTranslation;
            float upperTranslation;
            int enableLimit;
            int enableMotor;
            float motorSpeed;
            float maxMotorForce;
            float translation;  // Current translation
        } prismatic;
        
        struct {
            float stiffness;
            float damping;
            float gamma;
            float biasCoeff;
            float impulseX, impulseY;  // Linear impulse
            float angularImpulse;      // Angular impulse
        } weld;
    };
};

// Joint management functions
int create_joint(struct PhysicsWorld* world, JointDef* def);
void destroy_joint(struct PhysicsWorld* world, int jointId);
void init_joint_velocity_constraints(struct PhysicsWorld* world, float dt);
void solve_joint_velocity_constraints(struct PhysicsWorld* world);
void solve_joint_position_constraints(struct PhysicsWorld* world);

// Individual joint solvers
void solve_distance_joint_velocity(Joint* joint, struct PhysicsWorld* world);
void solve_revolute_joint_velocity(Joint* joint, struct PhysicsWorld* world);
void solve_prismatic_joint_velocity(Joint* joint, struct PhysicsWorld* world);
void solve_weld_joint_velocity(Joint* joint, struct PhysicsWorld* world);

void solve_distance_joint_position(Joint* joint, struct PhysicsWorld* world);
void solve_revolute_joint_position(Joint* joint, struct PhysicsWorld* world);
void solve_prismatic_joint_position(Joint* joint, struct PhysicsWorld* world);
void solve_weld_joint_position(Joint* joint, struct PhysicsWorld* world);

}

#endif
