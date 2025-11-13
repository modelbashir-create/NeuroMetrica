
// DicomBridge.hpp
#pragma once
#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int width;
    int height;
    int depth;
    float spacing[3];
    float direction[9];
    int16_t *pixels;
} NM_DicomVolume;

typedef struct {
    const char *description;
    const char *modality;
    const char *bodyPart;
    int volumeCount;
    NM_DicomVolume *volumes;
} NM_DicomSeries;

typedef struct {
    const char *patientName;
    const char *description;
    const char *modalitySummary;
    long long studyDateEpoch;
    int seriesCount;
    NM_DicomSeries *series;
} NM_DicomStudy;

int32_t nm_load_dicom_study(const char *path, NM_DicomStudy *outStudy);
void nm_free_dicom_study(NM_DicomStudy *study);

#ifdef __cplusplus
}
#endif
