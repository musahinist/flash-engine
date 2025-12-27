#include "nodes.h"
#include <cmath>
#include <cstring>
#include <algorithm>

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

NativeScene* create_native_scene(int maxNodes) {
    NativeScene* scene = new NativeScene();
    scene->maxNodes = maxNodes;
    scene->nodes = new NativeNode[maxNodes];
    scene->activeCount = 0;
    scene->totalUpdates = 0;
    return scene;
}

void destroy_native_scene(NativeScene* scene) {
    delete[] scene->nodes;
    delete scene;
}

int32_t create_native_node(NativeScene* scene, int32_t parentId) {
    if (scene->activeCount >= scene->maxNodes) return -1;
    
    int32_t id = scene->activeCount++;
    NativeNode& node = scene->nodes[id];
    node.id = id;
    node.parentId = parentId;
    node.posX = node.posY = node.posZ = 0;
    node.rotX = node.rotY = node.rotZ = 0;
    node.scaleX = node.scaleY = node.scaleZ = 1.0f;
    node.visible = 1;
    node.dirty = 1;
    node.worldVersion = 0;
    mat4_identity(node.localMatrix.m);
    mat4_identity(node.worldMatrix.m);
    
    return id;
}

void update_scene_transforms(NativeScene* scene) {
    scene->totalUpdates++;
    
    for (int i = 0; i < scene->activeCount; ++i) {
        NativeNode& node = scene->nodes[i];
        
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
        
        bool parentChanged = false;
        uint32_t parentWorldVersion = 0;
        if (node.parentId != -1) {
            NativeNode& parent = scene->nodes[node.parentId];
            parentWorldVersion = parent.worldVersion;
            if (node.worldVersion < parentWorldVersion) {
                parentChanged = true;
            }
        }

        if (localChanged || parentChanged || node.worldVersion == 0) {
            if (node.parentId == -1) {
                memcpy(node.worldMatrix.m, node.localMatrix.m, 16 * sizeof(float));
            } else {
                NativeNode& parent = scene->nodes[node.parentId];
                mat4_mul(node.worldMatrix.m, parent.worldMatrix.m, node.localMatrix.m);
            }
            node.worldVersion = scene->totalUpdates;
        }
    }
}

}
