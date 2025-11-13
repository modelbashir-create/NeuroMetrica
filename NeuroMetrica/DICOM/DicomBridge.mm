//
//  DicomBridge.mm
//  NeuroMetrica
//
//

#import "DicomBridge.h"



int32_t nm_load_dicom_study(const char *path, NM_DicomStudy *outStudy) {
    (void)path;
    if (outStudy) {
        outStudy->patientName = "";
        outStudy->description = "";
        outStudy->modalitySummary = "";
        outStudy->studyDateEpoch = 0;
        outStudy->seriesCount = 0;
        outStudy->series = nullptr;
    }
  
    return -1;
}

void nm_free_dicom_study(NM_DicomStudy *study) {

    (void)study;
}
