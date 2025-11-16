//
//  SliceExtractKernel.metal
//  ChromaImagingKit
//
//  Created by Mohamed Elbashir on 11/14/25.
//


#include <metal_stdlib>
using namespace metal;

// volumeVoxels: flattened [z * (width * height) + y * width + x]

// ────────────────────────────────────────────────────────────────
// AXIAL SLICE (z-plane) → output size: width x height (x, y)
// ────────────────────────────────────────────────────────────────
kernel void axialSliceKernel(
    const device float *volumeVoxels [[ buffer(0) ]],
    device float *outPixels          [[ buffer(1) ]],
    constant uint &width             [[ buffer(2) ]],
    constant uint &height            [[ buffer(3) ]],
    constant uint &depth             [[ buffer(4) ]],
    constant uint &sliceIndex        [[ buffer(5) ]],
    uint2 gid                        [[ thread_position_in_grid ]]
) {
    uint x = gid.x;
    uint y = gid.y;

    if (x >= width || y >= height) {
        return;
    }

    if (sliceIndex >= depth) {
        return;
    }

    uint sliceSize = width * height;
    uint z = sliceIndex;

    uint volumeIndex = z * sliceSize + y * width + x;
    uint sliceIndex2D = y * width + x;

    outPixels[sliceIndex2D] = volumeVoxels[volumeIndex];
}

// ────────────────────────────────────────────────────────────────
// CORONAL SLICE (y-plane) → output size: width x depth (x, z)
// ────────────────────────────────────────────────────────────────
kernel void coronalSliceKernel(
    const device float *volumeVoxels [[ buffer(0) ]],
    device float *outPixels          [[ buffer(1) ]],
    constant uint &width             [[ buffer(2) ]],
    constant uint &height            [[ buffer(3) ]],
    constant uint &depth             [[ buffer(4) ]],
    constant uint &sliceIndex        [[ buffer(5) ]], // fixed y
    uint2 gid                        [[ thread_position_in_grid ]]
) {
    uint x = gid.x;
    uint z = gid.y;

    if (x >= width || z >= depth) {
        return;
    }

    uint y = sliceIndex;
    if (y >= height) {
        return;
    }

    uint sliceSize = width * height;
    uint volumeIndex = z * sliceSize + y * width + x;

    // Output dims: width x depth
    // out(x, z) index = z * width + x
    uint outIndex = z * width + x;

    outPixels[outIndex] = volumeVoxels[volumeIndex];
}

// ────────────────────────────────────────────────────────────────
// SAGITTAL SLICE (x-plane) → output size: height x depth (y, z)
// ────────────────────────────────────────────────────────────────
kernel void sagittalSliceKernel(
    const device float *volumeVoxels [[ buffer(0) ]],
    device float *outPixels          [[ buffer(1) ]],
    constant uint &width             [[ buffer(2) ]],
    constant uint &height            [[ buffer(3) ]],
    constant uint &depth             [[ buffer(4) ]],
    constant uint &sliceIndex        [[ buffer(5) ]], // fixed x
    uint2 gid                        [[ thread_position_in_grid ]]
) {
    uint y = gid.x;
    uint z = gid.y;

    if (y >= height || z >= depth) {
        return;
    }

    uint x = sliceIndex;
    if (x >= width) {
        return;
    }

    uint sliceSize = width * height;
    uint volumeIndex = z * sliceSize + y * width + x;

    // Output dims: height x depth
    // out(y, z) index = z * height + y
    uint outIndex = z * height + y;

    outPixels[outIndex] = volumeVoxels[volumeIndex];
}
