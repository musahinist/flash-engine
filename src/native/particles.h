#ifndef FLASH_PARTICLES_H
#define FLASH_PARTICLES_H

#include <cstdint>

extern "C" {

struct NativeParticle {
    float x, y, z;
    float vx, vy, vz;
    float life;    // Remaining life (0 to 1)
    float maxLife; // Initial max life in seconds
    float size;
    uint32_t color;
};

struct ParticleEmitter {
    NativeParticle* particles;
    int maxParticles;
    int activeCount;
    
    float gravityX, gravityY, gravityZ;
    int shapeType; // 0 = Quad, 1 = Hexagon, 2 = Octagon
};

// Functions exported to Dart via FFI
void update_particles(ParticleEmitter* emitter, float dt);
void spawn_particle(ParticleEmitter* emitter, float x, float y, float z, float vx, float vy, float vz, float maxLife, float size, uint32_t color);
int fill_vertex_buffer(ParticleEmitter* emitter, float* matrix, float* vertices, uint32_t* colors, int maxRenderCount);

}

#endif // FLASH_PARTICLES_H
