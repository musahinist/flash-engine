#include "particles.h"
#include <thread>
#include <vector>
#include <algorithm>

extern "C" {

void update_particles(ParticleEmitter* emitter, float dt) {
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

void spawn_particle(ParticleEmitter* emitter, float x, float y, float z, float vx, float vy, float vz, float maxLife, float size, uint32_t color) {
    if (!emitter || !emitter->particles || emitter->activeCount >= emitter->maxParticles) return;

    NativeParticle& p = emitter->particles[emitter->activeCount++];
    p.x = x; p.y = y; p.z = z;
    p.vx = vx; p.vy = vy; p.vz = vz;
    p.life = 1.0f;
    p.maxLife = maxLife;
    p.size = size;
    p.color = color;
}

struct ThreadWork {
    int startIdx;
    int endIdx;
    int visibleCount;
    std::vector<int> visibleIndices;
};

void fill_chunk_pass1(ParticleEmitter* emitter, float* m, ThreadWork& work) {
    work.visibleCount = 0;
    work.visibleIndices.clear();
    work.visibleIndices.reserve(work.endIdx - work.startIdx);

    for (int i = work.startIdx; i < work.endIdx; ++i) {
        NativeParticle& p = emitter->particles[i];
        float wz = p.x * m[3] + p.y * m[7] + p.z * m[11] + m[15];
        if (wz >= 0.1f) {
            work.visibleIndices.push_back(i);
            work.visibleCount++;
        }
    }
}

void fill_chunk_pass2(ParticleEmitter* emitter, float* m, float* vertices, uint32_t* colors, const ThreadWork& work, int globalOffset) {
    int vPtr = globalOffset * 6 * 2; // 6 vertices per particle
    int cPtr = globalOffset * 6;     // 6 colors per particle

    for (int idx : work.visibleIndices) {
        NativeParticle& p = emitter->particles[idx];
        float wz = p.x * m[3] + p.y * m[7] + p.z * m[11] + m[15];
        float invW = 1.0f / wz;
        float screenX = (p.x * m[0] + p.y * m[4] + p.z * m[8] + m[12]) * invW;
        float screenY = (p.x * m[1] + p.y * m[5] + p.z * m[9] + m[13]) * invW;
        
        float halfSize = (p.size * p.life * invW * 500.0f);
        if (halfSize < 0.2f) halfSize = 0.2f;
        if (halfSize > 50.0f) halfSize = 50.0f;
        
        uint32_t alpha = (uint32_t)(p.life * 255.0f);
        uint32_t col = (p.color & 0x00FFFFFF) | (alpha << 24);

        // Quad Geometry (2 triangles: 0-1-2 and 0-2-3)
        float qx[] = {-1.0f, 1.0f, 1.0f, -1.0f};
        float qy[] = {-1.0f, -1.0f, 1.0f, 1.0f};

        // Vertices (6 vertices to form a quad via 2 triangles)
        vertices[vPtr++] = screenX + qx[0] * halfSize; vertices[vPtr++] = screenY + qy[0] * halfSize;
        vertices[vPtr++] = screenX + qx[1] * halfSize; vertices[vPtr++] = screenY + qy[1] * halfSize;
        vertices[vPtr++] = screenX + qx[2] * halfSize; vertices[vPtr++] = screenY + qy[2] * halfSize;
        
        vertices[vPtr++] = screenX + qx[0] * halfSize; vertices[vPtr++] = screenY + qy[0] * halfSize;
        vertices[vPtr++] = screenX + qx[2] * halfSize; vertices[vPtr++] = screenY + qy[2] * halfSize;
        vertices[vPtr++] = screenX + qx[3] * halfSize; vertices[vPtr++] = screenY + qy[3] * halfSize;

        for (int i = 0; i < 6; ++i) colors[cPtr++] = col;
    }
}

int fill_vertex_buffer(ParticleEmitter* emitter, float* m, float* vertices, uint32_t* colors, int maxRenderCount) {
    if (!emitter || !emitter->particles || emitter->activeCount == 0) return 0;

    int totalToProcess = std::min(emitter->activeCount, maxRenderCount);
    unsigned int numThreads = std::min((unsigned int)8, std::thread::hardware_concurrency());
    if (numThreads < 1) numThreads = 1;
    if (totalToProcess < 1000) numThreads = 1;

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
