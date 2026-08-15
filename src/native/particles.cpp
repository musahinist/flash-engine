#include "particles.h"
#include <thread>
#include <vector>
#include <algorithm>

extern "C" {

FLASH_API void update_particles(ParticleEmitter* emitter, float dt) {
    if (!emitter || !emitter->particles) return;

    for (int i = emitter->activeCount - 1; i >= 0; --i) {
        NativeParticle& p = emitter->particles[i];

        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.z += p.vz * dt;

        p.vx += emitter->gravityX * dt;
        p.vy += emitter->gravityY * dt;
        p.vz += emitter->gravityZ * dt;

        p.life -= dt / p.maxLife;

        if (p.life <= 0) {
            if (i < emitter->activeCount - 1) {
                emitter->particles[i] = emitter->particles[emitter->activeCount - 1];
            }
            emitter->activeCount--;
        }
    }
}

FLASH_API void spawn_particle(ParticleEmitter* emitter, float x, float y, float z, float vx, float vy, float vz, float maxLife, float size, uint32_t color) {
    if (!emitter || !emitter->particles || emitter->activeCount >= emitter->maxParticles) return;

    NativeParticle& p = emitter->particles[emitter->activeCount++];
    p.x = x; p.y = y; p.z = z;
    p.vx = vx; p.vy = vy; p.vz = vz;
    p.life = 1.0f;
    p.maxLife = maxLife;
    p.size = size;
    p.color = color;
}

// xorshift32: cheap, deterministic, and good enough for scattering particles.
// The alternative was calling back into Dart's Random per particle.
static inline uint32_t next_random(uint32_t& state) {
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return state;
}

static inline float random_range(uint32_t& state, float lo, float hi) {
    // 24 bits of mantissa is ample and avoids the bias of a modulo.
    const float unit = (next_random(state) >> 8) * (1.0f / 16777216.0f);
    return lo + unit * (hi - lo);
}

FLASH_API int emit_particles(ParticleEmitter* emitter, const EmitParams* params, int count, uint32_t seed) {
    if (!emitter || !emitter->particles || !params || count <= 0) return 0;

    const int room = emitter->maxParticles - emitter->activeCount;
    if (room <= 0) return 0;
    if (count > room) count = room;

    uint32_t state = seed ? seed : 0x9E3779B9u;

    for (int i = 0; i < count; ++i) {
        NativeParticle& p = emitter->particles[emitter->activeCount++];

        p.x = params->originX;
        p.y = params->originY;
        p.z = params->originZ;

        float vx = random_range(state, params->velMinX, params->velMaxX);
        float vy = random_range(state, params->velMinY, params->velMaxY);
        float vz = random_range(state, params->velMinZ, params->velMaxZ);

        if (params->spreadAngle > 0.0f) {
            // Same two rotations Dart was applying: about X, then about Z.
            const float ax = random_range(state, -params->spreadAngle, params->spreadAngle);
            const float az = random_range(state, -params->spreadAngle, params->spreadAngle);

            const float cx = cosf(ax), sx = sinf(ax);
            const float ty = vy * cx - vz * sx;
            const float tz = vy * sx + vz * cx;
            vy = ty; vz = tz;

            const float cz = cosf(az), sz = sinf(az);
            const float tx2 = vx * cz - vy * sz;
            const float ty2 = vx * sz + vy * cz;
            vx = tx2; vy = ty2;
        }

        p.vx = vx; p.vy = vy; p.vz = vz;
        p.life = 1.0f;
        p.maxLife = random_range(state, params->lifetimeMin, params->lifetimeMax);
        p.size = random_range(state, params->sizeMin, params->sizeMax);
        p.color = params->color;
    }

    return count;
}

struct ThreadWork {
    int startIdx;
    int endIdx;
    int visibleCount;
    std::vector<int> visibleIndices;
    // 1/w carried from pass1 so pass2 does not recompute the projection depth.
    std::vector<float> visibleInvW;
};

// Unit polygon for a shape, in screen space. The corner angles do not depend
// on the particle, so recomputing cosf/sinf per particle per corner was pure
// waste: at 10k particles with 12 sides that is 240,000 trig calls a frame for
// twelve constant values.
struct UnitPolygon {
    float cx[12];
    float cy[12];
    int sides;
};

static UnitPolygon make_unit_polygon(int shapeType) {
    UnitPolygon poly;
    poly.sides = 4;
    if (shapeType == 1) poly.sides = 6;
    else if (shapeType == 2) poly.sides = 8;
    else if (shapeType == 3) poly.sides = 12;
    else if (shapeType == 4) poly.sides = 3;

    for (int i = 0; i < poly.sides; ++i) {
        const float angle = i * (2.0f * (float)M_PI / poly.sides);
        poly.cx[i] = cosf(angle);
        poly.cy[i] = sinf(angle);
    }
    return poly;
}

void fill_chunk_pass1(ParticleEmitter* emitter, float* m, ThreadWork& work) {
    work.visibleCount = 0;
    work.visibleIndices.clear();
    work.visibleInvW.clear();
    work.visibleIndices.reserve(work.endIdx - work.startIdx);
    work.visibleInvW.reserve(work.endIdx - work.startIdx);

    for (int i = work.startIdx; i < work.endIdx; ++i) {
        NativeParticle& p = emitter->particles[i];
        float wz = p.x * m[3] + p.y * m[7] + p.z * m[11] + m[15];
        if (wz >= 0.1f) {
            work.visibleIndices.push_back(i);
            // Carried forward so pass2 does not redo the same four multiplies.
            work.visibleInvW.push_back(1.0f / wz);
            work.visibleCount++;
        }
    }
}

void fill_chunk_pass2(ParticleEmitter* emitter, float* m, float* vertices, uint32_t* colors, const ThreadWork& work, int globalOffset) {
    const UnitPolygon poly = make_unit_polygon(emitter->shapeType);
    const int sides = poly.sides;

    int triCount = sides - 2;
    int vCount = triCount * 3;

    int vPtr = globalOffset * vCount * 2;
    int cPtr = globalOffset * vCount;

    for (size_t n = 0; n < work.visibleIndices.size(); ++n) {
        const int idx = work.visibleIndices[n];
        NativeParticle& p = emitter->particles[idx];
        const float invW = work.visibleInvW[n];
        float screenX = (p.x * m[0] + p.y * m[4] + p.z * m[8] + m[12]) * invW;
        float screenY = (p.x * m[1] + p.y * m[5] + p.z * m[9] + m[13]) * invW;
        
        float halfSize = (p.size * p.life * invW * 500.0f);
        if (halfSize < 0.2f) halfSize = 0.2f;
        if (halfSize > 50.0f) halfSize = 50.0f;
        
        uint32_t alpha = (uint32_t)(p.life * 255.0f);
        uint32_t col = (p.color & 0x00FFFFFF) | (alpha << 24);

        // Scale and offset the precomputed unit polygon.
        float px[12], py[12];
        for (int i = 0; i < sides; ++i) {
            px[i] = screenX + poly.cx[i] * halfSize;
            py[i] = screenY + poly.cy[i] * halfSize;
        }

        // Fan-out triangles (0-i-(i+1))
        for (int i = 1; i < sides - 1; ++i) {
            vertices[vPtr++] = px[0]; vertices[vPtr++] = py[0];
            vertices[vPtr++] = px[i]; vertices[vPtr++] = py[i];
            vertices[vPtr++] = px[i+1]; vertices[vPtr++] = py[i+1];
        }

        for (int i = 0; i < vCount; ++i) colors[cPtr++] = col;
    }
}

FLASH_API int fill_vertex_buffer(ParticleEmitter* emitter, float* m, float* vertices, uint32_t* colors, int maxRenderCount) {
    if (!emitter || !emitter->particles || emitter->activeCount == 0) return 0;

    int totalToProcess = std::min(emitter->activeCount, maxRenderCount);
    
    // Performance optimization: Avoid thread-spawning overhead for small-medium counts.
    // std::thread is expensive to create every frame. 
    // Single-threaded is often faster for up to 100k particles on modern CPUs.
    if (totalToProcess < 100000) {
        ThreadWork work;
        work.startIdx = 0;
        work.endIdx = totalToProcess;
        fill_chunk_pass1(emitter, m, work);
        if (work.visibleCount > 0) {
            fill_chunk_pass2(emitter, m, vertices, colors, work, 0);
        }
        return work.visibleCount;
    }

    unsigned int numThreads = std::min((unsigned int)4, std::thread::hardware_concurrency());
    if (numThreads < 1) numThreads = 1;

    std::vector<ThreadWork> works(numThreads);
    std::vector<std::thread> threads;
    int chunkSize = totalToProcess / numThreads;

    for (unsigned int t = 0; t < numThreads; ++t) {
        works[t].startIdx = t * chunkSize;
        works[t].endIdx = (t == numThreads - 1) ? totalToProcess : (t + 1) * chunkSize;
        threads.emplace_back(fill_chunk_pass1, emitter, m, std::ref(works[t]));
    }
    for (auto& t : threads) t.join();
    threads.clear();

    int totalVisible = 0;
    std::vector<int> offsets(numThreads);
    for (unsigned int t = 0; t < numThreads; ++t) {
        offsets[t] = totalVisible;
        totalVisible += works[t].visibleCount;
    }

    if (totalVisible == 0) return 0;

    for (unsigned int t = 0; t < numThreads; ++t) {
        if (works[t].visibleCount > 0) {
            threads.emplace_back(fill_chunk_pass2, emitter, m, vertices, colors, std::ref(works[t]), offsets[t]);
        }
    }
    for (auto& t : threads) t.join();

    return totalVisible;
}

}
