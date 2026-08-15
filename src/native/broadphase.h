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

// Node for the dynamic AABB tree
struct TreeNode {
    AABB aabb;
    uint32_t bodyId; // 0xFFFFFFFF if internal node
    int32_t parent;
    int32_t left;
    int32_t right;
    int32_t height; // For AVL balancing
    int32_t next;   // For free list
    
    bool isLeaf() const { return right == -1; }
};

// Dynamic AABB Tree structure
struct DynamicTree {
    TreeNode* nodes;
    int32_t root;
    int32_t nodeCount;
    int32_t nodeCapacity;
    int32_t freeList;
    
    // Pair cache to avoid duplicate collision checks
    std::vector<uint64_t> pairs;
};

// Broadphase pair (two bodies that might be colliding)
struct BroadphasePair {
    uint32_t bodyA;
    uint32_t bodyB;
};

// Create dynamic tree
DynamicTree* create_dynamic_tree(int initialCapacity);

// Destroy dynamic tree
void destroy_dynamic_tree(DynamicTree* tree);

// Insert a body into the tree and return a proxy ID
int32_t tree_insert_leaf(DynamicTree* tree, uint32_t bodyId, const AABB& aabb);

// Remove a leaf from the tree
void tree_remove_leaf(DynamicTree* tree, int32_t proxyId);

// Update a leaf (move/resize)
int32_t tree_update_leaf(DynamicTree* tree, int32_t proxyId, const AABB& aabb);

// Query tree for potential collision pairs against all bodies
int query_tree_pairs(DynamicTree* tree, BroadphasePair* outPairs, int maxPairs);

// Bodies whose fat AABB overlaps `box`. Returns how many ids were written,
// clamped to maxResults.
//
// The tree existed only to build the pair list; everything else that needed a
// spatial lookup — raycasts, soft body contacts — walked all bodies instead.
int tree_query_aabb(DynamicTree* tree, const AABB& box, uint32_t* outBodyIds, int maxResults);

// Bodies whose fat AABB the segment (x0,y0)->(x1,y1) passes through. Broad
// phase only: the caller still runs the exact shape test on each candidate.
int tree_query_ray(DynamicTree* tree, float x0, float y0, float x1, float y1,
                   uint32_t* outBodyIds, int maxResults);

// Helper: Calculate AABB for a body
AABB calculate_body_aabb(const struct NativeBody& body);

}

#endif
