#include "DicomSeriesLoader.h"

#include <algorithm>
#include <cmath>

#include "itkImageSeriesReader.h"
#include "itkGDCMImageIO.h"
#include "itkGDCMImageIOFactory.h"
#include "itkGDCMSeriesFileNames.h"
#if __has_include("itkDCMTKImageIO.h")
#include "itkDCMTKImageIO.h"
#endif
#if __has_include("itkDCMTKImageIOFactory.h")
#include "itkDCMTKImageIOFactory.h"
#define ITKBRIDGE_HAS_DCMTK_FACTORY 1
#else
#define ITKBRIDGE_HAS_DCMTK_FACTORY 0
#endif

#include "../DICOM/DicomTagExtractors.h"
#include "../DICOM/SeriesGrouping.h"
#include "../DICOM/SliceOrdering.h"
#include "../DICOM/GeometryValidation.h"
#include "../Diagnostics/SeriesDiagnostics.h"

bool supportsDCMTK() {
#if ITKBRIDGE_HAS_DCMTK
    return true;
#else
    return false;
#endif
}

void registerDicomIOFactories() {
    static bool registered = false;
    if (registered) {
        return;
    }

    itk::GDCMImageIOFactory::RegisterOneFactory();
#if ITKBRIDGE_HAS_DCMTK_FACTORY
    itk::DCMTKImageIOFactory::RegisterOneFactory();
#endif
    registered = true;
}

itk::ImageIOBase::Pointer makeDicomIO(ITKDicomBackendC backend) {
    const bool wantsDCMTK = (backend == ITKDicomBackend_DCMTK);
    const bool wantsGDCM = (backend == ITKDicomBackend_GDCM);

#if ITKBRIDGE_HAS_DCMTK
    if (wantsDCMTK || (!wantsGDCM && backend == ITKDicomBackend_Auto)) {
        return itk::DCMTKImageIO::New();
    }
#endif

    return itk::GDCMImageIO::New();
}

namespace {

std::vector<itk::MetaDataDictionary> readDictionaries(
    const std::vector<std::string> &fileNames,
    ITKDicomBackendC backend) {
    std::vector<itk::MetaDataDictionary> dictionaries;
    dictionaries.reserve(fileNames.size());

    itk::ImageIOBase::Pointer dicomIO = makeDicomIO(backend);
    for (const auto &file : fileNames) {
        dicomIO->SetFileName(file);
        dicomIO->ReadImageInformation();
        dictionaries.push_back(dicomIO->GetMetaDataDictionary());
    }
    return dictionaries;
}

std::vector<itk::MetaDataDictionary> copyDictionaryArray(
    const itk::ImageSeriesReader<Float3DImage>::DictionaryArrayType *dictArray) {
    std::vector<itk::MetaDataDictionary> dictionaries;
    if (!dictArray) {
        return dictionaries;
    }
    dictionaries.reserve(dictArray->size());
    for (size_t i = 0; i < dictArray->size(); ++i) {
        const auto *dict = dictArray->at(i);
        if (dict) {
            dictionaries.push_back(*dict);
        }
    }
    return dictionaries;
}

itk::GDCMSeriesFileNames::Pointer makeSeriesNameGenerator(const char *directoryPath) {
    using GDCMNameGenType = itk::GDCMSeriesFileNames;

    registerDicomIOFactories();
    GDCMNameGenType::Pointer nameGen = GDCMNameGenType::New();
    nameGen->SetUseSeriesDetails(true);
    nameGen->AddSeriesRestriction("0008|0021");
    nameGen->SetDirectory(directoryPath);
    return nameGen;
}

} // namespace

VolumeLoadResult loadDicomSeries(const char *directoryPath,
                                 ITKDicomBackendC backend) {
    return loadDicomSeriesSelection(directoryPath, nullptr, nullptr, backend);
}

std::string inspectDicomDirectory(const char *directoryPath, ITKDicomBackendC backend) {
    auto nameGen = makeSeriesNameGenerator(directoryPath);
    const std::vector<std::string> &seriesUIDs = nameGen->GetSeriesUIDs();
    if (seriesUIDs.empty()) {
        throw itk::ExceptionObject(__FILE__, __LINE__,
                                   "No DICOM series found in directory",
                                   "ITKBridge");
    }

    SeriesDiagnosticsResult diagnostics = buildSeriesDiagnostics(nameGen, seriesUIDs, backend);
    return diagnostics.inspectionJSON;
}

VolumeLoadResult loadDicomSeriesSelection(const char *directoryPath,
                                          const char *seriesInstanceUID,
                                          const char *subseriesKey,
                                          ITKDicomBackendC backend) {
    using ImageType   = Float3DImage;
    using ReaderType  = itk::ImageSeriesReader<ImageType>;
    auto nameGen = makeSeriesNameGenerator(directoryPath);

    const std::vector<std::string> &seriesUIDs = nameGen->GetSeriesUIDs();
    if (seriesUIDs.empty()) {
        throw itk::ExceptionObject(__FILE__, __LINE__,
                                   "No DICOM series found in directory",
                                   "ITKBridge");
    }

    SeriesDiagnosticsResult diagnostics = buildSeriesDiagnostics(nameGen, seriesUIDs, backend);
    const std::string requestedSeriesUID = seriesInstanceUID ? seriesInstanceUID : "";
    const std::string requestedSubseriesKey = subseriesKey ? subseriesKey : "";

    std::string selectedSeriesUID = requestedSeriesUID;
    if (selectedSeriesUID.empty()) {
        selectedSeriesUID = diagnostics.selectedSeriesUID.empty() ? seriesUIDs.front() : diagnostics.selectedSeriesUID;
    } else {
        const bool seriesExists = std::find(seriesUIDs.begin(), seriesUIDs.end(), selectedSeriesUID) != seriesUIDs.end();
        if (!seriesExists) {
            throw itk::ExceptionObject(__FILE__, __LINE__,
                                       "Requested DICOM series was not found in directory",
                                       "ITKBridge");
        }
    }
    std::vector<std::string> fileNames = nameGen->GetFileNames(selectedSeriesUID);

    if (fileNames.empty()) {
        throw itk::ExceptionObject(__FILE__, __LINE__,
                                   "DICOM series has no files",
                                   "ITKBridge");
    }

    const double spacingEpsilon = 1e-2;
    const double orientationEpsilon = 1e-6;

    std::vector<itk::MetaDataDictionary> dictionaries = readDictionaries(fileNames, backend);
    const bool isMultiFrameInput = isMultiFrameSeries(dictionaries);
    bool inputReordered = false;
    SliceOrderingResult preOrder;
    GroupingResult grouping;
    size_t groupingRejectedCount = 0;

    if (!isMultiFrameInput) {
        grouping = groupFilesByTags(fileNames, dictionaries);
        if (!requestedSubseriesKey.empty()) {
            const auto requestedGroup = grouping.groupIndices.find(requestedSubseriesKey);
            if (requestedGroup == grouping.groupIndices.end()) {
                throw itk::ExceptionObject(__FILE__, __LINE__,
                                           "Requested DICOM subseries was not found in series",
                                           "ITKBridge");
            }
            grouping.selectedKey = requestedSubseriesKey;
            grouping.selectedIndices = requestedGroup->second;
            grouping.selectedSliceCount = requestedGroup->second.size();
            grouping.selectionReason = "user_selected_subseries";
        }
        if (!grouping.selectedIndices.empty() && grouping.selectedIndices.size() != fileNames.size()) {
            std::vector<std::string> groupedFileNames;
            std::vector<itk::MetaDataDictionary> groupedDicts;
            groupedFileNames.reserve(grouping.selectedIndices.size());
            groupedDicts.reserve(grouping.selectedIndices.size());
            for (size_t idx : grouping.selectedIndices) {
                groupedFileNames.push_back(fileNames[idx]);
                groupedDicts.push_back(dictionaries[idx]);
            }
            groupingRejectedCount = fileNames.size() - groupedFileNames.size();
            fileNames.swap(groupedFileNames);
            dictionaries.swap(groupedDicts);
        }
    }
    if (!isMultiFrameInput) {
        preOrder = computeSliceOrderingFromDictionaries(fileNames, dictionaries, orientationEpsilon);
        if (preOrder.canOrder && preOrder.order.size() == fileNames.size()) {
            std::vector<std::string> orderedFileNames;
            std::vector<itk::MetaDataDictionary> orderedDicts;
            orderedFileNames.reserve(fileNames.size());
            orderedDicts.reserve(fileNames.size());
            for (size_t idx : preOrder.order) {
                orderedFileNames.push_back(fileNames[idx]);
                orderedDicts.push_back(dictionaries[idx]);
            }
            fileNames.swap(orderedFileNames);
            dictionaries.swap(orderedDicts);
            inputReordered = true;
        }
    }
    const std::string orderingMethod = preOrder.canOrder
        ? preOrder.method
        : (isMultiFrameInput ? "multiframe_native" : "file_index");

    ReaderType::Pointer reader = ReaderType::New();
    itk::ImageIOBase::Pointer dicomIO = makeDicomIO(backend);
    reader->SetImageIO(dicomIO);
    reader->SetFileNames(fileNames);
    reader->Update();

    const auto *dictArray = reader->GetMetaDataDictionaryArray();
    std::vector<itk::MetaDataDictionary> readerDictionaries = copyDictionaryArray(dictArray);
    if (!readerDictionaries.empty()) {
        dictionaries = readerDictionaries;
    }

    MetadataContext metadata;
    metadata.baseDictionary = reader->GetImageIO()->GetMetaDataDictionary();
    metadata.sliceDictionaries = dictionaries;

    auto &numericOverrides = metadata.overrides.numericOverrides;
    auto &scalarOverrides = metadata.overrides.scalarOverrides;
    auto &boolOverrides = metadata.overrides.boolOverrides;

    std::string selectedCandidateId;
    SeriesCandidateRecord selectedCandidate;
    bool hasSelectedCandidate = false;
    if (!grouping.selectedKey.empty()) {
        selectedCandidateId = "group:" + grouping.selectedKey;
        for (auto &candidate : grouping.candidates) {
            if (candidate.candidateId == selectedCandidateId) {
                candidate.orderingMethod = orderingMethod;
                candidate.rejectionReason.clear();
                selectedCandidate = candidate;
                hasSelectedCandidate = true;
                break;
            }
        }
    }

    if (!requestedSeriesUID.empty() || !requestedSubseriesKey.empty()) {
        diagnostics.selectedSeriesUID = selectedSeriesUID;
        diagnostics.selectedSubseriesKey = grouping.selectedKey;
        diagnostics.selectedConfidence = 0;
        for (const auto &candidate : diagnostics.subseriesCandidates) {
            if (candidate.seriesUID == diagnostics.selectedSeriesUID
                && candidate.key == diagnostics.selectedSubseriesKey) {
                diagnostics.selectedConfidence = candidate.confidence;
                break;
            }
        }
        diagnostics.selectedInfoJSON = selectedSeriesInfoToJSON(
            diagnostics.selectedSeriesUID,
            diagnostics.selectedSubseriesKey,
            diagnostics.selectedConfidence
        );
    }

    std::vector<std::string> missingGeometryTags;
    std::vector<std::string> orderingAssumptions;
    std::string geometryReliability = "native";

    if (!grouping.keysUsed.empty()) {
        scalarOverrides["groupingRejectedCount"] = static_cast<double>(groupingRejectedCount);
    }

    if (dictArray && !dictArray->empty()) {
        const auto *firstDict = dictArray->at(0);
        std::vector<double> iop;
        std::vector<double> ipp;
        const bool hasIOP = firstDict
            ? extractDicomVector(*firstDict, "0020|0037", 6, iop)
            : false;
        const bool hasIPP = firstDict
            ? extractDicomVector(*firstDict, "0020|0032", 3, ipp)
            : false;
        double sliceLocation = 0.0;
        const bool hasSliceLocation = firstDict
            ? extractDicomScalar(*firstDict, "0020|1041", sliceLocation)
            : false;

        if (!hasIOP) { missingGeometryTags.push_back("0020|0037"); }
        if (!hasIPP) { missingGeometryTags.push_back("0020|0032"); }
        if (!hasSliceLocation) { missingGeometryTags.push_back("0020|1041"); }

        if (preOrder.canOrder && preOrder.order.size() == fileNames.size()) {
            std::vector<double> orderAsDouble;
            orderAsDouble.reserve(preOrder.order.size());
            for (size_t idx : preOrder.order) {
                orderAsDouble.push_back(static_cast<double>(idx));
            }
            numericOverrides["_sliceOrder"] = orderAsDouble;
        }

        if (hasIOP) {
            numericOverrides["0020,0037"] = iop;
        }
        if (hasIPP) {
            numericOverrides["0020,0032"] = ipp;
        }

        if (firstDict) {
            std::vector<double> pixelSpacing;
            if (extractDicomVector(*firstDict, "0028|0030", 2, pixelSpacing)) {
                numericOverrides["0028,0030"] = pixelSpacing;
            }

            std::vector<double> windowCenter;
            if (extractDicomVectorAny(*firstDict, "0028|1050", windowCenter)) {
                numericOverrides["0028,1050"] = windowCenter;
            }

            std::vector<double> windowWidth;
            if (extractDicomVectorAny(*firstDict, "0028|1051", windowWidth)) {
                numericOverrides["0028,1051"] = windowWidth;
            }
        }

        double scalarValue = 0.0;
        if (firstDict && extractDicomScalar(*firstDict, "0018|0050", scalarValue)) {
            scalarOverrides["0018,0050"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0018|0088", scalarValue)) {
            scalarOverrides["0018,0088"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0028|0010", scalarValue)) {
            scalarOverrides["0028,0010"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0028|0011", scalarValue)) {
            scalarOverrides["0028,0011"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0028|0100", scalarValue)) {
            scalarOverrides["0028,0100"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0028|0101", scalarValue)) {
            scalarOverrides["0028,0101"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0028|0102", scalarValue)) {
            scalarOverrides["0028,0102"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0028|0103", scalarValue)) {
            scalarOverrides["0028,0103"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0028|1052", scalarValue)) {
            scalarOverrides["0028,1052"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0028|1053", scalarValue)) {
            scalarOverrides["0028,1053"] = scalarValue;
        }
        bool isMultiFrame = false;
        if (firstDict && extractDicomScalar(*firstDict, "0028|0008", scalarValue)) {
            scalarOverrides["0028,0008"] = scalarValue;
            if (scalarValue > 1.0) {
                isMultiFrame = true;
            }
        }
        if (firstDict && extractDicomScalar(*firstDict, "0020|1209", scalarValue)) {
            scalarOverrides["0020,1209"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0020|0011", scalarValue)) {
            scalarOverrides["0020,0011"] = scalarValue;
        }
        if (firstDict && extractDicomScalar(*firstDict, "0020|0013", scalarValue)) {
            scalarOverrides["0020,0013"] = scalarValue;
        }

        if (isMultiFrame) {
            boolOverrides["_multiFrame"] = true;
        }
    }

    if (dictArray && dictArray->size() > 1) {
        const auto *firstDict = dictArray->at(0);
        bool isMultiFrame = false;
        double scalarValue = 0.0;
        if (firstDict && extractDicomScalar(*firstDict, "0028|0008", scalarValue)) {
            if (scalarValue > 1.0) {
                isMultiFrame = true;
            }
        }

        if (!isMultiFrame) {
            double firstRows = 0.0;
            double firstColumns = 0.0;
            double firstBitsAllocated = 0.0;
            double firstBitsStored = 0.0;
            double firstPixelRep = 0.0;
            bool hasRows = firstDict && extractDicomScalar(*firstDict, "0028|0010", firstRows);
            bool hasColumns = firstDict && extractDicomScalar(*firstDict, "0028|0011", firstColumns);
            bool hasBitsAllocated = firstDict && extractDicomScalar(*firstDict, "0028|0100", firstBitsAllocated);
            bool hasBitsStored = firstDict && extractDicomScalar(*firstDict, "0028|0101", firstBitsStored);
            bool hasPixelRep = firstDict && extractDicomScalar(*firstDict, "0028|0103", firstPixelRep);

            std::vector<double> firstPixelSpacing;
            bool hasPixelSpacing = firstDict && extractDicomVector(*firstDict, "0028|0030", 2, firstPixelSpacing);
            double firstSliceThickness = 0.0;
            double firstSpacingBetween = 0.0;
            bool hasSliceThickness = firstDict && extractDicomScalar(*firstDict, "0018|0050", firstSliceThickness);
            bool hasSpacingBetween = firstDict && extractDicomScalar(*firstDict, "0018|0088", firstSpacingBetween);

            bool pixelDataConsistent = true;
            bool geometryConsistent = true;
            bool orientationConsistent = true;
            bool spacingUniform = true;
            bool spacingReferenceSet = false;
            double spacingReference = 0.0;
            double maxSpacingError = 0.0;

            std::vector<double> distances;
            distances.reserve(dictArray->size());
            std::vector<size_t> sliceOrder;

            std::vector<double> iop;
            std::vector<double> ipp;
            const bool hasIOP = firstDict
                ? extractDicomVector(*firstDict, "0020|0037", 6, iop)
                : false;
            const bool hasIPP = firstDict
                ? extractDicomVector(*firstDict, "0020|0032", 3, ipp)
                : false;

            bool canOrder = hasIOP && hasIPP;
            double scanAxis[3] = {0.0, 0.0, 0.0};
            if (canOrder) {
                const double row[3] = {iop[0], iop[1], iop[2]};
                const double col[3] = {iop[3], iop[4], iop[5]};
                scanAxis[0] = row[1] * col[2] - row[2] * col[1];
                scanAxis[1] = row[2] * col[0] - row[0] * col[2];
                scanAxis[2] = row[0] * col[1] - row[1] * col[0];
                const double norm = std::sqrt(scanAxis[0] * scanAxis[0] +
                                              scanAxis[1] * scanAxis[1] +
                                              scanAxis[2] * scanAxis[2]);
                if (norm == 0.0) {
                    canOrder = false;
                } else {
                    scanAxis[0] /= norm;
                    scanAxis[1] /= norm;
                    scanAxis[2] /= norm;
                }
            }

            for (size_t i = 0; i < dictArray->size(); ++i) {
                const auto *dict = dictArray->at(i);
                if (!dict) {
                    orientationConsistent = false;
                    canOrder = false;
                    break;
                }
                if (hasIOP) {
                    std::vector<double> currentIOP;
                    if (!extractDicomVector(*dict, "0020|0037", 6, currentIOP)) {
                        orientationConsistent = false;
                    } else {
                        for (size_t j = 0; j < currentIOP.size(); ++j) {
                            if (std::abs(currentIOP[j] - iop[j]) > orientationEpsilon) {
                                orientationConsistent = false;
                                break;
                            }
                        }
                    }
                } else {
                    orientationConsistent = false;
                }

                if (canOrder) {
                    std::vector<double> currentIPP;
                    if (!extractDicomVector(*dict, "0020|0032", 3, currentIPP)) {
                        canOrder = false;
                    } else {
                        const double dx = currentIPP[0] - ipp[0];
                        const double dy = currentIPP[1] - ipp[1];
                        const double dz = currentIPP[2] - ipp[2];
                        const double dist = dx * scanAxis[0] + dy * scanAxis[1] + dz * scanAxis[2];
                        distances.push_back(dist);
                    }
                }

                if (hasRows) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0010", current) || std::abs(current - firstRows) > spacingEpsilon) {
                        pixelDataConsistent = false;
                    }
                }
                if (hasColumns) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0011", current) || std::abs(current - firstColumns) > spacingEpsilon) {
                        pixelDataConsistent = false;
                    }
                }
                if (hasBitsAllocated) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0100", current) || std::abs(current - firstBitsAllocated) > spacingEpsilon) {
                        pixelDataConsistent = false;
                    }
                }
                if (hasBitsStored) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0101", current) || std::abs(current - firstBitsStored) > spacingEpsilon) {
                        pixelDataConsistent = false;
                    }
                }
                if (hasPixelRep) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0103", current) || std::abs(current - firstPixelRep) > spacingEpsilon) {
                        pixelDataConsistent = false;
                    }
                }

                if (hasPixelSpacing) {
                    std::vector<double> currentSpacing;
                    if (!extractDicomVector(*dict, "0028|0030", 2, currentSpacing)) {
                        geometryConsistent = false;
                    } else {
                        for (size_t j = 0; j < currentSpacing.size(); ++j) {
                            if (std::abs(currentSpacing[j] - firstPixelSpacing[j]) > spacingEpsilon) {
                                geometryConsistent = false;
                                break;
                            }
                        }
                    }
                }
                if (hasSliceThickness) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0018|0050", current) || std::abs(current - firstSliceThickness) > spacingEpsilon) {
                        geometryConsistent = false;
                    }
                }
                if (hasSpacingBetween) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0018|0088", current) || std::abs(current - firstSpacingBetween) > spacingEpsilon) {
                        geometryConsistent = false;
                    }
                }
            }

            if (canOrder && distances.size() == dictArray->size()) {
                std::vector<size_t> spacingOrder;
                if (inputReordered && preOrder.order.size() == distances.size()) {
                    std::vector<double> orderAsDouble;
                    orderAsDouble.reserve(preOrder.order.size());
                    for (size_t idx : preOrder.order) {
                        orderAsDouble.push_back(static_cast<double>(idx));
                    }
                    numericOverrides["_sliceOrder"] = orderAsDouble;
                    spacingOrder.resize(distances.size());
                    for (size_t i = 0; i < distances.size(); ++i) {
                        spacingOrder[i] = i;
                    }
                } else {
                    sliceOrder.resize(distances.size());
                    for (size_t i = 0; i < distances.size(); ++i) {
                        sliceOrder[i] = i;
                    }
                    std::sort(sliceOrder.begin(), sliceOrder.end(), [&](size_t a, size_t b) {
                        return distances[a] < distances[b];
                    });

                    std::vector<double> orderAsDouble;
                    orderAsDouble.reserve(sliceOrder.size());
                    for (size_t idx : sliceOrder) {
                        orderAsDouble.push_back(static_cast<double>(idx));
                    }
                    numericOverrides["_sliceOrder"] = orderAsDouble;
                    spacingOrder = sliceOrder;
                }

                if (spacingOrder.size() > 1) {
                    spacingReference = distances[spacingOrder[1]] - distances[spacingOrder[0]];
                    spacingReferenceSet = true;
                    for (size_t i = 1; i < spacingOrder.size(); ++i) {
                        const double delta = distances[spacingOrder[i]] - distances[spacingOrder[i - 1]];
                        const double error = std::abs(delta - spacingReference);
                        maxSpacingError = std::max(maxSpacingError, error);
                        if (error > spacingEpsilon) {
                            spacingUniform = false;
                        }
                    }
                }
            }

            if (spacingReferenceSet) {
                scalarOverrides["_spacingReference"] = spacingReference;
                scalarOverrides["_spacingMaxError"] = maxSpacingError;
                boolOverrides["_spacingUniform"] = spacingUniform;
            }

            boolOverrides["_orientationConsistent"] = orientationConsistent;
            boolOverrides["_pixelDataConsistent"] = pixelDataConsistent;
            boolOverrides["_geometryConsistent"] = geometryConsistent;
        }
    }

    const auto &dir = reader->GetOutput()->GetDirection();
    double det = dir(0, 0) * (dir(1, 1) * dir(2, 2) - dir(1, 2) * dir(2, 1)) -
        dir(0, 1) * (dir(1, 0) * dir(2, 2) - dir(1, 2) * dir(2, 0)) +
        dir(0, 2) * (dir(1, 0) * dir(2, 1) - dir(1, 1) * dir(2, 0));
    boolOverrides["_leftHanded"] = (det < 0.0);

    GeometryValidationResult geometryValidation = validateGeometryFromDictionaries(
        fileNames,
        dictionaries,
        reader->GetOutput(),
        orientationEpsilon,
        spacingEpsilon,
        missingGeometryTags
    );

    if (!missingGeometryTags.empty()) {
        geometryReliability = "incomplete";
    }

    if (orderingMethod != "ipp_iop") {
        geometryReliability = (geometryReliability == "incomplete") ? "incomplete" : "fallback";
    }

    if (orderingMethod == "slice_location") {
        orderingAssumptions.push_back("slice_order_from_slice_location");
    } else if (orderingMethod == "file_index") {
        orderingAssumptions.push_back("slice_order_from_file_index");
    } else if (orderingMethod == "multiframe_native") {
        orderingAssumptions.push_back("slice_order_multiframe_native");
    }

    metadata.hasDicomMetadata = true;
    metadata.dicomMetadata.orderingMethod = orderingMethod;
    metadata.dicomMetadata.grouping = grouping;
    metadata.dicomMetadata.groupingRejectedCount = groupingRejectedCount;
    metadata.dicomMetadata.selectedCandidate = selectedCandidate;
    metadata.dicomMetadata.selectedCandidateId = selectedCandidateId;
    metadata.dicomMetadata.hasSelectedCandidate = hasSelectedCandidate;
    metadata.dicomMetadata.diagnostics = diagnostics;
    metadata.dicomMetadata.hasSeriesDiagnostics = true;
    metadata.dicomMetadata.geometryValidation = geometryValidation;
    metadata.dicomMetadata.hasGeometryValidation = true;
    metadata.dicomMetadata.missingGeometryTags = missingGeometryTags;
    metadata.dicomMetadata.orderingAssumptions = orderingAssumptions;
    metadata.dicomMetadata.geometryReliability = geometryReliability;

    if (boolOverrides.find("_multiFrame") != boolOverrides.end()) {
        metadata.dicomMetadata.isMultiFrame = true;
        metadata.dicomMetadata.multiFrameWarning =
            "Multi-frame image detected. If slice orientation or spacing is non-uniform then the image may be displayed incorrectly. Use with caution.";
    }

    VolumeLoadResult result;
    result.image = reader->GetOutput();
    result.metadata = metadata;
    return result;
}
