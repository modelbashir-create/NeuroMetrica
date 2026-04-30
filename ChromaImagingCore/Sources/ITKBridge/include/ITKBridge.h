//
//  ITKBridge.h
//  ITKBridge
//
//  Thin C/ObjC++ façade over ITK for volume loading.
//
//  Responsibilities:
//  - Expose a C-friendly descriptor for ITK images (ITKImageDescriptorC)
//  - Provide functions to load:
//      * DICOM series (directory) via GDCM/DCMTK
//      * Single-file volumes (NIfTI, NRRD, etc.) via ImageFileReader/ImageIOFactory
//  - Provide a simple version query for debugging
//
//  Ownership / lifetime:
//  - The bridge allocates a contiguous voxel buffer on the heap.
//  - Swift code should COPY the buffer into its own storage, then call
//    ITKFreeImageDescriptor(&descriptor) to release bridge-owned memory.
//

#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Pixel type classification compatible with ITKImageIOBase::IOPixelType.
/// Keep this in sync with the Swift-side ITKPixelType enum (raw Int32).
typedef enum ITKPixelTypeC : int32_t {
    ITKPixelType_Unknown = 0,
    ITKPixelType_Scalar  = 1,
    ITKPixelType_RGB     = 2,
    ITKPixelType_RGBA    = 3,
    ITKPixelType_Vector  = 4,
    ITKPixelType_Complex = 5
} ITKPixelTypeC;

/// Preferred DICOM backend for ITK series loading.
typedef enum ITKDicomBackendC : int32_t {
    /// Auto-select (prefer DCMTK when available, else GDCM).
    ITKDicomBackend_Auto  = 0,
    /// Force DCMTK.
    ITKDicomBackend_DCMTK = 1,
    /// Force GDCM.
    ITKDicomBackend_GDCM  = 2
} ITKDicomBackendC;

/// C descriptor for an ITK volume image.
///
/// All numeric fields are filled by the bridge based on the underlying
/// itk::ImageBase / ImageIOBase. The buffer is a contiguous block of
/// voxels in x-fastest layout (i,j,k,component) that higher layers can
/// copy into their own storage.
typedef struct ITKImageDescriptorC {
    /// Image dimension (typically 3 for volumetric medical images).
    int32_t   dimension;

    /// Size in voxels along each axis. For dimensions < 4, remaining slots are 1.
    uint64_t  size[4];

    /// Physical spacing in mm along each axis. For dimensions < 4, remaining slots are 1.0.
    double    spacing[4];

    /// World-space origin (in mm) of index (0,0,0,0).
    double    origin[4];

    /// Direction cosines as a row-major dim x dim matrix.
    /// For example, for 3D: first 9 elements are a 3x3 matrix.
    double    direction[16];

    /// Pixel type classification (scalar, RGB, etc.).
    ITKPixelTypeC pixelType;

    /// Number of scalar components per pixel (e.g. 1 for scalar, 3 for RGB).
    int32_t   componentsPerPixel;

    /// Total number of scalar values in the buffer:
    ///   valueCount = size[0] * size[1] * size[2] * ... * componentsPerPixel
    uint64_t  valueCount;

    /// Pointer to a contiguous heap-allocated voxel buffer.
    /// Layout is x-fastest, then y, then z, then component.
    /// Element type is described by componentBytes + isSigned.
    const void *bufferHandle;

    /// Size in bytes of a single scalar component (e.g. 2 for uint16, 4 for float32).
    int32_t   componentBytes;

    /// Non-zero if the scalar component type is signed (e.g. int16, float),
    /// zero if unsigned (e.g. uint16).
    int32_t   isSigned;

    /// Optional JSON metadata string (UTF-8) with tag/value pairs.
    const char *metadataJSON;

    /// Length in bytes of metadataJSON (excluding null terminator).
    int32_t metadataJSONLength;

    /// Optional JSON array (UTF-8) describing per-slice provenance.
    const char *sliceProvenanceJSON;

    /// Length in bytes of sliceProvenanceJSON (excluding null terminator).
    int32_t sliceProvenanceJSONLength;
} ITKImageDescriptorC;

/// Heap-allocated UTF-8 JSON payload returned by inspection APIs.
typedef struct ITKJSONStringResultC {
    /// Pointer to a null-terminated UTF-8 JSON string.
    const char *json;

    /// Length in bytes of `json` (excluding null terminator).
    int32_t jsonLength;
} ITKJSONStringResultC;


/// Fill `buffer` with a human-readable ITK version string.
///
/// Returns true on success. The string is always null-terminated
/// as long as bufferLength > 0.
bool ITKBridgeGetVersionString(char *buffer, int bufferLength);

/// Returns true if the ITK build has DCMTK support enabled.
bool ITKBridgeSupportsDCMTK(void);


/// Load a DICOM series from a directory.
///
/// directoryPath:
///   Filesystem path to a directory containing DICOM slices.
/// outDescriptor:
///   On success, filled with dimension/size/spacing/origin/direction/pixel info,
///   and a heap-allocated contiguous voxel buffer.
/// errorBuffer:
///   Optional output buffer for a textual error message (UTF-8).
/// errorBufferLength:
///   Length in bytes of errorBuffer.
///
/// Returns:
///   true on success, false on failure. On failure, outDescriptor is left
///   in a zeroed/undefined state and errorBuffer (if provided) contains a message.
bool ITKLoadDicomSeries(const char *directoryPath,
                        ITKImageDescriptorC *outDescriptor,
                        char *errorBuffer,
                        int errorBufferLength);

/// Load a DICOM series from a directory, forcing a specific backend.
bool ITKLoadDicomSeriesWithBackend(const char *directoryPath,
                                   ITKDicomBackendC backend,
                                   ITKImageDescriptorC *outDescriptor,
                                   char *errorBuffer,
                                   int errorBufferLength);

/// Load a DICOM series selection from a directory, forcing a specific backend.
///
/// `seriesInstanceUID` and `subseriesKey` are optional. Pass NULL to use the
/// bridge's automatic selection. `subseriesKey` only applies within the chosen
/// series UID.
bool ITKLoadDicomSeriesSelectionWithBackend(const char *directoryPath,
                                            const char *seriesInstanceUID,
                                            const char *subseriesKey,
                                            ITKDicomBackendC backend,
                                            ITKImageDescriptorC *outDescriptor,
                                            char *errorBuffer,
                                            int errorBufferLength);

/// Inspect a DICOM directory and return JSON describing detected series and
/// candidate subseries without loading voxel data.
bool ITKInspectDicomDirectory(const char *directoryPath,
                              ITKJSONStringResultC *outResult,
                              char *errorBuffer,
                              int errorBufferLength);

/// Inspect a DICOM directory and return JSON describing detected series and
/// candidate subseries, forcing a specific backend.
bool ITKInspectDicomDirectoryWithBackend(const char *directoryPath,
                                         ITKDicomBackendC backend,
                                         ITKJSONStringResultC *outResult,
                                         char *errorBuffer,
                                         int errorBufferLength);


/// Load a single-file volume (NIfTI, NRRD, MetaImage, etc.).
///
/// filePath:
///   Filesystem path to a single volume file. ITK's ImageIOFactory is used
///   to select the correct format handler.
/// outDescriptor / errorBuffer:
///   Same semantics as ITKLoadDicomSeries().
bool ITKLoadSingleFileVolume(const char *filePath,
                             ITKImageDescriptorC *outDescriptor,
                             char *errorBuffer,
                             int errorBufferLength);

/// Load a single-file DICOM volume (e.g., Secondary Capture) via a backend.
///
/// filePath:
///   Filesystem path to a single DICOM file.
/// backend:
///   Preferred DICOM IO backend (DCMTK vs GDCM).
/// outDescriptor / errorBuffer:
///   Same semantics as ITKLoadDicomSeries().
bool ITKLoadDicomFileWithBackend(const char *filePath,
                                 ITKDicomBackendC backend,
                                 ITKImageDescriptorC *outDescriptor,
                                 char *errorBuffer,
                                 int errorBufferLength);


/// Free resources owned by the descriptor (primarily the voxel buffer).
///
/// After this call, bufferHandle is set to NULL, valueCount is zeroed,
/// and the rest of the fields are left in a safe default state.
void ITKFreeImageDescriptor(ITKImageDescriptorC *descriptor);

/// Free resources owned by a JSON inspection result.
void ITKFreeJSONStringResult(ITKJSONStringResultC *result);

#ifdef __cplusplus
} // extern "C"
#endif
