//
//  DicomBridge.mm
//  DCMTKLoader
//
//  ObjC++ bridge that uses DCMTK to load DICOM series into a simple C struct.
//

#include "DicomBridge.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include <dcmtk/dcmdata/dctk.h>
#include <dcmtk/dcmdata/dcdeftag.h>
#include <dcmtk/dcmdata/dcuid.h>
#include <dcmtk/dcmtk/ofstd/ofstring.h>
#include <dcmtk/dcmimage/diregist.h>
#include <dcmtk/dcmimgle/dcmimage.h>

namespace {
struct SliceData {
    int instanceNumber{0};
    double normalDistance{0.0};
    double spacingX{1.0};
    double spacingY{1.0};
    double spacingBetweenSlices{0.0};
    double sliceThickness{0.0};
    std::vector<double> orientation; // 6 values
    std::vector<double> position;    // 3 values
    std::vector<float> pixels;
    DcmDataset *dataset{nullptr};
    std::unique_ptr<DcmFileFormat> file;
};

struct OwnedTagEntry {
    std::string key;
    NM_DicomTagValueType type{NM_DicomTagValueTypeString};
    std::string stringValue;
    long long intValue{0};
    double doubleValue{0.0};
    std::vector<uint8_t> dataValue;
};

char *copyCString(const std::string &value) {
    if (value.empty()) {
        return nullptr;
    }
    char *result = static_cast<char *>(std::malloc(value.size() + 1));
    if (result) {
        std::copy(value.begin(), value.end(), result);
        result[value.size()] = '\0';
    }
    return result;
}

double *copyDoubleArray(const std::vector<double> &values) {
    if (values.empty()) {
        return nullptr;
    }
    double *result = static_cast<double *>(std::malloc(sizeof(double) * values.size()));
    if (!result) {
        return nullptr;
    }
    std::copy(values.begin(), values.end(), result);
    return result;
}

void freeTagEntries(NM_DicomTagEntry *entries, int count) {
    if (!entries) {
        return;
    }
    for (int i = 0; i < count; ++i) {
        NM_DicomTagEntry &entry = entries[i];
        if (entry.tagKey) {
            std::free(entry.tagKey);
            entry.tagKey = nullptr;
        }
        if (entry.stringValue) {
            std::free(entry.stringValue);
            entry.stringValue = nullptr;
        }
        if (entry.dataValue) {
            std::free(entry.dataValue);
            entry.dataValue = nullptr;
            entry.dataLength = 0;
        }
    }
    std::free(entries);
}

std::string tagKeyString(const DcmTagKey &key) {
    char buffer[16];
    std::snprintf(buffer, sizeof(buffer), "%04X,%04X", key.getGroup(), key.getElement());
    return std::string(buffer);
}

void appendStringTag(std::vector<OwnedTagEntry> &entries, const DcmTagKey &key, const OFString &value) {
    OwnedTagEntry entry;
    entry.key = tagKeyString(key);
    entry.type = NM_DicomTagValueTypeString;
    entry.stringValue = value.c_str();
    entries.push_back(std::move(entry));
}

void appendDoubleTag(std::vector<OwnedTagEntry> &entries, const DcmTagKey &key, double value) {
    OwnedTagEntry entry;
    entry.key = tagKeyString(key);
    entry.type = NM_DicomTagValueTypeDouble;
    entry.doubleValue = value;
    entries.push_back(std::move(entry));
}

void appendIntTag(std::vector<OwnedTagEntry> &entries, const DcmTagKey &key, long long value) {
    OwnedTagEntry entry;
    entry.key = tagKeyString(key);
    entry.type = NM_DicomTagValueTypeInt;
    entry.intValue = value;
    entries.push_back(std::move(entry));
}

bool shouldSkipTag(const DcmTagKey &key) {
    return key == DCM_PixelData || key == DCM_IconImageSequence;
}

void collectTagEntries(DcmDataset *dataset, std::vector<OwnedTagEntry> &entries) {
    if (!dataset) {
        return;
    }

    std::set<std::string> seenKeys;
    DcmStack stack;
    while (dataset->nextObject(stack, OFTrue).good()) {
        DcmObject *object = stack.top();
        if (!object || !object->isLeaf()) {
            continue;
        }
        DcmElement *element = dynamic_cast<DcmElement *>(object);
        if (!element) {
            continue;
        }
        DcmTagKey key = element->getTag().getXTag();
        if (shouldSkipTag(key)) {
            continue;
        }

        std::string keyString = tagKeyString(key);
        if (seenKeys.find(keyString) != seenKeys.end()) {
            continue;
        }
        seenKeys.insert(keyString);

        const DcmEVR vr = element->getVR().getEVR();
        const unsigned long vm = element->getVM();

        if (vr == EVR_OB || vr == EVR_OW || vr == EVR_UN || vr == EVR_OF || vr == EVR_OL || vr == EVR_OD) {
            Uint8 *data = nullptr;
            const Uint32 length = element->getLength();
            if (length > 0 && length <= 4096 && element->getUint8Array(data).good() && data) {
                OwnedTagEntry entry;
                entry.key = keyString;
                entry.type = NM_DicomTagValueTypeData;
                entry.dataValue.assign(data, data + length);
                entries.push_back(std::move(entry));
            }
            continue;
        }

        if (vm == 1) {
            Sint32 sintValue = 0;
            if (element->getSint32(sintValue).good()) {
                appendIntTag(entries, key, static_cast<long long>(sintValue));
                continue;
            }

            Uint32 uintValue = 0;
            if (element->getUint32(uintValue).good()) {
                appendIntTag(entries, key, static_cast<long long>(uintValue));
                continue;
            }

            Double64 doubleValue = 0.0;
            if (element->getFloat64(doubleValue).good()) {
                appendDoubleTag(entries, key, static_cast<double>(doubleValue));
                continue;
            }
        }

        OFString strValue;
        if (element->getOFStringArray(strValue).good()) {
            appendStringTag(entries, key, strValue);
        }
    }
}

bool loadSlice(const std::string &filePath, SliceData &outSlice, unsigned long &outWidth, unsigned long &outHeight) {
    auto file = std::make_unique<DcmFileFormat>();
    OFCondition status = file->loadFile(filePath.c_str());
    if (!status.good()) {
        return false;
    }

    DcmDataset *dataset = file->getDataset();
    outSlice.dataset = dataset;
    outSlice.file = std::move(file);

    // Extract instance number
    Sint32 instanceNumber = 0;
    if (dataset->findAndGetSint32(DCM_InstanceNumber, instanceNumber).good()) {
        outSlice.instanceNumber = static_cast<int>(instanceNumber);
    }

    // Extract image position
    OFVector<Double64> imagePosition;
    if (dataset->findAndGetFloat64Array(DCM_ImagePositionPatient, imagePosition).good() && imagePosition.size() >= 3) {
        outSlice.position.assign(imagePosition.begin(), imagePosition.begin() + 3);
    }

    // Extract image orientation
    OFVector<Double64> imageOrientation;
    if (dataset->findAndGetFloat64Array(DCM_ImageOrientationPatient, imageOrientation).good() && imageOrientation.size() >= 6) {
        outSlice.orientation.assign(imageOrientation.begin(), imageOrientation.begin() + 6);
    }

    // Pixel spacing (row, column)
    OFVector<Double64> pixelSpacing;
    if (dataset->findAndGetFloat64Array(DCM_PixelSpacing, pixelSpacing).good() && pixelSpacing.size() >= 2) {
        outSlice.spacingY = pixelSpacing[0];
        outSlice.spacingX = pixelSpacing[1];
    }

    Double64 spacingBetweenSlices = 0.0;
    if (dataset->findAndGetFloat64(DCM_SpacingBetweenSlices, spacingBetweenSlices).good()) {
        outSlice.spacingBetweenSlices = spacingBetweenSlices;
    }

    Double64 sliceThickness = 0.0;
    if (dataset->findAndGetFloat64(DCM_SliceThickness, sliceThickness).good()) {
        outSlice.sliceThickness = sliceThickness;
    }

    // Use DicomImage to access pixel data
    DicomImage image(dataset, dataset->getOriginalXfer());
    if (image.getStatus() != EIS_Normal) {
        return false;
    }

    outWidth = image.getWidth();
    outHeight = image.getHeight();
    if (outWidth == 0 || outHeight == 0) {
        return false;
    }

    const unsigned long pixelCount = outWidth * outHeight;
    const int bitsPerSample = image.getDepth();
    const int requestedBits = bitsPerSample <= 16 ? 16 : bitsPerSample;
    const void *rawData = image.getOutputData(requestedBits);
    if (!rawData) {
        return false;
    }

    const Uint16 *pixelData = reinterpret_cast<const Uint16 *>(rawData);

    // Rescale to float using slope/intercept if present
    double slope = 1.0;
    double intercept = 0.0;
    dataset->findAndGetFloat64(DCM_RescaleSlope, slope);
    dataset->findAndGetFloat64(DCM_RescaleIntercept, intercept);

    outSlice.pixels.resize(pixelCount);
    for (unsigned long i = 0; i < pixelCount; ++i) {
        outSlice.pixels[i] = static_cast<float>(pixelData[i] * slope + intercept);
    }

    // Pre-compute normal distance for sorting if orientation and position are available
    if (outSlice.orientation.size() == 6 && outSlice.position.size() == 3) {
        const double nx = outSlice.orientation[1] * outSlice.orientation[5] - outSlice.orientation[2] * outSlice.orientation[4];
        const double ny = outSlice.orientation[2] * outSlice.orientation[3] - outSlice.orientation[0] * outSlice.orientation[5];
        const double nz = outSlice.orientation[0] * outSlice.orientation[4] - outSlice.orientation[1] * outSlice.orientation[3];
        outSlice.normalDistance = nx * outSlice.position[0] + ny * outSlice.position[1] + nz * outSlice.position[2];
    }

    return true;
}

std::vector<double> extractWindowValues(DcmDataset *dataset, const DcmTagKey &key) {
    std::vector<double> result;
    OFVector<Double64> values;
    if (dataset->findAndGetFloat64Array(key, values).good()) {
        result.assign(values.begin(), values.end());
    }
    return result;
}

void populateMetadataFromDataset(const DcmDataset *dataset, NM_DicomVolume *volume) {
    if (!dataset || !volume) {
        return;
    }

    OFString str;
    if (dataset->findAndGetOFString(DCM_FrameOfReferenceUID, str).good()) {
        volume->frameOfReferenceUID = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_PatientName, str).good()) {
        volume->patientName = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_PatientID, str).good()) {
        volume->patientID = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_PatientSex, str).good()) {
        volume->patientSex = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_PatientBirthDate, str).good()) {
        volume->patientBirthDate = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_StudyInstanceUID, str).good()) {
        volume->studyInstanceUID = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_SeriesInstanceUID, str).good()) {
        volume->seriesInstanceUID = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_StudyDescription, str).good()) {
        volume->studyDescription = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_SeriesDescription, str).good()) {
        volume->seriesDescription = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_Modality, str).good()) {
        volume->modality = copyCString(str.c_str());
    }
    if (dataset->findAndGetOFString(DCM_PhotometricInterpretation, str).good()) {
        volume->photometricInterpretation = copyCString(str.c_str());
    }

    Sint32 bitsAllocated = 0;
    if (dataset->findAndGetSint32(DCM_BitsAllocated, bitsAllocated).good()) {
        volume->bitsAllocated = static_cast<int>(bitsAllocated);
    }
    Sint32 bitsStored = 0;
    if (dataset->findAndGetSint32(DCM_BitsStored, bitsStored).good()) {
        volume->bitsStored = static_cast<int>(bitsStored);
    }
    Sint32 highBit = 0;
    if (dataset->findAndGetSint32(DCM_HighBit, highBit).good()) {
        volume->highBit = static_cast<int>(highBit);
    }
    Sint32 pixelRepresentation = 0;
    if (dataset->findAndGetSint32(DCM_PixelRepresentation, pixelRepresentation).good()) {
        volume->pixelRepresentation = static_cast<int>(pixelRepresentation);
    }

    Double64 slope = 1.0;
    Double64 intercept = 0.0;
    dataset->findAndGetFloat64(DCM_RescaleSlope, slope);
    dataset->findAndGetFloat64(DCM_RescaleIntercept, intercept);
    volume->rescaleSlope = static_cast<float>(slope);
    volume->rescaleIntercept = static_cast<float>(intercept);

    std::vector<double> centers = extractWindowValues(const_cast<DcmDataset *>(dataset), DCM_WindowCenter);
    std::vector<double> widths = extractWindowValues(const_cast<DcmDataset *>(dataset), DCM_WindowWidth);
    volume->windowCount = static_cast<int>(std::min(centers.size(), widths.size()));
    if (volume->windowCount > 0) {
        centers.resize(static_cast<size_t>(volume->windowCount));
        widths.resize(static_cast<size_t>(volume->windowCount));
        volume->windowCenters = copyDoubleArray(centers);
        volume->windowWidths = copyDoubleArray(widths);
    }
}

void freeVolumeMetadata(NM_DicomVolume *volume) {
    if (!volume) {
        return;
    }
    auto freeString = [](char *&value) {
        if (value) {
            std::free(value);
            value = nullptr;
        }
    };

    freeString(volume->frameOfReferenceUID);
    freeString(volume->patientName);
    freeString(volume->patientID);
    freeString(volume->patientSex);
    freeString(volume->patientBirthDate);
    freeString(volume->studyInstanceUID);
    freeString(volume->seriesInstanceUID);
    freeString(volume->studyDescription);
    freeString(volume->seriesDescription);
    freeString(volume->modality);
    freeString(volume->photometricInterpretation);

    if (volume->windowCenters) {
        std::free(volume->windowCenters);
        volume->windowCenters = nullptr;
    }
    if (volume->windowWidths) {
        std::free(volume->windowWidths);
        volume->windowWidths = nullptr;
    }
    if (volume->allTags) {
        freeTagEntries(volume->allTags, volume->allTagCount);
        volume->allTags = nullptr;
    }
}

} // namespace

int nm_dicom_load_series(const char *directoryPath, NM_DicomVolume **outVolume) {
    if (outVolume == nullptr || directoryPath == nullptr) {
        return NM_DicomErrorLoadFailed;
    }

    std::vector<std::string> filePaths;
    for (const auto &entry : std::filesystem::directory_iterator(directoryPath)) {
        if (entry.is_regular_file()) {
            filePaths.push_back(entry.path().string());
        }
    }

    if (filePaths.empty()) {
        return NM_DicomErrorNoFiles;
    }

    std::vector<SliceData> slices;
    unsigned long width = 0;
    unsigned long height = 0;
    for (const auto &path : filePaths) {
        SliceData slice;
        unsigned long sliceWidth = 0;
        unsigned long sliceHeight = 0;
        if (!loadSlice(path, slice, sliceWidth, sliceHeight)) {
            continue;
        }

        if (width == 0 && height == 0) {
            width = sliceWidth;
            height = sliceHeight;
        } else if (width != sliceWidth || height != sliceHeight) {
            return NM_DicomErrorInvalidDimensions;
        }

        slices.push_back(std::move(slice));
    }

    if (slices.empty()) {
        return NM_DicomErrorLoadFailed;
    }

    // Sort by normal distance (preferred) or instance number
    std::sort(slices.begin(), slices.end(), [](const SliceData &a, const SliceData &b) {
        if (a.normalDistance != 0.0 || b.normalDistance != 0.0) {
            return a.normalDistance < b.normalDistance;
        }
        return a.instanceNumber < b.instanceNumber;
    });

    const int depth = static_cast<int>(slices.size());
    const size_t voxelCount = static_cast<size_t>(width) * static_cast<size_t>(height) * static_cast<size_t>(depth);

    NM_DicomVolume *volume = static_cast<NM_DicomVolume *>(std::calloc(1, sizeof(NM_DicomVolume)));
    if (!volume) {
        return NM_DicomErrorAllocationFailed;
    }

    volume->width = static_cast<int>(width);
    volume->height = static_cast<int>(height);
    volume->depth = depth;
    volume->spacingX = static_cast<float>(slices.front().spacingX);
    volume->spacingY = static_cast<float>(slices.front().spacingY);

    double spacingZ = slices.front().spacingBetweenSlices;
    if (spacingZ <= 0.0 && slices.size() >= 2 && slices[0].position.size() == 3 && slices[1].position.size() == 3 && slices[0].orientation.size() == 6) {
        const double nx = slices[0].orientation[1] * slices[0].orientation[5] - slices[0].orientation[2] * slices[0].orientation[4];
        const double ny = slices[0].orientation[2] * slices[0].orientation[3] - slices[0].orientation[0] * slices[0].orientation[5];
        const double nz = slices[0].orientation[0] * slices[0].orientation[4] - slices[0].orientation[1] * slices[0].orientation[3];
        const double dx = slices[1].position[0] - slices[0].position[0];
        const double dy = slices[1].position[1] - slices[0].position[1];
        const double dz = slices[1].position[2] - slices[0].position[2];
        spacingZ = std::abs(nx * dx + ny * dy + nz * dz);
    }
    if (spacingZ <= 0.0) {
        spacingZ = slices.front().sliceThickness > 0.0 ? slices.front().sliceThickness : 1.0;
    }
    volume->spacingZ = static_cast<float>(spacingZ);
    volume->spacingBetweenSlices = static_cast<float>(slices.front().spacingBetweenSlices);
    volume->sliceThickness = static_cast<float>(slices.front().sliceThickness);

    if (slices.front().orientation.size() == 6) {
        std::copy(slices.front().orientation.begin(), slices.front().orientation.begin() + 6, volume->orientation);
    }
    if (slices.front().position.size() == 3) {
        std::copy(slices.front().position.begin(), slices.front().position.begin() + 3, volume->position);
    }

    volume->voxels = static_cast<float *>(std::malloc(sizeof(float) * voxelCount));
    if (!volume->voxels) {
        std::free(volume);
        return NM_DicomErrorAllocationFailed;
    }

    // Populate buffer in z–y–x order
    for (int z = 0; z < depth; ++z) {
        const auto &slice = slices[static_cast<size_t>(z)];
        const size_t sliceBase = static_cast<size_t>(z) * static_cast<size_t>(width) * static_cast<size_t>(height);
        for (unsigned long y = 0; y < height; ++y) {
            const size_t rowBase = sliceBase + static_cast<size_t>(y) * static_cast<size_t>(width);
            const size_t rowOffset = static_cast<size_t>(y) * static_cast<size_t>(width);
            for (unsigned long x = 0; x < width; ++x) {
                const size_t dstIndex = rowBase + x;
                const size_t srcIndex = rowOffset + x;
                volume->voxels[dstIndex] = slice.pixels[srcIndex];
            }
        }
    }

    // Metadata from the first slice
    populateMetadataFromDataset(slices.front().dataset, volume);

    // Collect tag map
    std::vector<OwnedTagEntry> ownedTags;
    collectTagEntries(slices.front().dataset, ownedTags);
    volume->allTagCount = static_cast<int>(ownedTags.size());
    if (!ownedTags.empty()) {
        volume->allTags = static_cast<NM_DicomTagEntry *>(std::calloc(static_cast<size_t>(ownedTags.size()), sizeof(NM_DicomTagEntry)));
        if (!volume->allTags) {
            nm_dicom_free(volume);
            return NM_DicomErrorAllocationFailed;
        }
        for (size_t i = 0; i < ownedTags.size(); ++i) {
            const auto &source = ownedTags[i];
            NM_DicomTagEntry &dest = volume->allTags[i];
            dest.tagKey = copyCString(source.key);
            dest.valueType = source.type;
            dest.intValue = source.intValue;
            dest.doubleValue = source.doubleValue;
            if (!source.stringValue.empty()) {
                dest.stringValue = copyCString(source.stringValue);
            }
            if (!source.dataValue.empty()) {
                dest.dataLength = source.dataValue.size();
                dest.dataValue = static_cast<uint8_t *>(std::malloc(source.dataValue.size()));
                if (dest.dataValue) {
                    std::copy(source.dataValue.begin(), source.dataValue.end(), dest.dataValue);
                }
            }
        }
    }

    *outVolume = volume;
    return NM_DicomErrorNone;
}

void nm_dicom_free(NM_DicomVolume *volume) {
    if (!volume) {
        return;
    }

    freeVolumeMetadata(volume);

    if (volume->voxels) {
        std::free(volume->voxels);
        volume->voxels = nullptr;
    }

    std::free(volume);
}
