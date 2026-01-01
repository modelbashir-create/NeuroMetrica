#include "DescriptorBuilder.h"

#include <cstring>
#include <cstdlib>
#include <map>

#include "itkMetaDataObject.h"

#include "../Diagnostics/SliceProvenance.h"
#include "../Diagnostics/SeriesDiagnostics.h"
#include "../Utils/ITKBridgeUtils.h"

namespace {

std::string metadataDictionaryToJSON(
    const itk::MetaDataDictionary &dict,
    const std::map<std::string, std::vector<double>> &numericOverrides,
    const std::map<std::string, double> &scalarOverrides,
    const std::map<std::string, bool> &boolOverrides,
    const std::map<std::string, std::string> &rawJsonOverrides
) {
    std::string json = "{";
    bool first = true;

    for (const auto &entry : rawJsonOverrides) {
        if (!first) { json += ","; }
        first = false;
        json += "\"";
        json += escapeJSON(entry.first);
        json += "\":";
        json += entry.second;
    }

    for (const auto &entry : boolOverrides) {
        if (!first) { json += ","; }
        first = false;
        json += "\"";
        json += escapeJSON(entry.first);
        json += "\":";
        json += entry.second ? "true" : "false";
    }

    for (const auto &entry : numericOverrides) {
        if (!first) { json += ","; }
        first = false;
        json += "\"";
        json += escapeJSON(entry.first);
        json += "\":[";
        for (size_t i = 0; i < entry.second.size(); ++i) {
            if (i > 0) { json += ","; }
            json += jsonNumber(entry.second[i]);
        }
        json += "]";
    }

    for (const auto &entry : scalarOverrides) {
        if (!first) { json += ","; }
        first = false;
        json += "\"";
        json += escapeJSON(entry.first);
        json += "\":";
        json += jsonNumber(entry.second);
    }

    for (auto it = dict.Begin(); it != dict.End(); ++it) {
        const std::string normalizedKey = normalizeTagKey(it->first);
        if (rawJsonOverrides.find(normalizedKey) != rawJsonOverrides.end()) {
            continue;
        }
        if (numericOverrides.find(normalizedKey) != numericOverrides.end()) {
            continue;
        }
        if (scalarOverrides.find(normalizedKey) != scalarOverrides.end()) {
            continue;
        }
        if (boolOverrides.find(normalizedKey) != boolOverrides.end()) {
            continue;
        }
        std::string value;
        if (!itk::ExposeMetaData<std::string>(dict, it->first, value)) {
            continue;
        }

        if (!first) {
            json += ",";
        }
        first = false;
        json += "\"";
        json += escapeJSON(normalizedKey);
        json += "\":\"";
        json += escapeJSON(value);
        json += "\"";
    }

    json += "}";
    return json;
}

// ---- Descriptor metadata allocation ----

void attachMetadataJSON(ITKImageDescriptorC *outDescriptor,
                        const std::string &metadataJSON) {
    if (!outDescriptor) { return; }
    if (metadataJSON.empty()) {
        outDescriptor->metadataJSON = nullptr;
        outDescriptor->metadataJSONLength = 0;
        return;
    }

    const size_t length = metadataJSON.size();
    char *buffer = static_cast<char *>(std::malloc(length + 1));
    if (!buffer) {
        outDescriptor->metadataJSON = nullptr;
        outDescriptor->metadataJSONLength = 0;
        return;
    }

    std::memcpy(buffer, metadataJSON.c_str(), length);
    buffer[length] = '\0';
    outDescriptor->metadataJSON = buffer;
    outDescriptor->metadataJSONLength = static_cast<int32_t>(length);
}

void attachSliceProvenanceJSON(ITKImageDescriptorC *outDescriptor,
                               const std::string &provenanceJSON) {
    if (!outDescriptor) { return; }
    if (provenanceJSON.empty()) {
        outDescriptor->sliceProvenanceJSON = nullptr;
        outDescriptor->sliceProvenanceJSONLength = 0;
        return;
    }

    const size_t length = provenanceJSON.size();
    char *buffer = static_cast<char *>(std::malloc(length + 1));
    if (!buffer) {
        outDescriptor->sliceProvenanceJSON = nullptr;
        outDescriptor->sliceProvenanceJSONLength = 0;
        return;
    }

    std::memcpy(buffer, provenanceJSON.c_str(), length);
    buffer[length] = '\0';
    outDescriptor->sliceProvenanceJSON = buffer;
    outDescriptor->sliceProvenanceJSONLength = static_cast<int32_t>(length);
}

// ---- Descriptor struct population (no ownership changes) ----

void fillDescriptorFromImage(const Float3DImage::Pointer &image,
                             void *buffer,
                             uint64_t valueCount,
                             ITKImageDescriptorC *outDescriptor) {
    if (!image || !outDescriptor) {
        return;
    }

    using SizeType      = Float3DImage::SizeType;
    using SpacingType   = Float3DImage::SpacingType;
    using PointType     = Float3DImage::PointType;
    using DirectionType = Float3DImage::DirectionType;

    const SizeType      &size    = image->GetLargestPossibleRegion().GetSize();
    const SpacingType   &spacing = image->GetSpacing();
    const PointType     &origin  = image->GetOrigin();
    const DirectionType &dir     = image->GetDirection();

    outDescriptor->dimension = 3;

    outDescriptor->size[0] = static_cast<uint64_t>(size[0]);
    outDescriptor->size[1] = static_cast<uint64_t>(size[1]);
    outDescriptor->size[2] = static_cast<uint64_t>(size[2]);
    outDescriptor->size[3] = 1;

    outDescriptor->spacing[0] = spacing[0];
    outDescriptor->spacing[1] = spacing[1];
    outDescriptor->spacing[2] = spacing[2];
    outDescriptor->spacing[3] = 1.0;

    outDescriptor->origin[0] = origin[0];
    outDescriptor->origin[1] = origin[1];
    outDescriptor->origin[2] = origin[2];
    outDescriptor->origin[3] = 0.0;

    std::memset(outDescriptor->direction, 0, sizeof(outDescriptor->direction));
    for (unsigned int r = 0; r < 3; ++r) {
        for (unsigned int c = 0; c < 3; ++c) {
            outDescriptor->direction[r * 3 + c] = dir(r, c);
        }
    }

    outDescriptor->pixelType          = ITKPixelType_Scalar;
    outDescriptor->componentsPerPixel = 1;

    outDescriptor->valueCount   = valueCount;
    outDescriptor->bufferHandle = buffer;

    outDescriptor->componentBytes = 4;
    outDescriptor->isSigned       = 1;
}

std::string buildMetadataJSON(const MetadataContext &metadata) {
    std::map<std::string, std::string> rawJsonOverrides;

    if (metadata.hasDicomMetadata) {
        const auto &dicomMeta = metadata.dicomMetadata;
        if (!dicomMeta.orderingMethod.empty()) {
            rawJsonOverrides["orderingMethod"] = jsonStringValue(dicomMeta.orderingMethod);
        }
        if (!dicomMeta.grouping.candidates.empty()) {
            rawJsonOverrides["_seriesCandidates"] = seriesCandidatesToJSON(dicomMeta.grouping.candidates);
        }
        if (!dicomMeta.selectedCandidateId.empty()) {
            rawJsonOverrides["_selectedSeriesCandidateId"] = jsonStringValue(dicomMeta.selectedCandidateId);
        }
        if (!dicomMeta.grouping.selectionReason.empty()) {
            rawJsonOverrides["_seriesSelectionReason"] = jsonStringValue(dicomMeta.grouping.selectionReason);
        }
        if (dicomMeta.hasSelectedCandidate) {
            const bool fallbackUsed = (dicomMeta.orderingMethod != "ipp_iop");
            rawJsonOverrides["_selectedSeriesCandidateInfo"] = seriesSelectionInfoToJSON(
                dicomMeta.selectedCandidate,
                dicomMeta.grouping.keysUsed,
                dicomMeta.orderingMethod,
                fallbackUsed,
                dicomMeta.grouping.selectionReason
            );
        }
        if (!dicomMeta.grouping.keysUsed.empty()) {
            rawJsonOverrides["groupingKeysUsed"] = jsonArrayFromStrings(dicomMeta.grouping.keysUsed);
        }
        if (dicomMeta.hasSeriesDiagnostics) {
            rawJsonOverrides["_seriesDiagnostics"] = dicomMeta.diagnostics.seriesDiagnosticsJSON;
            rawJsonOverrides["_subseriesDiagnostics"] = dicomMeta.diagnostics.subseriesDiagnosticsJSON;
            rawJsonOverrides["_selectedSeriesInfo"] = dicomMeta.diagnostics.selectedInfoJSON;
        }
        if (dicomMeta.hasGeometryValidation) {
            rawJsonOverrides["_geometryValidation"] = geometryValidationToJSON(dicomMeta.geometryValidation);
        }
        if (!dicomMeta.missingGeometryTags.empty()) {
            rawJsonOverrides["missingGeometryTags"] = jsonArrayFromStrings(dicomMeta.missingGeometryTags);
        }
        if (!dicomMeta.geometryReliability.empty()) {
            rawJsonOverrides["geometryReliability"] = jsonStringValue(dicomMeta.geometryReliability);
        }
        if (!dicomMeta.orderingAssumptions.empty()) {
            rawJsonOverrides["orderingAssumptions"] = jsonArrayFromStrings(dicomMeta.orderingAssumptions);
        }
        if (!dicomMeta.multiFrameWarning.empty()) {
            rawJsonOverrides["_multiFrameWarning"] = jsonStringValue(dicomMeta.multiFrameWarning);
        }
    }

    return metadataDictionaryToJSON(
        metadata.baseDictionary,
        metadata.overrides.numericOverrides,
        metadata.overrides.scalarOverrides,
        metadata.overrides.boolOverrides,
        rawJsonOverrides
    );
}

} // namespace

// ---- Descriptor memory helpers (ownership/free) ----

void zeroDescriptor(ITKImageDescriptorC *desc) {
    if (!desc) { return; }
    std::memset(desc, 0, sizeof(*desc));
}

void freeDescriptor(ITKImageDescriptorC *descriptor) {
    if (!descriptor) { return; }

    if (descriptor->bufferHandle != nullptr) {
        void *ptr = const_cast<void *>(descriptor->bufferHandle);
        std::free(ptr);
    }
    if (descriptor->metadataJSON != nullptr) {
        void *ptr = const_cast<char *>(descriptor->metadataJSON);
        std::free(ptr);
    }
    if (descriptor->sliceProvenanceJSON != nullptr) {
        void *ptr = const_cast<char *>(descriptor->sliceProvenanceJSON);
        std::free(ptr);
    }
    zeroDescriptor(descriptor);
}

bool buildDescriptorFromResult(const VolumeLoadResult &result,
                               ITKImageDescriptorC *outDescriptor,
                               const char *context,
                               std::string *errorMessage) {
    const char *prefix = context ? context : "ITKLoad";
    if (!outDescriptor) {
        if (errorMessage) {
            *errorMessage = std::string(prefix) + ": null output descriptor";
        }
        return false;
    }

    if (!result.image) {
        if (errorMessage) {
            *errorMessage = std::string(prefix) + ": reader returned null image";
        }
        return false;
    }

    const auto &size = result.image->GetLargestPossibleRegion().GetSize();
    const uint64_t voxelCount =
        static_cast<uint64_t>(size[0]) *
        static_cast<uint64_t>(size[1]) *
        static_cast<uint64_t>(size[2]);
    const uint64_t componentsPerPixel = 1;
    const uint64_t valueCount = voxelCount * componentsPerPixel;
    const uint64_t byteCount = valueCount * 4;

    // ---- Descriptor buffer allocation ----
    void *buffer = std::malloc(static_cast<size_t>(byteCount));
    if (!buffer) {
        if (errorMessage) {
            *errorMessage = std::string(prefix) + ": failed to allocate voxel buffer";
        }
        return false;
    }

    const float *src = result.image->GetBufferPointer();
    std::memcpy(buffer, src, static_cast<size_t>(byteCount));

    fillDescriptorFromImage(result.image, buffer, valueCount, outDescriptor);
    const std::string metadataJSON = buildMetadataJSON(result.metadata);
    const std::string sliceProvenanceJSON = buildSliceProvenanceJSON(result.metadata.sliceDictionaries);
    attachMetadataJSON(outDescriptor, metadataJSON);
    attachSliceProvenanceJSON(outDescriptor, sliceProvenanceJSON);
    return true;
}
