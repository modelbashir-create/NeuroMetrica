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
