#include "broadphase.h"
#include "physics.h"
#include <cmath>
#include <algorithm>

extern "C" {

SpatialHashGrid* create_spatial_grid(float worldMinX, float worldMinY, 
                                     float worldMaxX, float worldMaxY, 
                                     float cellSize) {
    SpatialHashGrid* grid = new SpatialHashGrid();
    
    grid->worldMinX = worldMinX;
    grid->worldMinY = worldMinY;
    grid->worldMaxX = worldMaxX;
    grid->worldMaxY = worldMaxY;
    grid->cellSize = cellSize;
    
    grid->gridWidth = (int)std::ceil((worldMaxX - worldMinX) / cellSize);
    grid->gridHeight = (int)std::ceil((worldMaxY - worldMinY) / cellSize);
    
    int totalCells = grid->gridWidth * grid->gridHeight;
    grid->cells = new GridCell[totalCells];
    
    return grid;
}

void destroy_spatial_grid(SpatialHashGrid* grid) {
    if (!grid) return;
    delete[] grid->cells;
    delete grid;
}

void clear_spatial_grid(SpatialHashGrid* grid) {
    if (!grid) return;
    
    int totalCells = grid->gridWidth * grid->gridHeight;
    for (int i = 0; i < totalCells; ++i) {
        grid->cells[i].bodyIds.clear();
    }
    grid->pairs.clear();
}

// Hash function for pair caching
inline uint64_t make_pair_key(uint32_t a, uint32_t b) {
    if (a > b) std::swap(a, b);
    return ((uint64_t)a << 32) | b;
}

void insert_into_grid(SpatialHashGrid* grid, uint32_t bodyId, const AABB& aabb) {
    if (!grid) return;
    
    // Calculate grid cell range that AABB overlaps
    int minCellX = (int)std::floor((aabb.minX - grid->worldMinX) / grid->cellSize);
    int minCellY = (int)std::floor((aabb.minY - grid->worldMinY) / grid->cellSize);
    int maxCellX = (int)std::floor((aabb.maxX - grid->worldMinX) / grid->cellSize);
    int maxCellY = (int)std::floor((aabb.maxY - grid->worldMinY) / grid->cellSize);
    
    // Clamp to grid bounds
    minCellX = std::max(0, std::min(minCellX, grid->gridWidth - 1));
    minCellY = std::max(0, std::min(minCellY, grid->gridHeight - 1));
    maxCellX = std::max(0, std::min(maxCellX, grid->gridWidth - 1));
    maxCellY = std::max(0, std::min(maxCellY, grid->gridHeight - 1));
    
    // Insert body into all overlapping cells
    for (int y = minCellY; y <= maxCellY; ++y) {
        for (int x = minCellX; x <= maxCellX; ++x) {
            int cellIndex = y * grid->gridWidth + x;
            grid->cells[cellIndex].bodyIds.push_back(bodyId);
        }
    }
}

int query_grid_pairs(SpatialHashGrid* grid, BroadphasePair* outPairs, int maxPairs) {
    if (!grid) return 0;
    
    int pairCount = 0;
    int totalCells = grid->gridWidth * grid->gridHeight;
    
    // For each cell, check all pairs of bodies in that cell
    for (int i = 0; i < totalCells && pairCount < maxPairs; ++i) {
        const auto& bodyIds = grid->cells[i].bodyIds;
        
        for (size_t j = 0; j < bodyIds.size() && pairCount < maxPairs; ++j) {
            for (size_t k = j + 1; k < bodyIds.size() && pairCount < maxPairs; ++k) {
                uint32_t bodyA = bodyIds[j];
                uint32_t bodyB = bodyIds[k];
                
                // Check if we've already added this pair
                uint64_t pairKey = make_pair_key(bodyA, bodyB);
                
                bool alreadyAdded = false;
                for (uint64_t existingKey : grid->pairs) {
                    if (existingKey == pairKey) {
                        alreadyAdded = true;
                        break;
                    }
                }
                
                if (!alreadyAdded) {
                    grid->pairs.push_back(pairKey);
                    outPairs[pairCount].bodyA = bodyA;
                    outPairs[pairCount].bodyB = bodyB;
                    pairCount++;
                }
            }
        }
    }
    
    return pairCount;
}

AABB calculate_body_aabb(const NativeBody& body) {
    AABB aabb;
    
    if (body.shapeType == SHAPE_CIRCLE) {
        aabb.minX = body.x - body.radius;
        aabb.minY = body.y - body.radius;
        aabb.maxX = body.x + body.radius;
        aabb.maxY = body.y + body.radius;
    } else {
        // Box - need to account for rotation
        float hw = body.width * 0.5f;
        float hh = body.height * 0.5f;
        float c = std::cos(body.rotation);
        float s = std::sin(body.rotation);
        
        // Calculate rotated corners
        float corners[4][2] = {
            {-hw * c - (-hh) * s, -hw * s + (-hh) * c},
            { hw * c - (-hh) * s,  hw * s + (-hh) * c},
            { hw * c -   hh  * s,  hw * s +   hh  * c},
            {-hw * c -   hh  * s, -hw * s +   hh  * c}
        };
        
        // Find min/max
        aabb.minX = aabb.maxX = body.x + corners[0][0];
        aabb.minY = aabb.maxY = body.y + corners[0][1];
        
        for (int i = 1; i < 4; ++i) {
            float x = body.x + corners[i][0];
            float y = body.y + corners[i][1];
            aabb.minX = std::min(aabb.minX, x);
            aabb.minY = std::min(aabb.minY, y);
            aabb.maxX = std::max(aabb.maxX, x);
            aabb.maxY = std::max(aabb.maxY, y);
        }
    }
    
    // Fatten AABB slightly for temporal coherence
    aabb.fatten(2.0f);
    
    return aabb;
}

}
