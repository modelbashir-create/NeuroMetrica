#import "ITKBridge.h"

#include <string>
#include <vector>
#include <cstring>
#include <sys/stat.h>

#include "itkImage.h"
#include "itkImageFileReader.h"
#include "itkImageSeriesReader.h"
#include "itkGDCMImageIO.h"
#include "itkGDCMSeriesFileNames.h"
#if __has_include("itkDCMTKImageIO.h")
#include "itkDCMTKImageIO.h"
#define ITKBRIDGE_HAS_DCMTK 1
#else
#define ITKBRIDGE_HAS_DCMTK 0
#endif
#include "itkImageIOBase.h"
#include "itkMetaDataObject.h"
#include "itkVersion.h"

using Float3DImage = itk::Image<float, 3>;

namespace {

// Simple directory check.
bool isDirectory(const char *path) {
    if (!path) {
        return false;
    }
    struct stat s;
    if (stat(path, &s) != 0) {
        return false;
    }
    return (s.st_mode & S_IFDIR) != 0;
}

// Small helper to write an error string into a C buffer.
void writeError(char *buffer, int bufferLength, const char *message) {
    if (!buffer || bufferLength <= 0) {
        return;
    }
    if (!message) {
        buffer[0] = '\0';
        return;
    }
    const size_t len = std::strlen(message);
    const size_t toCopy =
        (len + 1 < static_cast<size_t>(bufferLength))
            ? len
            : static_cast<size_t>(bufferLength - 1);
    std::memcpy(buffer, message, toCopy);
    buffer[toCopy] = '\0';
}

void zeroDescriptor(ITKImageDescriptorC *desc) {
    if (!desc) { return; }
    std::memset(desc, 0, sizeof(*desc));
}

bool supportsDCMTK() {
#if ITKBRIDGE_HAS_DCMTK
    return true;
#else
    return false;
#endif
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

std::string escapeJSON(const std::string &input) {
    std::string output;
    output.reserve(input.size());
    for (char c : input) {
        switch (c) {
        case '\"': output += "\\\""; break;
        case '\\': output += "\\\\"; break;
        case '\n': output += "\\n"; break;
        case '\r': output += "\\r"; break;
        case '\t': output += "\\t"; break;
        default: output += c; break;
        }
    }
    return output;
}

std::string metadataDictionaryToJSON(const itk::MetaDataDictionary &dict) {
    std::string json = "{";
    bool first = true;

    for (auto it = dict.Begin(); it != dict.End(); ++it) {
        const std::string &key = it->first;
        std::string value;
        if (!itk::ExposeMetaData<std::string>(dict, key, value)) {
            continue;
        }

        if (!first) {
            json += ",";
        }
        first = false;
        json += "\"";
        json += escapeJSON(key);
        json += "\":\"";
        json += escapeJSON(value);
        json += "\"";
    }

    json += "}";
    return json;
}

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

struct VolumeLoadResult {
    Float3DImage::Pointer image;
    std::string metadataJSON;
};

// Load a 3D float volume from a DICOM series directory using a selected backend.
VolumeLoadResult loadDicomSeries(const char *directoryPath,
                                 ITKDicomBackendC backend) {
    using ImageType   = Float3DImage;
    using ReaderType  = itk::ImageSeriesReader<ImageType>;
    using GDCMNameGenType = itk::GDCMSeriesFileNames;

    GDCMNameGenType::Pointer nameGen = GDCMNameGenType::New();
    nameGen->SetUseSeriesDetails(true);
    nameGen->AddSeriesRestriction("0008|0021"); // Series Date.
    nameGen->SetDirectory(directoryPath);

    const std::vector<std::string> &seriesUIDs = nameGen->GetSeriesUIDs();
    if (seriesUIDs.empty()) {
        throw itk::ExceptionObject(__FILE__, __LINE__,
                                   "No DICOM series found in directory",
                                   "ITKBridge");
    }

    // For now, just take the first series.
    const std::string &seriesUID = seriesUIDs.front();
    std::vector<std::string> fileNames = nameGen->GetFileNames(seriesUID);

    if (fileNames.empty()) {
        throw itk::ExceptionObject(__FILE__, __LINE__,
                                   "DICOM series has no files",
                                   "ITKBridge");
    }

    ReaderType::Pointer reader = ReaderType::New();
    itk::ImageIOBase::Pointer dicomIO = makeDicomIO(backend);
    reader->SetImageIO(dicomIO);
    reader->SetFileNames(fileNames);
    reader->Update();

    VolumeLoadResult result;
    result.image = reader->GetOutput();
    result.metadataJSON = metadataDictionaryToJSON(reader->GetImageIO()->GetMetaDataDictionary());
    return result;
}

// Load a 3D float volume from a single volume file (NIfTI, NRRD, etc).
VolumeLoadResult loadSingleFileVolume(const char *filePath) {
    using ReaderType = itk::ImageFileReader<Float3DImage>;
    ReaderType::Pointer reader = ReaderType::New();
    reader->SetFileName(std::string(filePath));
    reader->Update();
    VolumeLoadResult result;
    result.image = reader->GetOutput();
    result.metadataJSON = metadataDictionaryToJSON(reader->GetImageIO()->GetMetaDataDictionary());
    return result;
}

// Fill an ITKImageDescriptorC from a Float3DImage and a copied buffer.
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

    // Size (pad remaining slots to 1).
    outDescriptor->size[0] = static_cast<uint64_t>(size[0]);
    outDescriptor->size[1] = static_cast<uint64_t>(size[1]);
    outDescriptor->size[2] = static_cast<uint64_t>(size[2]);
    outDescriptor->size[3] = 1;

    // Spacing (pad remaining slots to 1.0).
    outDescriptor->spacing[0] = spacing[0];
    outDescriptor->spacing[1] = spacing[1];
    outDescriptor->spacing[2] = spacing[2];
    outDescriptor->spacing[3] = 1.0;

    // Origin.
    outDescriptor->origin[0] = origin[0];
    outDescriptor->origin[1] = origin[1];
    outDescriptor->origin[2] = origin[2];
    outDescriptor->origin[3] = 0.0;

    // Direction: 3x3 matrix flattened row-major into the first 9 entries,
    // rest zeroed.
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

    outDescriptor->componentBytes = 4;  // float32
    outDescriptor->isSigned       = 1;  // floats are signed
}

} // namespace

extern "C" bool ITKBridgeGetVersionString(char *buffer, int bufferLength) {
    const std::string version = itk::Version::GetITKVersion();
    if (!buffer || bufferLength <= 0) {
        return false;
    }
    const size_t len = version.size();
    const size_t toCopy =
        (len + 1 < static_cast<size_t>(bufferLength))
            ? len
            : static_cast<size_t>(bufferLength - 1);
    std::memcpy(buffer, version.c_str(), toCopy);
    buffer[toCopy] = '\0';
    return true;
}

extern "C" bool ITKBridgeSupportsDCMTK(void) {
    return supportsDCMTK();
}

extern "C" bool ITKLoadDicomSeries(const char *directoryPath,
                                   ITKImageDescriptorC *outDescriptor,
                                   char *errorBuffer,
                                   int errorBufferLength) {
    return ITKLoadDicomSeriesWithBackend(
        directoryPath,
        ITKDicomBackend_Auto,
        outDescriptor,
        errorBuffer,
        errorBufferLength
    );
}

extern "C" bool ITKLoadDicomSeriesWithBackend(const char *directoryPath,
                                              ITKDicomBackendC backend,
                                              ITKImageDescriptorC *outDescriptor,
                                              char *errorBuffer,
                                              int errorBufferLength) {
    zeroDescriptor(outDescriptor);

    if (!directoryPath || !outDescriptor) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadDicomSeries: null argument");
        return false;
    }

    if (!isDirectory(directoryPath)) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadDicomSeries: path is not a directory");
        return false;
    }

    try {
        ITKDicomBackendC resolvedBackend = backend;
#if !ITKBRIDGE_HAS_DCMTK
        if (resolvedBackend == ITKDicomBackend_DCMTK || resolvedBackend == ITKDicomBackend_Auto) {
            resolvedBackend = ITKDicomBackend_GDCM;
        }
#endif

        VolumeLoadResult result = loadDicomSeries(directoryPath, resolvedBackend);
        if (!result.image) {
            writeError(errorBuffer, errorBufferLength,
                       "ITKLoadDicomSeries: reader returned null image");
            return false;
        }

        // Compute value count and allocate buffer.
        const auto &size = result.image->GetLargestPossibleRegion().GetSize();
        const uint64_t voxelCount =
            static_cast<uint64_t>(size[0]) *
            static_cast<uint64_t>(size[1]) *
            static_cast<uint64_t>(size[2]);
        const uint64_t componentsPerPixel = 1;
        const uint64_t valueCount         = voxelCount * componentsPerPixel;
        const uint64_t byteCount          = valueCount * 4; // float32

        void *buffer = std::malloc(static_cast<size_t>(byteCount));
        if (!buffer) {
            writeError(errorBuffer, errorBufferLength,
                       "ITKLoadDicomSeries: failed to allocate voxel buffer");
            return false;
        }

        const float *src = result.image->GetBufferPointer();
        std::memcpy(buffer, src, static_cast<size_t>(byteCount));

        // Fill descriptor.
        fillDescriptorFromImage(result.image, buffer, valueCount, outDescriptor);
        attachMetadataJSON(outDescriptor, result.metadataJSON);
        return true;
    }
    catch (const itk::ExceptionObject &ex) {
        writeError(errorBuffer, errorBufferLength, ex.GetDescription());
        return false;
    }
    catch (...) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadDicomSeries: unknown exception");
        return false;
    }
}

extern "C" bool ITKLoadSingleFileVolume(const char *filePath,
                                        ITKImageDescriptorC *outDescriptor,
                                        char *errorBuffer,
                                        int errorBufferLength) {
    zeroDescriptor(outDescriptor);

    if (!filePath || !outDescriptor) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadSingleFileVolume: null argument");
        return false;
    }

    try {
        VolumeLoadResult result = loadSingleFileVolume(filePath);
        if (!result.image) {
            writeError(errorBuffer, errorBufferLength,
                       "ITKLoadSingleFileVolume: reader returned null image");
            return false;
        }

        const auto &size = result.image->GetLargestPossibleRegion().GetSize();
        const uint64_t voxelCount =
            static_cast<uint64_t>(size[0]) *
            static_cast<uint64_t>(size[1]) *
            static_cast<uint64_t>(size[2]);
        const uint64_t componentsPerPixel = 1;
        const uint64_t valueCount         = voxelCount * componentsPerPixel;
        const uint64_t byteCount          = valueCount * 4; // float32

        void *buffer = std::malloc(static_cast<size_t>(byteCount));
        if (!buffer) {
            writeError(errorBuffer, errorBufferLength,
                       "ITKLoadSingleFileVolume: failed to allocate voxel buffer");
            return false;
        }

        const float *src = result.image->GetBufferPointer();
        std::memcpy(buffer, src, static_cast<size_t>(byteCount));

        fillDescriptorFromImage(result.image, buffer, valueCount, outDescriptor);
        attachMetadataJSON(outDescriptor, result.metadataJSON);
        return true;
    }
    catch (const itk::ExceptionObject &ex) {
        writeError(errorBuffer, errorBufferLength, ex.GetDescription());
        return false;
    }
    catch (...) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadSingleFileVolume: unknown exception");
        return false;
    }
}

extern "C" void ITKFreeImageDescriptor(ITKImageDescriptorC *descriptor) {
    if (!descriptor) { return; }

    if (descriptor->bufferHandle != nullptr) {
        void *ptr = const_cast<void *>(descriptor->bufferHandle);
        std::free(ptr);
    }
    if (descriptor->metadataJSON != nullptr) {
        void *ptr = const_cast<char *>(descriptor->metadataJSON);
        std::free(ptr);
    }
    // Put descriptor into a safe, zeroed state.
    zeroDescriptor(descriptor);
}
