#ifndef FLASH_PARTICLES_H
#define FLASH_PARTICLES_H

#include <cstdint>
#include "flash_export.h"

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

// Everything an emission burst needs, so N particles cost one FFI call
// instead of N. Randomisation and the spread rotation happen on this side —
// they were being done per particle in Dart, which meant several allocations
// and a full FFI crossing for every single particle spawned.
struct EmitParams {
    float originX, originY, originZ;

    float velMinX, velMinY, velMinZ;
    float velMaxX, velMaxY, velMaxZ;

    float lifetimeMin, lifetimeMax;
    float sizeMin, sizeMax;

    float spreadAngle;   // radians; 0 disables the spread rotation entirely
    uint32_t color;
};

// Functions exported to Dart via FFI
FLASH_API void update_particles(ParticleEmitter* emitter, float dt);

/// Spawns up to [count] particles in one call. Returns how many were created
/// (fewer if the emitter filled up). [seed] advances the internal RNG so the
/// caller can reproduce a sequence.
FLASH_API int emit_particles(ParticleEmitter* emitter, const EmitParams* params, int count, uint32_t seed);
/// Particle count at or above which the vertex fill runs across the thread
/// pool. Exposed so a benchmark can measure both paths on identical input.
/// Returns the previous threshold.
FLASH_API int set_particle_parallel_threshold(int threshold);

/// How many threads a pool dispatch runs across, including the caller.
FLASH_API int particle_pool_concurrency();

FLASH_API int fill_vertex_buffer(ParticleEmitter* emitter, float* matrix, float* vertices, uint32_t* colors, int maxRenderCount);

}

#endif // FLASH_PARTICLES_H
