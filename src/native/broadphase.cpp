#include "broadphase.h"
#include "physics.h"
#include <cmath>
#include <algorithm>

extern "C" {

// --- Dynamic AABB Tree Implementation ---

namespace {
    // Allocation helper
    int32_t allocate_node(DynamicTree* tree) {
        if (tree->freeList == -1) {
            // Grow capacity
            int32_t oldCapacity = tree->nodeCapacity;
            tree->nodeCapacity *= 2;
            TreeNode* oldNodes = tree->nodes;
            tree->nodes = new TreeNode[tree->nodeCapacity];
            std::copy(oldNodes, oldNodes + oldCapacity, tree->nodes);
            delete[] oldNodes;
            
            // Link new free nodes
            for (int32_t i = oldCapacity; i < tree->nodeCapacity - 1; ++i) {
                tree->nodes[i].next = i + 1;
                tree->nodes[i].height = -1; // -1 indicates free
            }
            tree->nodes[tree->nodeCapacity - 1].next = -1;
            tree->nodes[tree->nodeCapacity - 1].height = -1;
            tree->freeList = oldCapacity;
        }
        
        int32_t nodeId = tree->freeList;
        tree->freeList = tree->nodes[nodeId].next;
        tree->nodes[nodeId].parent = -1;
        tree->nodes[nodeId].left = -1;
        tree->nodes[nodeId].right = -1;
        tree->nodes[nodeId].height = 0;
        tree->nodes[nodeId].bodyId = 0xFFFFFFFF;
        tree->nodeCount++;
        return nodeId;
    }

    void free_node(DynamicTree* tree, int32_t nodeId) {
        tree->nodes[nodeId].next = tree->freeList;
        tree->nodes[nodeId].height = -1;
        tree->freeList = nodeId;
        tree->nodeCount--;
    }

    // AVL Balancing (Box2D implementation)
    int32_t balance(DynamicTree* tree, int32_t iA) {
        if (iA == -1 || tree->nodes[iA].height < 2) return iA;
        
        TreeNode* nodes = tree->nodes;
        int32_t iB = nodes[iA].left;
        int32_t iC = nodes[iA].right;
        
        int32_t balance_factor = nodes[iC].height - nodes[iB].height;
        
        // Rotate C up
        if (balance_factor > 1) {
            int32_t iF = nodes[iC].left;
            int32_t iG = nodes[iC].right;
            
            // Swap A and C
            nodes[iC].left = iA;
            nodes[iC].parent = nodes[iA].parent;
            nodes[iA].parent = iC;
            
            // A's old parent should point to C
            if (nodes[iC].parent != -1) {
                if (nodes[nodes[iC].parent].left == iA) nodes[nodes[iC].parent].left = iC;
                else nodes[nodes[iC].parent].right = iC;
            } else {
                tree->root = iC;
            }
            
            // Rotate
            if (nodes[iF].height > nodes[iG].height) {
                nodes[iC].right = iF;
                nodes[iA].right = iG;
                nodes[iG].parent = iA;
                
                // Update AABBs
                nodes[iA].aabb.minX = std::min(nodes[iB].aabb.minX, nodes[iG].aabb.minX);
                nodes[iA].aabb.minY = std::min(nodes[iB].aabb.minY, nodes[iG].aabb.minY);
                nodes[iA].aabb.maxX = std::max(nodes[iB].aabb.maxX, nodes[iG].aabb.maxX);
                nodes[iA].aabb.maxY = std::max(nodes[iB].aabb.maxY, nodes[iG].aabb.maxY);
                
                nodes[iC].aabb.minX = std::min(nodes[iA].aabb.minX, nodes[iF].aabb.minX);
                nodes[iC].aabb.minY = std::min(nodes[iA].aabb.minY, nodes[iF].aabb.minY);
                nodes[iC].aabb.maxX = std::max(nodes[iA].aabb.maxX, nodes[iF].aabb.maxX);
                nodes[iC].aabb.maxY = std::max(nodes[iA].aabb.maxY, nodes[iF].aabb.maxY);
                
                nodes[iA].height = 1 + std::max(nodes[iB].height, nodes[iG].height);
                nodes[iC].height = 1 + std::max(nodes[iA].height, nodes[iF].height);
            } else {
                nodes[iC].right = iG;
                nodes[iA].right = iF;
                nodes[iF].parent = iA;
                
                nodes[iA].aabb.minX = std::min(nodes[iB].aabb.minX, nodes[iF].aabb.minX);
                nodes[iA].aabb.minY = std::min(nodes[iB].aabb.minY, nodes[iF].aabb.minY);
                nodes[iA].aabb.maxX = std::max(nodes[iB].aabb.maxX, nodes[iF].aabb.maxX);
                nodes[iA].aabb.maxY = std::max(nodes[iB].aabb.maxY, nodes[iF].aabb.maxY);
                
                nodes[iC].aabb.minX = std::min(nodes[iA].aabb.minX, nodes[iG].aabb.minX);
                nodes[iC].aabb.minY = std::min(nodes[iA].aabb.minY, nodes[iG].aabb.minY);
                nodes[iC].aabb.maxX = std::max(nodes[iA].aabb.maxX, nodes[iG].aabb.maxX);
                nodes[iC].aabb.maxY = std::max(nodes[iA].aabb.maxY, nodes[iG].aabb.maxY);
                
                nodes[iA].height = 1 + std::max(nodes[iB].height, nodes[iF].height);
                nodes[iC].height = 1 + std::max(nodes[iA].height, nodes[iG].height);
            }
            return iC;
        }
        
        // Rotate B up
        if (balance_factor < -1) {
            int32_t iD = nodes[iB].left;
            int32_t iE = nodes[iB].right;
            
            nodes[iB].left = iA;
            nodes[iB].parent = nodes[iA].parent;
            nodes[iA].parent = iB;
            
            if (nodes[iB].parent != -1) {
                if (nodes[nodes[iB].parent].left == iA) nodes[nodes[iB].parent].left = iB;
                else nodes[nodes[iB].parent].right = iB;
            } else {
                tree->root = iB;
            }
            
            if (nodes[iD].height > nodes[iE].height) {
                nodes[iB].right = iD;
                nodes[iA].left = iE;
                nodes[iE].parent = iA;
                
                nodes[iA].aabb.minX = std::min(nodes[iC].aabb.minX, nodes[iE].aabb.minX);
                nodes[iA].aabb.minY = std::min(nodes[iC].aabb.minY, nodes[iE].aabb.minY);
                nodes[iA].aabb.maxX = std::max(nodes[iC].aabb.maxX, nodes[iE].aabb.maxX);
                nodes[iA].aabb.maxY = std::max(nodes[iC].aabb.maxY, nodes[iE].aabb.maxY);
                
                nodes[iB].aabb.minX = std::min(nodes[iA].aabb.minX, nodes[iD].aabb.minX);
                nodes[iB].aabb.minY = std::min(nodes[iA].aabb.minY, nodes[iD].aabb.minY);
                nodes[iB].aabb.maxX = std::max(nodes[iA].aabb.maxX, nodes[iD].aabb.maxX);
                nodes[iB].aabb.maxY = std::max(nodes[iA].aabb.maxY, nodes[iD].aabb.maxY);
                
                nodes[iA].height = 1 + std::max(nodes[iC].height, nodes[iE].height);
                nodes[iB].height = 1 + std::max(nodes[iA].height, nodes[iD].height);
            } else {
                nodes[iB].right = iE;
                nodes[iA].left = iD;
                nodes[iD].parent = iA;
                
                nodes[iA].aabb.minX = std::min(nodes[iC].aabb.minX, nodes[iD].aabb.minX);
                nodes[iA].aabb.minY = std::min(nodes[iC].aabb.minY, nodes[iD].aabb.minY);
                nodes[iA].aabb.maxX = std::max(nodes[iC].aabb.maxX, nodes[iD].aabb.maxX);
                nodes[iA].aabb.maxY = std::max(nodes[iC].aabb.maxY, nodes[iD].aabb.maxY);
                
                nodes[iB].aabb.minX = std::min(nodes[iA].aabb.minX, nodes[iE].aabb.minX);
                nodes[iB].aabb.minY = std::min(nodes[iA].aabb.minY, nodes[iE].aabb.minY);
                nodes[iB].aabb.maxX = std::max(nodes[iA].aabb.maxX, nodes[iE].aabb.maxX);
                nodes[iB].aabb.maxY = std::max(nodes[iA].aabb.maxY, nodes[iE].aabb.maxY);
                
                nodes[iA].height = 1 + std::max(nodes[iC].height, nodes[iD].height);
                nodes[iB].height = 1 + std::max(nodes[iA].height, nodes[iE].height);
            }
            return iB;
        }
        
        return iA;
    }
}

DynamicTree* create_dynamic_tree(int initialCapacity) {
    DynamicTree* tree = new DynamicTree();
    tree->nodeCapacity = initialCapacity;
    tree->nodes = new TreeNode[initialCapacity];
    tree->nodeCount = 0;
    tree->root = -1;
    
    // Build free list
    for (int32_t i = 0; i < initialCapacity - 1; ++i) {
        tree->nodes[i].next = i + 1;
        tree->nodes[i].height = -1;
    }
    tree->nodes[initialCapacity - 1].next = -1;
    tree->nodes[initialCapacity - 1].height = -1;
    tree->freeList = 0;
    
    return tree;
}

void destroy_dynamic_tree(DynamicTree* tree) {
    if (!tree) return;
    delete[] tree->nodes;
    delete tree;
}

int32_t tree_insert_leaf(DynamicTree* tree, uint32_t bodyId, const AABB& aabb) {
    int32_t leafId = allocate_node(tree);
    tree->nodes[leafId].aabb = aabb;
    tree->nodes[leafId].bodyId = bodyId;
    tree->nodes[leafId].height = 0;
    
    if (tree->root == -1) {
        tree->root = leafId;
        return leafId;
    }
    
    // Find best sibling (simple cost based on area increase)
    int32_t index = tree->root;
    while (!tree->nodes[index].isLeaf()) {
        int32_t left = tree->nodes[index].left;
        int32_t right = tree->nodes[index].right;
        
        float area = (tree->nodes[index].aabb.maxX - tree->nodes[index].aabb.minX) * 
                     (tree->nodes[index].aabb.maxY - tree->nodes[index].aabb.minY);
        
        AABB combined;
        combined.minX = std::min(tree->nodes[index].aabb.minX, aabb.minX);
        combined.minY = std::min(tree->nodes[index].aabb.minY, aabb.minY);
        combined.maxX = std::max(tree->nodes[index].aabb.maxX, aabb.maxX);
        combined.maxY = std::max(tree->nodes[index].aabb.maxY, aabb.maxY);
        float combinedArea = (combined.maxX - combined.minX) * (combined.maxY - combined.minY);
        
        float cost = 2.0f * combinedArea;
        float inheritanceCost = 2.0f * (combinedArea - area);
        
        // Cost of descending into left child
        float cost1;
        if (tree->nodes[left].isLeaf()) {
            AABB c;
            c.minX = std::min(tree->nodes[left].aabb.minX, aabb.minX);
            c.minY = std::min(tree->nodes[left].aabb.minY, aabb.minY);
            c.maxX = std::max(tree->nodes[left].aabb.maxX, aabb.maxX);
            c.maxY = std::max(tree->nodes[left].aabb.maxY, aabb.maxY);
            cost1 = (c.maxX - c.minX) * (c.maxY - c.minY) + inheritanceCost;
        } else {
            AABB c;
            c.minX = std::min(tree->nodes[left].aabb.minX, aabb.minX);
            c.minY = std::min(tree->nodes[left].aabb.minY, aabb.minY);
            c.maxX = std::max(tree->nodes[left].aabb.maxX, aabb.maxX);
            c.maxY = std::max(tree->nodes[left].aabb.maxY, aabb.maxY);
            float oldArea = (tree->nodes[left].aabb.maxX - tree->nodes[left].aabb.minX) * 
                            (tree->nodes[left].aabb.maxY - tree->nodes[left].aabb.minY);
            float newArea = (c.maxX - c.minX) * (c.maxY - c.minY);
            cost1 = (newArea - oldArea) + inheritanceCost;
        }
        
        // Cost of descending into right child
        float cost2;
        if (tree->nodes[right].isLeaf()) {
            AABB c;
            c.minX = std::min(tree->nodes[right].aabb.minX, aabb.minX);
            c.minY = std::min(tree->nodes[right].aabb.minY, aabb.minY);
            c.maxX = std::max(tree->nodes[right].aabb.maxX, aabb.maxX);
            c.maxY = std::max(tree->nodes[right].aabb.maxY, aabb.maxY);
            cost2 = (c.maxX - c.minX) * (c.maxY - c.minY) + inheritanceCost;
        } else {
            AABB c;
            c.minX = std::min(tree->nodes[right].aabb.minX, aabb.minX);
            c.minY = std::min(tree->nodes[right].aabb.minY, aabb.minY);
            c.maxX = std::max(tree->nodes[right].aabb.maxX, aabb.maxX);
            c.maxY = std::max(tree->nodes[right].aabb.maxY, aabb.maxY);
            float oldArea = (tree->nodes[right].aabb.maxX - tree->nodes[right].aabb.minX) * 
                            (tree->nodes[right].aabb.maxY - tree->nodes[right].aabb.minY);
            float newArea = (c.maxX - c.minX) * (c.maxY - c.minY);
            cost2 = (newArea - oldArea) + inheritanceCost;
        }
        
        if (cost < cost1 && cost < cost2) break;
        
        if (cost1 < cost2) index = left;
        else index = right;
    }
    
    int32_t sibling = index;
    int32_t oldParent = tree->nodes[sibling].parent;
    int32_t newParent = allocate_node(tree);
    tree->nodes[newParent].parent = oldParent;
    tree->nodes[newParent].aabb.minX = std::min(tree->nodes[sibling].aabb.minX, aabb.minX);
    tree->nodes[newParent].aabb.minY = std::min(tree->nodes[sibling].aabb.minY, aabb.minY);
    tree->nodes[newParent].aabb.maxX = std::max(tree->nodes[sibling].aabb.maxX, aabb.maxX);
    tree->nodes[newParent].aabb.maxY = std::max(tree->nodes[sibling].aabb.maxY, aabb.maxY);
    tree->nodes[newParent].height = tree->nodes[sibling].height + 1;
    
    if (oldParent != -1) {
        if (tree->nodes[oldParent].left == sibling) tree->nodes[oldParent].left = newParent;
        else tree->nodes[oldParent].right = newParent;
        
        tree->nodes[newParent].left = sibling;
        tree->nodes[newParent].right = leafId;
        tree->nodes[sibling].parent = newParent;
        tree->nodes[leafId].parent = newParent;
    } else {
        tree->nodes[newParent].left = sibling;
        tree->nodes[newParent].right = leafId;
        tree->nodes[sibling].parent = newParent;
        tree->nodes[leafId].parent = newParent;
        tree->root = newParent;
    }
    
    // Back-propagate height and AABB up and balance
    index = tree->nodes[leafId].parent;
    while (index != -1) {
        index = balance(tree, index);
        
        int32_t left = tree->nodes[index].left;
        int32_t right = tree->nodes[index].right;
        
        tree->nodes[index].height = 1 + std::max(tree->nodes[left].height, tree->nodes[right].height);
        tree->nodes[index].aabb.minX = std::min(tree->nodes[left].aabb.minX, tree->nodes[right].aabb.minX);
        tree->nodes[index].aabb.minY = std::min(tree->nodes[left].aabb.minY, tree->nodes[right].aabb.minY);
        tree->nodes[index].aabb.maxX = std::max(tree->nodes[left].aabb.maxX, tree->nodes[right].aabb.maxX);
        tree->nodes[index].aabb.maxY = std::max(tree->nodes[left].aabb.maxY, tree->nodes[right].aabb.maxY);
        
        index = tree->nodes[index].parent;
    }
    
    return leafId;
}

void tree_remove_leaf(DynamicTree* tree, int32_t leafId) {
    if (leafId == tree->root) {
        tree->root = -1;
        free_node(tree, leafId);
        return;
    }
    
    int32_t parent = tree->nodes[leafId].parent;
    int32_t grandParent = tree->nodes[parent].parent;
    int32_t sibling = (tree->nodes[parent].left == leafId) ? tree->nodes[parent].right : tree->nodes[parent].left;
    
    if (grandParent != -1) {
        if (tree->nodes[grandParent].left == parent) tree->nodes[grandParent].left = sibling;
        else tree->nodes[grandParent].right = sibling;
        tree->nodes[sibling].parent = grandParent;
        free_node(tree, parent);
        
        int32_t index = grandParent;
        while (index != -1) {
            index = balance(tree, index);
            int32_t left = tree->nodes[index].left;
            int32_t right = tree->nodes[index].right;
            tree->nodes[index].aabb.minX = std::min(tree->nodes[left].aabb.minX, tree->nodes[right].aabb.minX);
            tree->nodes[index].aabb.minY = std::min(tree->nodes[left].aabb.minY, tree->nodes[right].aabb.minY);
            tree->nodes[index].aabb.maxX = std::max(tree->nodes[left].aabb.maxX, tree->nodes[right].aabb.maxX);
            tree->nodes[index].aabb.maxY = std::max(tree->nodes[left].aabb.maxY, tree->nodes[right].aabb.maxY);
            tree->nodes[index].height = 1 + std::max(tree->nodes[left].height, tree->nodes[right].height);
            index = tree->nodes[index].parent;
        }
    } else {
        tree->root = sibling;
        tree->nodes[sibling].parent = -1;
        free_node(tree, parent);
    }
    
    free_node(tree, leafId);
}

int32_t tree_update_leaf(DynamicTree* tree, int32_t proxyId, const AABB& aabb) {
    uint32_t bodyId = tree->nodes[proxyId].bodyId;
    tree_remove_leaf(tree, proxyId);
    return tree_insert_leaf(tree, bodyId, aabb);
}

int query_tree_pairs(DynamicTree* tree, BroadphasePair* outPairs, int maxPairs) {
    if (tree->root == -1) return 0;
    
    int pairCount = 0;
    std::vector<int32_t> stack;
    
    // We traverse the tree to find all overlapping leaves.
    // Algorithm: for each leaf, query the tree for overlaps.
    // To avoid duplicates (A,B and B,A), we only query leaves with index > leaf.
    
    std::vector<int32_t> leaves;
    stack.push_back(tree->root);
    while(!stack.empty()){
        int32_t curr = stack.back();
        stack.pop_back();
        if(tree->nodes[curr].isLeaf()) leaves.push_back(curr);
        else {
            stack.push_back(tree->nodes[curr].left);
            stack.push_back(tree->nodes[curr].right);
        }
    }
    
    for(size_t i = 0; i < leaves.size(); ++i){
        int32_t leafA = leaves[i];
        const AABB& aabbA = tree->nodes[leafA].aabb;
        
        // Query tree for overlaps with aabbA
        stack.clear();
        stack.push_back(tree->root);
        
        while(!stack.empty()){
            int32_t curr = stack.back();
            stack.pop_back();
            
            if(!tree->nodes[curr].aabb.overlaps(aabbA)) continue;
            
            if(tree->nodes[curr].isLeaf()){
                int32_t leafB = curr;
                // Only process pairs once (A < B)
                if(leafB > leafA){
                    if(pairCount >= maxPairs) return pairCount;
                    outPairs[pairCount].bodyA = tree->nodes[leafA].bodyId;
                    outPairs[pairCount].bodyB = tree->nodes[leafB].bodyId;
                    pairCount++;
                }
            } else {
                stack.push_back(tree->nodes[curr].left);
                stack.push_back(tree->nodes[curr].right);
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
