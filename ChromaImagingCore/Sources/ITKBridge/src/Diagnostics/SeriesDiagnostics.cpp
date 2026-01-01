#include "SeriesDiagnostics.h"

#include <map>
#include <cmath>

#include "../DICOM/DicomTagExtractors.h"
#include "../Core/ITKBridgeInternal.h"

SeriesDiagnosticsResult buildSeriesDiagnostics(
    const itk::GDCMSeriesFileNames::Pointer &nameGen,
    const std::vector<std::string> &seriesUIDs,
    ITKDicomBackendC backend
) {
    SeriesDiagnosticsResult result;
    std::vector<SubseriesCandidate> candidates;

    std::string seriesDiagnostics = "[";
    std::string subseriesDiagnostics = "[";
    bool firstSeries = true;
    bool firstSubseries = true;

    for (const auto &seriesUID : seriesUIDs) {
        std::vector<std::string> fileNames = nameGen->GetFileNames(seriesUID);
        if (!firstSeries) { seriesDiagnostics += ","; }
        firstSeries = false;
        seriesDiagnostics += "{";
        bool firstField = true;
        seriesDiagnostics += jsonStringField("seriesInstanceUID", seriesUID, firstField);
        seriesDiagnostics += jsonObjectField("fileCount", jsonNumber(static_cast<double>(fileNames.size())), firstField);
        seriesDiagnostics += "}";

        std::map<std::string, std::vector<size_t>> subseriesIndices;
        std::vector<std::vector<double>> iopValues(fileNames.size());
        std::vector<std::vector<double>> ippValues(fileNames.size());
        std::vector<bool> pixelDataPresent(fileNames.size(), false);

        for (size_t i = 0; i < fileNames.size(); ++i) {
            const std::string &file = fileNames[i];
            itk::ImageIOBase::Pointer dicomIO = makeDicomIO(backend);
            dicomIO->SetFileName(file);
            dicomIO->ReadImageInformation();
            const auto &dict = dicomIO->GetMetaDataDictionary();

            std::vector<double> iop;
            std::vector<double> ipp;
            extractDicomVectorOptional(dict, "0020|0037", 6, iop);
            extractDicomVectorOptional(dict, "0020|0032", 3, ipp);
            iopValues[i] = iop;
            ippValues[i] = ipp;

            std::string acquisitionNumber;
            extractDicomString(dict, "0020|0012", acquisitionNumber);
            std::string imageType;
            extractDicomString(dict, "0008|0008", imageType);
            std::vector<double> diffusion;
            extractDicomVectorOptional(dict, "0018|9089", 3, diffusion);
            std::string contentTime;
            extractDicomString(dict, "0008|0033", contentTime);
            std::string triggerTime;
            extractDicomString(dict, "0018|1060", triggerTime);

            std::string pixelData;
            pixelDataPresent[i] = extractDicomString(dict, "7fe0|0010", pixelData);

            std::string key = "iop=" + (iop.empty() ? "nil" : vectorKey(iop))
                + "|acq=" + (acquisitionNumber.empty() ? "nil" : acquisitionNumber)
                + "|type=" + (imageType.empty() ? "nil" : imageType)
                + "|dgo=" + (diffusion.empty() ? "nil" : vectorKey(diffusion))
                + "|ct=" + (contentTime.empty() ? "nil" : contentTime)
                + "|tt=" + (triggerTime.empty() ? "nil" : triggerTime);

            subseriesIndices[key].push_back(i);
        }

        for (const auto &entry : subseriesIndices) {
            const std::string &key = entry.first;
            const std::vector<size_t> &indices = entry.second;
            const size_t sliceCount = indices.size();

            bool orientationConsistent = true;
            bool spacingUniform = true;
            bool spacingReferenceSet = false;
            double spacingReference = 0.0;
            double maxSpacingError = 0.0;
            bool hasPixelData = false;

            std::vector<double> refIOP;
            std::vector<double> refIPP;
            if (!indices.empty()) {
                refIOP = iopValues[indices.front()];
                refIPP = ippValues[indices.front()];
            }

            for (size_t idx : indices) {
                if (pixelDataPresent[idx]) {
                    hasPixelData = true;
                }
                const std::vector<double> &currentIOP = iopValues[idx];
                if (refIOP.size() != 6 || currentIOP.size() != 6) {
                    orientationConsistent = false;
                } else {
                    for (size_t j = 0; j < 6; ++j) {
                        if (std::abs(currentIOP[j] - refIOP[j]) > 1e-6) {
                            orientationConsistent = false;
                            break;
                        }
                    }
                }
            }

            std::vector<double> distances;
            if (orientationConsistent && refIOP.size() == 6 && refIPP.size() == 3) {
                const double row[3] = {refIOP[0], refIOP[1], refIOP[2]};
                const double col[3] = {refIOP[3], refIOP[4], refIOP[5]};
                double scanAxis[3] = {
                    row[1] * col[2] - row[2] * col[1],
                    row[2] * col[0] - row[0] * col[2],
                    row[0] * col[1] - row[1] * col[0]
                };
                const double norm = std::sqrt(scanAxis[0] * scanAxis[0] +
                                              scanAxis[1] * scanAxis[1] +
                                              scanAxis[2] * scanAxis[2]);
                if (norm > 0.0) {
                    scanAxis[0] /= norm;
                    scanAxis[1] /= norm;
                    scanAxis[2] /= norm;
                    for (size_t idx : indices) {
                        const std::vector<double> &ipp = ippValues[idx];
                        if (ipp.size() != 3) {
                            spacingUniform = false;
                            distances.clear();
                            break;
                        }
                        const double dx = ipp[0] - refIPP[0];
                        const double dy = ipp[1] - refIPP[1];
                        const double dz = ipp[2] - refIPP[2];
                        const double dist = dx * scanAxis[0] + dy * scanAxis[1] + dz * scanAxis[2];
                        distances.push_back(dist);
                    }
                } else {
                    spacingUniform = false;
                }
            } else {
                spacingUniform = false;
            }

            if (distances.size() == indices.size() && distances.size() > 1) {
                std::vector<size_t> order(distances.size());
                for (size_t i = 0; i < order.size(); ++i) { order[i] = i; }
                std::sort(order.begin(), order.end(), [&](size_t a, size_t b) {
                    return distances[a] < distances[b];
                });
                spacingReference = distances[order[1]] - distances[order[0]];
                spacingReferenceSet = true;
                for (size_t i = 1; i < order.size(); ++i) {
                    const double delta = distances[order[i]] - distances[order[i - 1]];
                    const double error = std::abs(delta - spacingReference);
                    maxSpacingError = std::max(maxSpacingError, error);
                    if (error > 1e-2) {
                        spacingUniform = false;
                    }
                }
            }

            bool localizerLike = sliceCount <= 2;
            if (spacingReferenceSet && maxSpacingError > spacingReference * 2.0) {
                localizerLike = true;
            }

            SubseriesCandidate candidate;
            candidate.seriesUID = seriesUID;
            candidate.key = key;
            candidate.fileCount = sliceCount;
            candidate.orientationConsistent = orientationConsistent;
            candidate.spacingUniform = spacingUniform;
            candidate.spacingReference = spacingReferenceSet ? spacingReference : 0.0;
            candidate.maxSpacingError = spacingReferenceSet ? maxSpacingError : 0.0;

            if (hasPixelData) {
                candidate.confidence += 1;
            } else {
                candidate.reasons.push_back("missingPixelData");
            }
            if (sliceCount > 1) {
                candidate.confidence += 1;
            } else {
                candidate.reasons.push_back("singleSlice");
            }
            if (orientationConsistent) {
                candidate.confidence += 1;
            } else {
                candidate.reasons.push_back("orientationInconsistent");
            }
            if (spacingUniform && spacingReferenceSet) {
                candidate.confidence += 1;
            } else {
                candidate.reasons.push_back("spacingNonUniform");
            }
            if (!localizerLike) {
                candidate.confidence += 1;
            } else {
                candidate.reasons.push_back("localizerLike");
            }

            candidates.push_back(candidate);

            if (!firstSubseries) { subseriesDiagnostics += ","; }
            firstSubseries = false;
            subseriesDiagnostics += "{";
            bool subFirst = true;
            subseriesDiagnostics += jsonStringField("seriesInstanceUID", seriesUID, subFirst);
            subseriesDiagnostics += jsonStringField("subseriesKey", key, subFirst);
            subseriesDiagnostics += jsonObjectField("fileCount", jsonNumber(static_cast<double>(sliceCount)), subFirst);
            subseriesDiagnostics += jsonObjectField("confidence", jsonNumber(static_cast<double>(candidate.confidence)), subFirst);
            subseriesDiagnostics += jsonObjectField("orientationConsistent", candidate.orientationConsistent ? "true" : "false", subFirst);
            subseriesDiagnostics += jsonObjectField("spacingUniform", candidate.spacingUniform ? "true" : "false", subFirst);
            if (spacingReferenceSet) {
                subseriesDiagnostics += jsonObjectField("spacingReferenceMm", jsonNumber(candidate.spacingReference), subFirst);
                subseriesDiagnostics += jsonObjectField("maxSpacingErrorMm", jsonNumber(candidate.maxSpacingError), subFirst);
            }
            subseriesDiagnostics += jsonObjectField("reasons", jsonArrayFromStrings(candidate.reasons), subFirst);
            subseriesDiagnostics += "}";
        }
    }

    seriesDiagnostics += "]";
    subseriesDiagnostics += "]";

    if (!candidates.empty()) {
        auto best = candidates.front();
        for (const auto &candidate : candidates) {
            if (candidate.confidence > best.confidence) {
                best = candidate;
                continue;
            }
            if (candidate.confidence == best.confidence) {
                if (candidate.fileCount > best.fileCount) {
                    best = candidate;
                    continue;
                }
                if (candidate.fileCount == best.fileCount) {
                    if (candidate.seriesUID < best.seriesUID) {
                        best = candidate;
                        continue;
                    }
                    if (candidate.seriesUID == best.seriesUID && candidate.key < best.key) {
                        best = candidate;
                        continue;
                    }
                }
            }
        }
        result.selectedSeriesUID = best.seriesUID;
        result.selectedSubseriesKey = best.key;
        result.selectedConfidence = best.confidence;
    }

    std::string selectedInfo = "{";
    bool selectedFirst = true;
    if (!result.selectedSeriesUID.empty()) {
        selectedInfo += jsonStringField("seriesInstanceUID", result.selectedSeriesUID, selectedFirst);
    }
    if (!result.selectedSubseriesKey.empty()) {
        selectedInfo += jsonStringField("subseriesKey", result.selectedSubseriesKey, selectedFirst);
    }
    selectedInfo += jsonObjectField("confidence", jsonNumber(static_cast<double>(result.selectedConfidence)), selectedFirst);
    selectedInfo += "}";

    result.seriesDiagnosticsJSON = seriesDiagnostics;
    result.subseriesDiagnosticsJSON = subseriesDiagnostics;
    result.selectedInfoJSON = selectedInfo;
    return result;
}

std::string seriesCandidatesToJSON(const std::vector<SeriesCandidateRecord> &candidates) {
    std::string json = "[";
    for (size_t i = 0; i < candidates.size(); ++i) {
        if (i > 0) { json += ","; }
        bool firstField = true;
        json += "{";
        json += jsonStringField("candidateId", candidates[i].candidateId, firstField);
        json += jsonObjectField("sliceCount", jsonNumber(static_cast<double>(candidates[i].sliceCount)), firstField);
        json += jsonObjectField("groupingKeys", jsonArrayFromStrings(candidates[i].groupingKeys), firstField);
        if (!candidates[i].orderingMethod.empty()) {
            json += jsonStringField("orderingMethod", candidates[i].orderingMethod, firstField);
        }
        if (!candidates[i].rejectionReason.empty()) {
            json += jsonStringField("rejectionReason", candidates[i].rejectionReason, firstField);
        }
        json += "}";
    }
    json += "]";
    return json;
}

std::string seriesSelectionInfoToJSON(const SeriesCandidateRecord &selected,
                                      const std::vector<std::string> &groupingKeysUsed,
                                      const std::string &orderingMethod,
                                      bool fallbackUsed,
                                      const std::string &selectionReason) {
    bool firstField = true;
    std::string json = "{";
    json += jsonStringField("candidateId", selected.candidateId, firstField);
    json += jsonObjectField("sliceCount", jsonNumber(static_cast<double>(selected.sliceCount)), firstField);
    if (!orderingMethod.empty()) {
        json += jsonStringField("orderingMethod", orderingMethod, firstField);
    }
    json += jsonObjectField("groupingKeysUsed", jsonArrayFromStrings(groupingKeysUsed), firstField);
    json += jsonObjectField("fallbackUsed", fallbackUsed ? "true" : "false", firstField);
    json += jsonStringField("selectionReason", selectionReason, firstField);
    json += "}";
    return json;
}

std::string geometryValidationToJSON(const GeometryValidationResult &validation) {
    bool firstField = true;
    std::string json = "{";
    json += jsonStringField("sliceOrder", validation.sliceOrder, firstField);
    json += "\"spacing\":{";
    bool spacingFirst = true;
    json += jsonObjectField("uniform", validation.spacingUniform ? "true" : "false", spacingFirst);
    json += jsonObjectField("min", jsonNumber(validation.spacingMin), spacingFirst);
    json += jsonObjectField("max", jsonNumber(validation.spacingMax), spacingFirst);
    json += "}";
    json += ",\"direction\":{";
    bool directionFirst = true;
    json += jsonObjectField("orthonormal", validation.directionOrthonormal ? "true" : "false", directionFirst);
    json += jsonObjectField("determinant", jsonNumber(validation.directionDeterminant), directionFirst);
    json += jsonObjectField("leftHanded", validation.leftHanded ? "true" : "false", directionFirst);
    json += "}";
    json += jsonObjectField("usedDefaults", validation.usedDefaults ? "true" : "false", firstField);
    json += jsonStringField("validationStatus", validation.validationStatus, firstField);
    json += "}";
    return json;
}

