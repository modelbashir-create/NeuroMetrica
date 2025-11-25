//
//  DicomBridge.h
//  DCMTKLoader
//
//  Low-level C interface for loading DICOM series via DCMTK.
//

#ifndef DICOM_BRIDGE_H
#define DICOM_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

#if __has_include(<Foundation/Foundation.h>)
#include <Foundation/Foundation.h>
#define NM_ENUM NS_ENUM
#else
#define NM_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

/// Error codes returned by nm_dicom_load_series.
/// 0 indicates success.
typedef NM_ENUM(int32_t, NM_DicomError) {
    NM_DicomErrorNone = 0,
    NM_DicomErrorNoFiles = 1,
    NM_DicomErrorLoadFailed = 2,
    NM_DicomErrorInvalidDimensions = 3,
    NM_DicomErrorAllocationFailed = 4
};

typedef enum {
    NM_DicomTagValueTypeString = 0,
    NM_DicomTagValueTypeInt = 1,
    NM_DicomTagValueTypeDouble = 2,
    NM_DicomTagValueTypeData = 3
} NM_DicomTagValueType;

/// A simple key/value representation for arbitrary DICOM tags.
typedef struct {
    char *tagKey;               // "gggg,eeee" format
    NM_DicomTagValueType valueType;
    char *stringValue;          // owned C string when valueType == String
    long long intValue;         // used when valueType == Int
    double doubleValue;         // used when valueType == Double
    uint8_t *dataValue;         // owned data buffer when valueType == Data
    size_t dataLength;
} NM_DicomTagEntry;

/// A C-friendly representation of a 3D DICOM volume with rich metadata.
typedef struct {
    int width;
    int height;
    int depth;
    float spacingX;
    float spacingY;
    float spacingZ;
    float sliceThickness;
    float spacingBetweenSlices;
    double orientation[6];
    double position[3];

    // Identity / geometry metadata
    char *frameOfReferenceUID;
    char *patientName;
    char *patientID;
    char *patientSex;
    char *patientBirthDate;
    char *studyInstanceUID;
    char *seriesInstanceUID;
    char *studyDescription;
    char *seriesDescription;
    char *modality;

    // Pixel description
    int bitsAllocated;
    int bitsStored;
    int highBit;
    int pixelRepresentation;
    char *photometricInterpretation;
    float rescaleSlope;
    float rescaleIntercept;
    double *windowCenters;
    double *windowWidths;
    int windowCount;

    NM_DicomTagEntry *allTags;
    int allTagCount;

    float *voxels; // contiguous float32 buffer, length = width * height * depth
} NM_DicomVolume;

/// Loads a DICOM series from the directory at `directoryPath`.
/// On success, returns NM_DicomErrorNone and sets `*outVolume` to a newly allocated NM_DicomVolume.
/// The caller must free the returned volume with `nm_dicom_free`.
NM_DicomError nm_dicom_load_series(const char *directoryPath, NM_DicomVolume **outVolume);

/// Frees memory allocated by `nm_dicom_load_series`.
void nm_dicom_free(NM_DicomVolume *volume);

#ifdef __cplusplus
}
#endif

#endif /* DICOM_BRIDGE_H */
