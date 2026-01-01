#pragma once

#include "ITKBridge.h"

#include <map>
#include <string>
#include <vector>

#include "itkImage.h"
#include "itkMetaDataDictionary.h"
#include "itkImageIOBase.h"
#if __has_include("itkDCMTKImageIO.h")
#define ITKBRIDGE_HAS_DCMTK 1
#else
#define ITKBRIDGE_HAS_DCMTK 0
#endif

#include "../DICOM/GeometryValidation.h"
#include "../DICOM/SeriesGrouping.h"
#include "../Diagnostics/SeriesDiagnostics.h"

using Float3DImage = itk::Image<float, 3>;

struct MetadataOverrides {
    std::map<std::string, std::vector<double>> numericOverrides;
    std::map<std::string, double> scalarOverrides;
    std::map<std::string, bool> boolOverrides;
};

struct DicomSeriesMetadata {
    std::string orderingMethod;
    GroupingResult grouping;
    size_t groupingRejectedCount = 0;
    SeriesCandidateRecord selectedCandidate;
    std::string selectedCandidateId;
    bool hasSelectedCandidate = false;
    SeriesDiagnosticsResult diagnostics;
    bool hasSeriesDiagnostics = false;
    GeometryValidationResult geometryValidation;
    bool hasGeometryValidation = false;
    std::vector<std::string> missingGeometryTags;
    std::vector<std::string> orderingAssumptions;
    std::string geometryReliability;
    bool isMultiFrame = false;
    std::string multiFrameWarning;
};

struct MetadataContext {
    itk::MetaDataDictionary baseDictionary;
    std::vector<itk::MetaDataDictionary> sliceDictionaries;
    MetadataOverrides overrides;
    DicomSeriesMetadata dicomMetadata;
    bool hasDicomMetadata = false;
};

struct VolumeLoadResult {
    Float3DImage::Pointer image;
    MetadataContext metadata;
};

bool supportsDCMTK();
void registerDicomIOFactories();
itk::ImageIOBase::Pointer makeDicomIO(ITKDicomBackendC backend);

VolumeLoadResult loadDicomSeries(const char *directoryPath, ITKDicomBackendC backend);
VolumeLoadResult loadSingleFileVolume(const char *filePath);
VolumeLoadResult loadDicomFile(const char *filePath, ITKDicomBackendC backend);
