#ifndef FLASH_BROADPHASE_H
#define FLASH_BROADPHASE_H

#include <stdint.h>
#include <vector>

extern "C" {

// AABB (Axis-Aligned Bounding Box) for broadphase
struct AABB {
    float minX, minY;
    float maxX, maxY;
    
    bool overlaps(const AABB& other) const {
        return !(maxX < other.minX || minX > other.maxX ||
                 maxY < other.minY || minY > other.maxY);
    }
    
    void fatten(float amount) {
        minX -= amount;
        minY -= amount;
        maxX += amount;
        maxY += amount;
    }
};

// Spatial hash grid cell
struct GridCell {
    std::vector<uint32_t> bodyIds;
};

// Spatial hash grid for broadphase collision detection
struct SpatialHashGrid {
    GridCell* cells;
    int gridWidth;
    int gridHeight;
    float cellSize;
    float worldMinX, worldMinY;
    float worldMaxX, worldMaxY;
    
    // Pair cache to avoid duplicate collision checks
    std::vector<uint64_t> pairs;
};

// Broadphase pair (two bodies that might be colliding)
struct BroadphasePair {
    uint32_t bodyA;
    uint32_t bodyB;
};

// Create spatial hash grid
SpatialHashGrid* create_spatial_grid(float worldMinX, float worldMinY, 
                                     float worldMaxX, float worldMaxY, 
                                     float cellSize);

// Destroy spatial hash grid
void destroy_spatial_grid(SpatialHashGrid* grid);

// Clear grid for new frame
void clear_spatial_grid(SpatialHashGrid* grid);

// Insert body into grid
void insert_into_grid(SpatialHashGrid* grid, uint32_t bodyId, const AABB& aabb);

// Query grid for potential collision pairs
int query_grid_pairs(SpatialHashGrid* grid, BroadphasePair* outPairs, int maxPairs);

// Helper: Calculate AABB for a body
AABB calculate_body_aabb(const struct NativeBody& body);

}

#endif
