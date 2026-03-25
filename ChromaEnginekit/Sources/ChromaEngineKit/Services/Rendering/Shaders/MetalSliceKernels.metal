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
    float4 origin;
    float4 spacing;
    float4 axisX;
    float4 axisY;
    float4 axisZ;
    float4 invRow0;
    float4 invRow1;
    float4 invRow2;
    float rescaleSlope;
    float rescaleIntercept;
    uint interpolationMode;
    uint validDirection;
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

inline float readVoxelAt(
    const device uchar *data,
    uint sizeX,
    uint sizeY,
    uint sizeZ,
    uint bytesPerVoxel,
    uint scalarType,
    int i,
    int j,
    int k
) {
    if (i < 0 || j < 0 || k < 0 ||
        i >= int(sizeX) || j >= int(sizeY) || k >= int(sizeZ)) {
        return 0.0f;
    }
    const uint voxelIndex = (uint(k) * sizeX * sizeY) + (uint(j) * sizeX) + uint(i);
    const uint byteOffset = voxelIndex * bytesPerVoxel;
    return readVoxel(data, byteOffset, scalarType);
}

inline float sampleTrilinear(
    const device uchar *data,
    constant SliceRenderParams &params,
    float3 index
) {
    int x0 = int(floor(index.x));
    int y0 = int(floor(index.y));
    int z0 = int(floor(index.z));

    if (x0 < 0 || y0 < 0 || z0 < 0 ||
        x0 >= int(params.sizeX) || y0 >= int(params.sizeY) || z0 >= int(params.sizeZ)) {
        return 0.0f;
    }

    int x1 = min(x0 + 1, int(params.sizeX) - 1);
    int y1 = min(y0 + 1, int(params.sizeY) - 1);
    int z1 = min(z0 + 1, int(params.sizeZ) - 1);

    float xd = index.x - float(x0);
    float yd = index.y - float(y0);
    float zd = index.z - float(z0);

    float c000 = readVoxelAt(data, params.sizeX, params.sizeY, params.sizeZ, params.bytesPerVoxel, params.scalarType, x0, y0, z0);
    float c100 = readVoxelAt(data, params.sizeX, params.sizeY, params.sizeZ, params.bytesPerVoxel, params.scalarType, x1, y0, z0);
    float c010 = readVoxelAt(data, params.sizeX, params.sizeY, params.sizeZ, params.bytesPerVoxel, params.scalarType, x0, y1, z0);
    float c110 = readVoxelAt(data, params.sizeX, params.sizeY, params.sizeZ, params.bytesPerVoxel, params.scalarType, x1, y1, z0);
    float c001 = readVoxelAt(data, params.sizeX, params.sizeY, params.sizeZ, params.bytesPerVoxel, params.scalarType, x0, y0, z1);
    float c101 = readVoxelAt(data, params.sizeX, params.sizeY, params.sizeZ, params.bytesPerVoxel, params.scalarType, x1, y0, z1);
    float c011 = readVoxelAt(data, params.sizeX, params.sizeY, params.sizeZ, params.bytesPerVoxel, params.scalarType, x0, y1, z1);
    float c111 = readVoxelAt(data, params.sizeX, params.sizeY, params.sizeZ, params.bytesPerVoxel, params.scalarType, x1, y1, z1);

    float c00 = c000 * (1.0f - xd) + c100 * xd;
    float c10 = c010 * (1.0f - xd) + c110 * xd;
    float c01 = c001 * (1.0f - xd) + c101 * xd;
    float c11 = c011 * (1.0f - xd) + c111 * xd;

    float c0 = c00 * (1.0f - yd) + c10 * yd;
    float c1 = c01 * (1.0f - yd) + c11 * yd;

    return c0 * (1.0f - zd) + c1 * zd;
}

inline float sampleNearest(
    const device uchar *data,
    constant SliceRenderParams &params,
    float3 index
) {
    int i = int(round(index.x));
    int j = int(round(index.y));
    int k = int(round(index.z));
    return readVoxelAt(data, params.sizeX, params.sizeY, params.sizeZ, params.bytesPerVoxel, params.scalarType, i, j, k);
}

inline float3 patientToVoxelIndex(
    constant SliceRenderParams &params,
    float3 patientPoint
) {
    float3 origin = params.origin.xyz;
    float3 spacing = params.spacing.xyz;
    float3 relative = patientPoint - origin;
    float3 index;
    index.x = dot(params.invRow0.xyz, relative) / spacing.x;
    index.y = dot(params.invRow1.xyz, relative) / spacing.y;
    index.z = dot(params.invRow2.xyz, relative) / spacing.z;
    return index;
}

inline float applyWindowLevel(
    float value,
    constant SliceRenderParams &params
) {
    float rescaled = value * params.rescaleSlope + params.rescaleIntercept;
    float lower = params.level - params.window * 0.5f;
    float upper = params.level + params.window * 0.5f;
    float range = max(upper - lower, 1.0f);
    return clamp((rescaled - lower) / range, 0.0f, 1.0f);
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

    if (params.validDirection == 0) {
        outData[gid.y * params.outputWidth + gid.x] = uchar(0);
        return;
    }

    const float3 axisX = params.axisX.xyz;
    const float3 axisY = params.axisY.xyz;
    const float3 axisZ = params.axisZ.xyz;
    const float3 spacing = params.spacing.xyz;
    const float3 origin = params.origin.xyz;

    float3 planeOrigin = origin + axisZ * (float(params.sliceIndex) * spacing.z);
    float3 axisU = axisX;
    float3 axisV = axisY;
    float spacingU = spacing.x;
    float spacingV = spacing.y;

    float3 patientPoint = planeOrigin
        + axisU * (float(gid.x) * spacingU)
        + axisV * (float(gid.y) * spacingV);

    float3 index = patientToVoxelIndex(params, patientPoint);
    float sample = params.interpolationMode == 0
        ? sampleTrilinear(volumeData, params, index)
        : sampleNearest(volumeData, params, index);

    float normalized = applyWindowLevel(sample, params);
    outData[gid.y * params.outputWidth + gid.x] = uchar(normalized * 255.0f);
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

    if (params.validDirection == 0) {
        outData[gid.y * params.outputWidth + gid.x] = uchar(0);
        return;
    }

    const float3 axisX = params.axisX.xyz;
    const float3 axisY = params.axisY.xyz;
    const float3 axisZ = params.axisZ.xyz;
    const float3 spacing = params.spacing.xyz;
    const float3 origin = params.origin.xyz;

    float3 planeOrigin = origin + axisY * (float(params.sliceIndex) * spacing.y);
    float3 axisU = axisX;
    float3 axisV = axisZ;
    float spacingU = spacing.x;
    float spacingV = spacing.z;

    float3 patientPoint = planeOrigin
        + axisU * (float(gid.x) * spacingU)
        + axisV * (float(gid.y) * spacingV);

    float3 index = patientToVoxelIndex(params, patientPoint);
    float sample = params.interpolationMode == 0
        ? sampleTrilinear(volumeData, params, index)
        : sampleNearest(volumeData, params, index);

    float normalized = applyWindowLevel(sample, params);
    outData[gid.y * params.outputWidth + gid.x] = uchar(normalized * 255.0f);
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

    if (params.validDirection == 0) {
        outData[gid.y * params.outputWidth + gid.x] = uchar(0);
        return;
    }

    const float3 axisX = params.axisX.xyz;
    const float3 axisY = params.axisY.xyz;
    const float3 axisZ = params.axisZ.xyz;
    const float3 spacing = params.spacing.xyz;
    const float3 origin = params.origin.xyz;

    float3 planeOrigin = origin + axisX * (float(params.sliceIndex) * spacing.x);
    float3 axisU = axisY;
    float3 axisV = axisZ;
    float spacingU = spacing.y;
    float spacingV = spacing.z;

    float3 patientPoint = planeOrigin
        + axisU * (float(gid.x) * spacingU)
        + axisV * (float(gid.y) * spacingV);

    float3 index = patientToVoxelIndex(params, patientPoint);
    float sample = params.interpolationMode == 0
        ? sampleTrilinear(volumeData, params, index)
        : sampleNearest(volumeData, params, index);

    float normalized = applyWindowLevel(sample, params);
    outData[gid.y * params.outputWidth + gid.x] = uchar(normalized * 255.0f);
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
