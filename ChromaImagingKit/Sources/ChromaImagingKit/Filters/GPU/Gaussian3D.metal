// Gaussian3D.metal
// ChromaImagingKit

#include <metal_stdlib>
using namespace metal;

// Minimal 3D Gaussian blur kernel stub.
// This is a placeholder compute kernel signature you can flesh out later.
kernel void gaussian3D(texture3d<float, access::read>  inTex   [[texture(0)]],
                       texture3d<float, access::write> outTex  [[texture(1)]],
                       constant uint3&                  radius [[buffer(0)]],
                       uint3 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height() || gid.z >= outTex.get_depth()) {
        return;
    }
    // Pass-through for now
    outTex.write(inTex.read(gid), gid);
}
