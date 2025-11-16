//
//  WindowLevelKernel.metal
//  ChromaImagingKit
//
//  Created by Mohamed Elbashir on 11/14/25.
//


#include <metal_stdlib>
using namespace metal;

// inPixels  : input float pixels (row-major)
// outPixels : output float pixels (row-major)
// slope     : 1 / window
// intercept : -(level - window/2) * slope
// count     : total pixel count (width * height)

kernel void windowLevelKernel(
    const device float *inPixels         [[ buffer(0) ]],
    device float *outPixels              [[ buffer(1) ]],
    constant float &slope                [[ buffer(2) ]],
    constant float &intercept            [[ buffer(3) ]],
    constant uint &count                 [[ buffer(4) ]],
    uint gid                             [[ thread_position_in_grid ]]
) {
    if (gid >= count) return;

    float v = inPixels[gid];
    float norm = slope * v + intercept;

    // Clamp to [0, 1] for display
    norm = clamp(norm, 0.0f, 1.0f);

    outPixels[gid] = norm;
}