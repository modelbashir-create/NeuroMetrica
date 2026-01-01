#pragma once

#include <string>
#include <vector>

#include "../DICOM/GeometryValidation.h"
#include "../DICOM/SeriesGrouping.h"
#include "../Utils/ITKBridgeUtils.h"
#include "ITKBridge.h"
#include "itkGDCMSeriesFileNames.h"

struct SubseriesCandidate {
    std::string seriesUID;
    std::string key;
    size_t fileCount = 0;
    int confidence = 0;
    bool orientationConsistent = false;
    bool spacingUniform = false;
    double spacingReference = 0.0;
    double maxSpacingError = 0.0;
    std::vector<std::string> reasons;
};

struct SeriesDiagnosticsResult {
    std::string selectedSeriesUID;
    std::string selectedSubseriesKey;
    int selectedConfidence = 0;
    std::string seriesDiagnosticsJSON;
    std::string subseriesDiagnosticsJSON;
    std::string selectedInfoJSON;
};

SeriesDiagnosticsResult buildSeriesDiagnostics(
    const itk::GDCMSeriesFileNames::Pointer &nameGen,
    const std::vector<std::string> &seriesUIDs,
    ITKDicomBackendC backend);

std::string seriesCandidatesToJSON(const std::vector<SeriesCandidateRecord> &candidates);

std::string seriesSelectionInfoToJSON(const SeriesCandidateRecord &selected,
                                      const std::vector<std::string> &groupingKeysUsed,
                                      const std::string &orderingMethod,
                                      bool fallbackUsed,
                                      const std::string &selectionReason);

std::string geometryValidationToJSON(const GeometryValidationResult &validation);
