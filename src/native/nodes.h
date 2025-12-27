#ifndef FLASH_NODES_H
#define FLASH_NODES_H

#include <stdint.h>
#include <vector>

extern "C" {

struct NativeTransform {
    float m[16]; // 4x4 Column-major matrix
};

struct NativeNode {
    uint32_t id;
    float posX, posY, posZ;
    float rotX, rotY, rotZ;
    float scaleX, scaleY, scaleZ;
    
    NativeTransform localMatrix;
    NativeTransform worldMatrix;
    
    int32_t parentId; // -1 for root
    int32_t visible;
    int32_t dirty;
};

struct NativeScene {
    NativeNode* nodes;
    int maxNodes;
    int activeCount;
};

NativeScene* create_native_scene(int maxNodes);
void destroy_native_scene(NativeScene* scene);
int32_t create_native_node(NativeScene* scene, int32_t parentId);
void update_scene_transforms(NativeScene* scene);

}

#endif // FLASH_NODES_H
