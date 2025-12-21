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
#include "itkImageIOBase.h"
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

// Load a 3D float volume from a DICOM series directory using GDCM.
Float3DImage::Pointer loadDicomSeries(const char *directoryPath) {
    using ImageType   = Float3DImage;
    using ReaderType  = itk::ImageSeriesReader<ImageType>;
    using ImageIOType = itk::GDCMImageIO;
    using NameGenType = itk::GDCMSeriesFileNames;

    NameGenType::Pointer nameGen = NameGenType::New();
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
    ImageIOType::Pointer dicomIO = ImageIOType::New();
    reader->SetImageIO(dicomIO);
    reader->SetFileNames(fileNames);
    reader->Update();

    return reader->GetOutput();
}

// Load a 3D float volume from a single volume file (NIfTI, NRRD, etc).
Float3DImage::Pointer loadSingleFileVolume(const char *filePath) {
    using ReaderType = itk::ImageFileReader<Float3DImage>;
    ReaderType::Pointer reader = ReaderType::New();
    reader->SetFileName(std::string(filePath));
    reader->Update();
    return reader->GetOutput();
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

extern "C" bool ITKLoadDicomSeries(const char *directoryPath,
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
        Float3DImage::Pointer image = loadDicomSeries(directoryPath);
        if (!image) {
            writeError(errorBuffer, errorBufferLength,
                       "ITKLoadDicomSeries: reader returned null image");
            return false;
        }

        // Compute value count and allocate buffer.
        const auto &size = image->GetLargestPossibleRegion().GetSize();
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

        const float *src = image->GetBufferPointer();
        std::memcpy(buffer, src, static_cast<size_t>(byteCount));

        // Fill descriptor.
        fillDescriptorFromImage(image, buffer, valueCount, outDescriptor);
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
        Float3DImage::Pointer image = loadSingleFileVolume(filePath);
        if (!image) {
            writeError(errorBuffer, errorBufferLength,
                       "ITKLoadSingleFileVolume: reader returned null image");
            return false;
        }

        const auto &size = image->GetLargestPossibleRegion().GetSize();
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

        const float *src = image->GetBufferPointer();
        std::memcpy(buffer, src, static_cast<size_t>(byteCount));

        fillDescriptorFromImage(image, buffer, valueCount, outDescriptor);
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
    // Put descriptor into a safe, zeroed state.
    zeroDescriptor(descriptor);
}
