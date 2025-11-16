// NiftiBridge.c
#include <stdlib.h>
#include <string.h>
#include "NiftiBridge.h"
#include "nifti2_io.h" // from niftilib; built with nifti2+znzlib

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

#ifdef NIFTI_FTYPE_NIFTI2_1
    vol->isNifti2   = (nim->nifti_type == NIFTI_FTYPE_NIFTI2_1 ||
                       nim->nifti_type == NIFTI_FTYPE_NIFTI2_2) ? 1 : 0;
#else
    vol->isNifti2   = 0;
#endif

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
