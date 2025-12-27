#include <iostream>
#include <cassert>
#include <vector>
#include "physics.h"
#include "joints.h"

// Simple assertion helper
void assert_true(bool condition, const char* message) {
    if (!condition) {
        std::cerr << "❌ FAIL: " << message << std::endl;
        exit(1);
    } else {
        std::cout << "✅ PASS: " << message << std::endl;
    }
}

// Test 1: World Creation and Gravity
void test_gravity() {
    std::cout << "\n--- Testing Gravity ---" << std::endl;
    PhysicsWorld* world = create_physics_world(10);
    
    // Create a dynamic body
    int bodyId = create_body(world, DYNAMIC, SHAPE_CIRCLE, 0, 0, 10, 10, 0);
    NativeBody* body = &world->bodies[bodyId];
    
    // Verify initial state
    assert_true(body->vy == 0, "Initial velocity is 0");
    
    // Step physics
    step_physics(world, 1.0f / 60.0f);
    
    // Check if gravity applied (Y-Up system: Gravity is -9.8, so vy should be negative)
    // Default C++ gravityY is now -981.0f.
    // v = a*t = -981 * 0.016 = -16.35
    std::cout << "Velocity Y after step: " << body->vy << std::endl;
    assert_true(body->vy < 0, "Body should fall downwards (Negative Y)");
    
    destroy_physics_world(world);
}

// Test 2: Collisions
void test_collision() {
    std::cout << "\n--- Testing Collision ---" << std::endl;
    PhysicsWorld* world = create_physics_world(10);
    
    // Ground (Static) at Y= -100
    create_body(world, STATIC, SHAPE_BOX, 0, -100, 1000, 20, 0);
    
    // Ball (Dynamic) at Y= 0 (falling down to -100)
    int ballId = create_body(world, DYNAMIC, SHAPE_CIRCLE, 0, 0, 10, 10, 0);
    
    // Step for 2 seconds
    for(int i=0; i<120; ++i) {
        step_physics(world, 1.0f/60.0f);
    }
    
    NativeBody* ball = &world->bodies[ballId];
    std::cout << "Ball Y position: " << ball->y << std::endl;
    
    // Ball should stop on ground: Ground Y=-100 + HalfHeight=10 = -90. Ball radius=5.
    // So Ball Y should be around -85.
    assert_true(ball->y > -100.0f, "Ball should be above ground center");
    assert_true(ball->vy > -10.0f && ball->vy < 10.0f, "Ball should have stopped/bounced");
    
    destroy_physics_world(world);
}

int main() {
    std::cout << "🚀 Running Native Physics Tests..." << std::endl;
    test_gravity();
    test_collision();
    std::cout << "\n🎉 All Tests Passed!" << std::endl;
    return 0;
}
