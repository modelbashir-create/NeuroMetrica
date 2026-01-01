#include <metal_stdlib>
using namespace metal;

struct SliceRenderParams {
    uint sizeX;
    uint sizeY;
    uint sizeZ;
    uint outputWidth;
    uint outputHeight;
    uint sliceIndex;
    uint bytesPerVoxel;
    uint scalarType;
    float window;
    float level;
};

struct VolumeRenderParams {
    uint sizeX;
    uint sizeY;
    uint sizeZ;
    uint outputWidth;
    uint outputHeight;
    uint bytesPerVoxel;
    uint scalarType;
    float window;
    float level;
    float step;
};

inline float readVoxel(const device uchar *data, uint offset, uint scalarType) {
    switch (scalarType) {
        case 0: { // uint16
            const device ushort *ptr = reinterpret_cast<const device ushort *>(data + offset);
            return float(*ptr);
        }
        case 1: { // int16
            const device short *ptr = reinterpret_cast<const device short *>(data + offset);
            return float(*ptr);
        }
        case 2: { // float32
            const device float *ptr = reinterpret_cast<const device float *>(data + offset);
            return *ptr;
        }
        case 3: { // uint8
            const device uchar *ptr = reinterpret_cast<const device uchar *>(data + offset);
            return float(*ptr);
        }
        default:
            return 0.0f;
    }
}

kernel void renderAxialSlice(
    const device uchar *volumeData [[buffer(0)]],
    device uchar *outData [[buffer(1)]],
    constant SliceRenderParams &params [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= params.outputWidth || gid.y >= params.outputHeight) {
        return;
    }

    const uint x = gid.x;
    const uint y = gid.y;
    const uint k = min(params.sliceIndex, max(params.sizeZ, 1u) - 1u);

    const uint sliceStride = params.sizeX * params.sizeY;
    const uint voxelIndex = (k * sliceStride) + (y * params.sizeX) + x;
    const uint byteOffset = voxelIndex * params.bytesPerVoxel;

    const float value = readVoxel(volumeData, byteOffset, params.scalarType);
    const float lower = params.level - params.window * 0.5f;
    const float upper = params.level + params.window * 0.5f;
    const float range = max(upper - lower, 1.0f);
    const float normalized = clamp((value - lower) / range, 0.0f, 1.0f);
    const uint outIndex = y * params.outputWidth + x;
    outData[outIndex] = uchar(normalized * 255.0f);
}

kernel void renderCoronalSlice(
    const device uchar *volumeData [[buffer(0)]],
    device uchar *outData [[buffer(1)]],
    constant SliceRenderParams &params [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= params.outputWidth || gid.y >= params.outputHeight) {
        return;
    }

    const uint x = gid.x;
    const uint z = gid.y;
    const uint j = min(params.sliceIndex, max(params.sizeY, 1u) - 1u);

    const uint sliceStride = params.sizeX * params.sizeY;
    const uint voxelIndex = (z * sliceStride) + (j * params.sizeX) + x;
    const uint byteOffset = voxelIndex * params.bytesPerVoxel;

    const float value = readVoxel(volumeData, byteOffset, params.scalarType);
    const float lower = params.level - params.window * 0.5f;
    const float upper = params.level + params.window * 0.5f;
    const float range = max(upper - lower, 1.0f);
    const float normalized = clamp((value - lower) / range, 0.0f, 1.0f);
    const uint outIndex = z * params.outputWidth + x;
    outData[outIndex] = uchar(normalized * 255.0f);
}

kernel void renderSagittalSlice(
    const device uchar *volumeData [[buffer(0)]],
    device uchar *outData [[buffer(1)]],
    constant SliceRenderParams &params [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= params.outputWidth || gid.y >= params.outputHeight) {
        return;
    }

    const uint y = gid.x;
    const uint z = gid.y;
    const uint i = min(params.sliceIndex, max(params.sizeX, 1u) - 1u);

    const uint sliceStride = params.sizeX * params.sizeY;
    const uint voxelIndex = (z * sliceStride) + (y * params.sizeX) + i;
    const uint byteOffset = voxelIndex * params.bytesPerVoxel;

    const float value = readVoxel(volumeData, byteOffset, params.scalarType);
    const float lower = params.level - params.window * 0.5f;
    const float upper = params.level + params.window * 0.5f;
    const float range = max(upper - lower, 1.0f);
    const float normalized = clamp((value - lower) / range, 0.0f, 1.0f);
    const uint outIndex = z * params.outputWidth + y;
    outData[outIndex] = uchar(normalized * 255.0f);
}

kernel void renderAxialVolume(
    const device uchar *volumeData [[buffer(0)]],
    device uchar *outData [[buffer(1)]],
    constant VolumeRenderParams &params [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= params.outputWidth || gid.y >= params.outputHeight) {
        return;
    }

    const uint x = gid.x;
    const uint y = gid.y;
    const uint sliceStride = params.sizeX * params.sizeY;
    const float lower = params.level - params.window * 0.5f;
    const float upper = params.level + params.window * 0.5f;
    const float range = max(upper - lower, 1.0f);
    const float step = max(params.step, 1.0f);

    float accum = 0.0f;
    for (float kf = 0.0f; kf < float(params.sizeZ); kf += step) {
        const uint k = min(uint(kf), max(params.sizeZ, 1u) - 1u);
        const uint voxelIndex = (k * sliceStride) + (y * params.sizeX) + x;
        const uint byteOffset = voxelIndex * params.bytesPerVoxel;
        const float value = readVoxel(volumeData, byteOffset, params.scalarType);
        const float normalized = clamp((value - lower) / range, 0.0f, 1.0f);
        accum = accum + (1.0f - accum) * normalized;
        if (accum >= 0.999f) {
            break;
        }
    }

    const uint outIndex = y * params.outputWidth + x;
    outData[outIndex] = uchar(accum * 255.0f);
}

kernel void renderCoronalVolume(
    const device uchar *volumeData [[buffer(0)]],
    device uchar *outData [[buffer(1)]],
    constant VolumeRenderParams &params [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= params.outputWidth || gid.y >= params.outputHeight) {
        return;
    }

    const uint x = gid.x;
    const uint z = gid.y;
    const uint sliceStride = params.sizeX * params.sizeY;
    const float lower = params.level - params.window * 0.5f;
    const float upper = params.level + params.window * 0.5f;
    const float range = max(upper - lower, 1.0f);
    const float step = max(params.step, 1.0f);

    float accum = 0.0f;
    for (float jf = 0.0f; jf < float(params.sizeY); jf += step) {
        const uint j = min(uint(jf), max(params.sizeY, 1u) - 1u);
        const uint voxelIndex = (z * sliceStride) + (j * params.sizeX) + x;
        const uint byteOffset = voxelIndex * params.bytesPerVoxel;
        const float value = readVoxel(volumeData, byteOffset, params.scalarType);
        const float normalized = clamp((value - lower) / range, 0.0f, 1.0f);
        accum = accum + (1.0f - accum) * normalized;
        if (accum >= 0.999f) {
            break;
        }
    }

    const uint outIndex = z * params.outputWidth + x;
    outData[outIndex] = uchar(accum * 255.0f);
}

kernel void renderSagittalVolume(
    const device uchar *volumeData [[buffer(0)]],
    device uchar *outData [[buffer(1)]],
    constant VolumeRenderParams &params [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= params.outputWidth || gid.y >= params.outputHeight) {
        return;
    }

    const uint y = gid.x;
    const uint z = gid.y;
    const uint sliceStride = params.sizeX * params.sizeY;
    const float lower = params.level - params.window * 0.5f;
    const float upper = params.level + params.window * 0.5f;
    const float range = max(upper - lower, 1.0f);
    const float step = max(params.step, 1.0f);

    float accum = 0.0f;
    for (float ifv = 0.0f; ifv < float(params.sizeX); ifv += step) {
        const uint i = min(uint(ifv), max(params.sizeX, 1u) - 1u);
        const uint voxelIndex = (z * sliceStride) + (y * params.sizeX) + i;
        const uint byteOffset = voxelIndex * params.bytesPerVoxel;
        const float value = readVoxel(volumeData, byteOffset, params.scalarType);
        const float normalized = clamp((value - lower) / range, 0.0f, 1.0f);
        accum = accum + (1.0f - accum) * normalized;
        if (accum >= 0.999f) {
            break;
        }
    }

    const uint outIndex = z * params.outputWidth + y;
    outData[outIndex] = uchar(accum * 255.0f);
}
