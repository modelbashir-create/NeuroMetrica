#include "SliceProvenance.h"

#include "../DICOM/DicomTagExtractors.h"
#include "../Utils/ITKBridgeUtils.h"

std::string buildSliceProvenanceJSON(const std::vector<itk::MetaDataDictionary> &dictionaries) {
    if (dictionaries.empty()) {
        return "";
    }

    std::string json = "[";
    for (size_t i = 0; i < dictionaries.size(); ++i) {
        const auto &dict = dictionaries[i];
        if (i > 0) { json += ","; }
        json += "{";

        bool firstField = true;
        std::string instanceUID;
        if (extractDicomString(dict, "0008|0018", instanceUID)) {
            if (!firstField) { json += ","; }
            firstField = false;
            json += "\"instanceUID\":\"";
            json += escapeJSON(instanceUID);
            json += "\"";
        }

        double instanceNumber = 0.0;
        if (extractDicomScalar(dict, "0020|0013", instanceNumber)) {
            if (!firstField) { json += ","; }
            firstField = false;
            json += "\"instanceNumber\":";
            json += jsonNumber(instanceNumber);
        }

        std::vector<double> ipp;
        if (extractDicomVector(dict, "0020|0032", 3, ipp)) {
            if (!firstField) { json += ","; }
            firstField = false;
            json += "\"imagePositionPatient\":[";
            for (size_t j = 0; j < ipp.size(); ++j) {
                if (j > 0) { json += ","; }
                json += jsonNumber(ipp[j]);
            }
            json += "]";
        }

        std::vector<double> iop;
        if (extractDicomVector(dict, "0020|0037", 6, iop)) {
            if (!firstField) { json += ","; }
            firstField = false;
            json += "\"imageOrientationPatient\":[";
            for (size_t j = 0; j < iop.size(); ++j) {
                if (j > 0) { json += ","; }
                json += jsonNumber(iop[j]);
            }
            json += "]";
        }

        json += "}";
    }
    json += "]";
    return json;
}
