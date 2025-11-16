// Laplacian3D.metal
// ChromaImagingKit

#include <metal_stdlib>
using namespace metal;

// Minimal 3D Laplacian kernel stub.
// Placeholder signature to be implemented later.
kernel void laplacian3D(texture3d<float, access::read>  inTex   [[texture(0)]],
                        texture3d<float, access::write> outTex  [[texture(1)]],
                        uint3 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height() || gid.z >= outTex.get_depth()) {
        return;
    }
    // Pass-through for now
    outTex.write(inTex.read(gid), gid);
}
