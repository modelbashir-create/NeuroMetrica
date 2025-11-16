#!/usr/bin/env bash
set -euo pipefail

# Run this from the ChromaImagingKit package root.
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "Creating CNifti target files..."

mkdir -p Sources/CNifti

cat > Sources/CNifti/NiftiBridge.h <<'EOF'
// NiftiBridge.h
#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Simple struct exported to Swift.
// Always returns data as 32-bit floats.
typedef struct {
    int ndim;          // number of dimensions
    int width;         // dim[1]
    int height;        // dim[2]
    int depth;         // dim[3]
    int timepoints;    // dim[4] (0 or 1 if not 4D)

    float spacingX;    // pixdim[1]
    float spacingY;    // pixdim[2]
    float spacingZ;    // pixdim[3]

    int isNifti2;      // 0 = nifti-1, 1 = nifti-2 (info only)
    size_t voxelCount; // width * height * depth * max(1, timepoints)

    float *data;       // pointer to float32 voxels, flattened
} NM_NiftiVolume;

// Load a NIfTI file (nifti-1 or nifti-2, compressed or not).
// Returns NULL on failure. Caller must free with nm_nifti_free().
NM_NiftiVolume *nm_nifti_load(const char *path);

// Free a volume returned by nm_nifti_load.
void nm_nifti_free(NM_NiftiVolume *volume);

#ifdef __cplusplus
} // extern "C"
#endif
EOF

cat > Sources/CNifti/NiftiBridge.c <<'EOF'
// NiftiBridge.c
#include <stdlib.h>
#include <string.h>
#include "NiftiBridge.h"
#include "nifti1_io.h" // from niftilib; built with nifti2+znzlib

// Helper: convert arbitrary nifti_image->data into float32 array
static int convert_to_float32(const nifti_image *nim, float *out)
{
    size_t nvox = (size_t)nim->nx * (size_t)nim->ny * (size_t)nim->nz;
    int t = (nim->nt > 0) ? nim->nt : 1;
    nvox *= (size_t)t;

    switch (nim->datatype) {
        case NIFTI_TYPE_FLOAT32: {
            const float *src = (const float *)nim->data;
            memcpy(out, src, nvox * sizeof(float));
            return 0;
        }
        case NIFTI_TYPE_INT16: {
            const short *src = (const short *)nim->data;
            for (size_t i = 0; i < nvox; ++i) out[i] = (float)src[i];
            return 0;
        }
        case NIFTI_TYPE_UINT8: {
            const unsigned char *src = (const unsigned char *)nim->data;
            for (size_t i = 0; i < nvox; ++i) out[i] = (float)src[i];
            return 0;
        }
        default:
            // Add more datatypes here as needed.
            return -1;
    }
}

NM_NiftiVolume *nm_nifti_load(const char *path)
{
    if (!path) return NULL;

    // Read image with full data loaded
    nifti_image *nim = nifti_image_read(path, 1);
    if (!nim) return NULL;

    if (nim->ndim < 3) {
        nifti_image_free(nim);
        return NULL;
    }

    int nx = nim->nx;
    int ny = nim->ny;
    int nz = nim->nz;
    int nt = nim->nt > 0 ? nim->nt : 1;

    size_t nvox = (size_t)nx * (size_t)ny * (size_t)nz * (size_t)nt;

    float *data = (float *)malloc(nvox * sizeof(float));
    if (!data) {
        nifti_image_free(nim);
        return NULL;
    }

    if (convert_to_float32(nim, data) != 0) {
        free(data);
        nifti_image_free(nim);
        return NULL;
    }

    NM_NiftiVolume *vol = (NM_NiftiVolume *)calloc(1, sizeof(NM_NiftiVolume));
    if (!vol) {
        free(data);
        nifti_image_free(nim);
        return NULL;
    }

    vol->ndim       = nim->ndim;
    vol->width      = nx;
    vol->height     = ny;
    vol->depth      = nz;
    vol->timepoints = (nim->ndim >= 4) ? nt : 1;

    vol->spacingX   = (nim->pixdim[1] != 0.0f) ? nim->pixdim[1] : 1.0f;
    vol->spacingY   = (nim->pixdim[2] != 0.0f) ? nim->pixdim[2] : 1.0f;
    vol->spacingZ   = (nim->pixdim[3] != 0.0f) ? nim->pixdim[3] : 1.0f;

    vol->isNifti2   = (nim->nifti_type == NIFTI_FTYPE_NIFTI2_1 ||
                       nim->nifti_type == NIFTI_FTYPE_NIFTI2_2) ? 1 : 0;

    vol->voxelCount = nvox;
    vol->data       = data;

    // Done with nifti_image; we copied what we need
    nifti_image_free(nim);
    return vol;
}

void nm_nifti_free(NM_NiftiVolume *volume)
{
    if (!volume) return;
    if (volume->data) free(volume->data);
    free(volume);
}
EOF

echo "Creating Swift NIfTILoader..."

mkdir -p Sources/ChromaImagingKit/IO

cat > Sources/ChromaImagingKit/IO/NIfTILoader.swift <<'EOF'
import Foundation
import CNifti

public enum NIfTILoaderError: Error {
    case failedToOpen
    case unsupportedDimensions
    case missingData
}

public final class NIfTILoader {
    public init() {}

    /// Load a NIfTI file into a CIImageVolume.
    /// For now we take only the first 3D volume if the file is 4D.
    public func loadVolume(from url: URL) throws -> CIImageVolume {
        var result: CIImageVolume?

        try url.withUnsafeFileSystemRepresentation { cPath in
            guard let cPath = cPath else {
                throw NIfTILoaderError.failedToOpen
            }

            guard let ptr = nm_nifti_load(cPath) else {
                throw NIfTILoaderError.failedToOpen
            }
            defer { nm_nifti_free(ptr) }

            let vol = ptr.pointee

            guard vol.width > 0, vol.height > 0, vol.depth > 0 else {
                throw NIfTILoaderError.unsupportedDimensions
            }
            guard vol.voxelCount > 0, vol.data != nil else {
                throw NIfTILoaderError.missingData
            }

            let width  = Int(vol.width)
            let height = Int(vol.height)
            let depth  = Int(vol.depth)

            let spacingX = vol.spacingX
            let spacingY = vol.spacingY
            let spacingZ = vol.spacingZ

            let count = Int(vol.voxelCount)
            let dataPtr = vol.data!

            // Copy C float* into Swift [Float]
            let buffer = Array(
                UnsafeBufferPointer(start: dataPtr, count: count)
            )

            // NOTE: we ignore timepoints for now and treat as 3D volume.
            // Later you can extend CIImageVolume or add CIImageVolume4D.
            result = CIImageVolume(
                width: width,
                height: height,
                depth: depth,
                spacing: (spacingX, spacingY, spacingZ),
                voxels: buffer
            )
        }

        guard let volume = result else {
            throw NIfTILoaderError.failedToOpen
        }
        return volume
    }
}
EOF

echo ""
echo "Done creating bridge + loader files."
echo ""
echo "NEXT STEPS:"
echo "1) Copy niftilib/, nifti2/, znzlib/ from your nifti_clib source into:"
echo "     ChromaImagingKit/Sources/CNifti/"
echo "   so you end up with:"
echo "     Sources/CNifti/niftilib/..."
echo "     Sources/CNifti/nifti2/..."
echo "     Sources/CNifti/znzlib/..."
echo ""
echo "2) Update ChromaImagingKit/Package.swift to add:"
echo "     .target(name: \"CNifti\", path: \"Sources/CNifti\", publicHeadersPath: \".\"),"
echo "     and add \"CNifti\" to the dependencies of the ChromaImagingKit target."
echo ""
echo "Then open Xcode and build the ChromaImagingKit package."
EOF
