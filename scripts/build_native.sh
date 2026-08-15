#!/bin/bash
# Exit on any failure: previously only the macOS build's exit code was checked,
# so a broken iOS Simulator build reported success.
set -euo pipefail

# Configuration
SOURCE_DIR="src/native"
OUTPUT_DIR="lib/src/core/native/bin"
LIB_NAME="libflash_core.dylib"
CPP_FLAGS="-O3 -ffast-math -flto -std=c++11"

# Clean output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Compiling native core library (Particles + Physics) for iOS Simulator..."

# Get SDK path for simulator
SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)

# Compile for iOS Simulator (arm64 for modern Macs)
clang++ -shared -fPIC \
    $CPP_FLAGS \
    -target arm64-apple-ios14.0-simulator \
    -isysroot "$SDK_PATH" \
    "$SOURCE_DIR/particles.cpp" \
    "$SOURCE_DIR/physics.cpp" \
    "$SOURCE_DIR/broadphase.cpp" \
    "$SOURCE_DIR/joints.cpp" \
    "$SOURCE_DIR/nodes.cpp" \
    -o "$OUTPUT_DIR/libflash_core_sim.dylib"

echo "Compiling native core library (Particles + Physics) for macOS Host..."
# Compile for macOS (Host)
clang++ -shared -fPIC \
    $CPP_FLAGS \
    -std=c++11 \
    "$SOURCE_DIR/particles.cpp" \
    "$SOURCE_DIR/physics.cpp" \
    "$SOURCE_DIR/broadphase.cpp" \
    "$SOURCE_DIR/joints.cpp" \
    "$SOURCE_DIR/nodes.cpp" \
    -o "$OUTPUT_DIR/libflash_core.dylib"

if [ $? -eq 0 ]; then
    echo "Successfully compiled to $OUTPUT_DIR/$LIB_NAME"
else
    echo "Compilation failed!"
    exit 1
fi
