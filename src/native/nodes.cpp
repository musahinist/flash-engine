#include "nodes.h"
#include <cmath>
#include <cstring>
#include <algorithm>

// Safety stop for resolve_node's parent walk. A well-formed scene is far
// shallower than this; hitting it means a cyclic or corrupt parent chain.
static const int kMaxHierarchyDepth = 256;

extern "C" {

// Helper: Matrix Multiply (Column-Major)
void mat4_mul(float* out, const float* a, const float* b) {
    for (int col = 0; col < 4; ++col) {
        for (int row = 0; row < 4; ++row) {
            float sum = 0;
            for (int k = 0; k < 4; ++k) {
                sum += a[k * 4 + row] * b[col * 4 + k];
            }
            out[col * 4 + row] = sum;
        }
    }
}

// Helper: Matrix Identity
void mat4_identity(float* m) {
    memset(m, 0, 16 * sizeof(float));
    m[0] = m[5] = m[10] = m[15] = 1.0f;
}

// Helper: Create Local Matrix from PRS (T * R * S) - Column-Major
void mat4_from_prs(float* m, float tx, float ty, float tz, float rx, float ry, float rz, float sx, float sy, float sz) {
    float cx = cosf(rx), sx_s = sinf(rx);
    float cy = cosf(ry), sy_s = sinf(ry);
    float cz = cosf(rz), sz_s = sinf(rz);

    // Rotation Matrix (Euler ZYX)
    m[0] = (cy * cz) * sx;
    m[1] = (cx * sz_s + sx_s * sy_s * cz) * sx;
    m[2] = (sx_s * sz_s - cx * sy_s * cz) * sx;
    m[3] = 0;

    m[4] = (-cy * sz_s) * sy;
    m[5] = (cx * cz - sx_s * sy_s * sz_s) * sy;
    m[6] = (sx_s * cz + cx * sy_s * sz_s) * sy;
    m[7] = 0;

    m[8] = sy_s * sz;
    m[9] = -sx_s * cy * sz;
    m[10] = cx * cy * sz;
    m[11] = 0;

    m[12] = tx;
    m[13] = ty;
    m[14] = tz;
    m[15] = 1.0f;
}

FLASH_API NativeScene* create_native_scene(int maxNodes) {
    NativeScene* scene = new NativeScene();
    scene->maxNodes = maxNodes;
    scene->nodes = new NativeNode[maxNodes];
    scene->activeCount = 0;
    scene->totalUpdates = 0;
    scene->freeList = new int32_t[maxNodes];
    scene->freeCount = 0;
    return scene;
}

FLASH_API void destroy_native_scene(NativeScene* scene) {
    if (!scene) return;
    delete[] scene->nodes;
    delete[] scene->freeList;
    delete scene;
}

FLASH_API int32_t create_native_node(NativeScene* scene, int32_t parentId) {
    int32_t id;
    if (scene->freeCount > 0) {
        // Reuse a released slot before growing the pool.
        id = scene->freeList[--scene->freeCount];
    } else {
        if (scene->activeCount >= scene->maxNodes) return -1;
        id = scene->activeCount++;
    }

    NativeNode& node = scene->nodes[id];
    node.id = id;
    node.parentId = parentId;
    node.posX = node.posY = node.posZ = 0;
    node.rotX = node.rotY = node.rotZ = 0;
    node.scaleX = node.scaleY = node.scaleZ = 1.0f;
    node.visible = 1;
    node.dirty = 1;
    node.worldVersion = 0;
    node.alive = 1;
    mat4_identity(node.localMatrix.m);
    mat4_identity(node.worldMatrix.m);

    return id;
}

FLASH_API void destroy_native_node(NativeScene* scene, int32_t nodeId) {
    if (!scene || nodeId < 0 || nodeId >= scene->activeCount) return;

    NativeNode& node = scene->nodes[nodeId];
    if (!node.alive) return; // guard against double release

    node.alive = 0;
    node.parentId = -1;
    node.visible = 0;
    node.dirty = 0;

    // Orphan any node still pointing at this slot, so a later slot reuse
    // cannot silently re-parent it under an unrelated node.
    for (int i = 0; i < scene->activeCount; ++i) {
        if (scene->nodes[i].alive && scene->nodes[i].parentId == nodeId) {
            scene->nodes[i].parentId = -1;
            scene->nodes[i].dirty = 1;
        }
    }

    scene->freeList[scene->freeCount++] = nodeId;
}

// Resolves one node's world matrix, making sure its parent is resolved first.
//
// The old implementation walked the pool in flat index order and read
// nodes[parentId] assuming the parent had already been processed this pass.
// That held only because ids were handed out monotonically. Now that
// create_native_node reuses released slots, a child can sit at a lower index
// than its parent, so the order has to be derived from the hierarchy instead.
//
// Re-entry is harmless: a node resolved earlier in the same pass has dirty == 0
// and worldVersion == totalUpdates, so both recompute conditions are false.
static void resolve_node(NativeScene* scene, int32_t id, int depth) {
    if (id < 0 || id >= scene->activeCount) return;
    if (depth > kMaxHierarchyDepth) return; // malformed/cyclic parent chain

    NativeNode& node = scene->nodes[id];
    if (!node.alive) return;

    if (node.parentId != -1) {
        resolve_node(scene, node.parentId, depth + 1);
    }

    bool localChanged = false;
    if (node.dirty) {
        mat4_from_prs(node.localMatrix.m,
            node.posX, node.posY, node.posZ,
            node.rotX, node.rotY, node.rotZ,
            node.scaleX, node.scaleY, node.scaleZ
        );
        node.dirty = 0;
        localChanged = true;
    }

    if (node.parentId == -1) {
        if (localChanged || node.worldVersion == 0) {
            memcpy(node.worldMatrix.m, node.localMatrix.m, 16 * sizeof(float));
            node.worldVersion = scene->totalUpdates;
        }
        return;
    }

    NativeNode& parent = scene->nodes[node.parentId];
    if (localChanged || node.worldVersion == 0 || node.worldVersion < parent.worldVersion) {
        mat4_mul(node.worldMatrix.m, parent.worldMatrix.m, node.localMatrix.m);
        node.worldVersion = scene->totalUpdates;
    }
}

FLASH_API void update_scene_transforms(NativeScene* scene) {
    if (!scene) return;
    scene->totalUpdates++;

    for (int i = 0; i < scene->activeCount; ++i) {
        resolve_node(scene, i, 0);
    }
}

}
