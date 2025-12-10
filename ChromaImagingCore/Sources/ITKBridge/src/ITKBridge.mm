//
//  ITKBridge.mm
//  ChromaImagingCore
//
//  Thin C / Objective-C++ bridge between Swift (ChromaImagingCore)
//  and ITK + GDCM. Responsible ONLY for:
//    - Reading volumes (DICOM series dir, NIfTI, NRRD, etc.)
//    - Exposing basic metadata (size, spacing, origin, direction, type)
//    - Copying voxel data into a caller-provided buffer
//
//  All higher-level logic lives in Swift (ITKImageIO, CIImageVolume, etc.)
//

#import "ITKBridge.h"

#include <string>
#include <cstring>
#include <vector>
#include <sys/stat.h>
#include <cstddef> // size_t

// ITK & GDCM
#include "itkImage.h"
#include "itkImageFileReader.h"
#include "itkImageSeriesReader.h"
#include "itkGDCMImageIO.h"
#include "itkGDCMSeriesFileNames.h"
#include "itkImageIOBase.h"
#include "itkVersion.h"

using Float3DImage = itk::Image<float, 3>;

// Internal volume wrapper that backs NMVolumeHandle.
// Right now we only support 3D float volumes; this can be extended later.
struct NMVolume {
    Float3DImage::Pointer image;
};

namespace {

/// Simple error-code values used internally.
/// Swift can mirror these if needed, but they're not part of the public C API.
enum : int32_t {
    NMIErrorCode_None            = 0,
    NMIErrorCode_InvalidArgument = 1,
    NMIErrorCode_LoadFailed      = 2,
    NMIErrorCode_BufferTooSmall  = 3,
    NMIErrorCode_UnsupportedType = 4,
    NMIErrorCode_Unknown         = 999
};

inline NMVolume *unwrap(NMVolumeHandle handle) {
    return reinterpret_cast<NMVolume *>(handle);
}

inline NMVolumeHandle wrap(NMVolume *volume) {
    return reinterpret_cast<NMVolumeHandle>(volume);
}

// Static storage for error messages so we can safely return const char*.
static std::string gLastErrorMessage;

inline NMIError makeError(int32_t code, const char *message) {
    if (message) {
        gLastErrorMessage = message;
        NMIError err;
        err.code    = code;
        err.message = gLastErrorMessage.c_str();
        return err;
    } else {
        gLastErrorMessage.clear();
        NMIError err;
        err.code    = code;
        err.message = nullptr;
        return err;
    }
}

inline NMIError makeErrorFromException(const itk::ExceptionObject &ex,
                                       int32_t code) {
    gLastErrorMessage = ex.GetDescription();
    NMIError err;
    err.code    = code;
    err.message = gLastErrorMessage.c_str();
    return err;
}

inline bool isDirectory(const char *path) {
    if (!path) {
        return false;
    }
    struct stat s;
    if (stat(path, &s) != 0) {
        return false;
    }
    return (s.st_mode & S_IFDIR) != 0;
}

/// Fill an NMVolumeDescriptor from an ITK 3D float image.
///
/// NOTE: This assumes NMVolumeDescriptor (in ITKBridge.h) has:
///   uint32_t dimension;
///   uint32_t size[3];
///   double   spacing[3];
///   double   origin[3];
///   double   direction[9]; // 3x3 row-major
///   int32_t  componentType;
///   int32_t  componentsPerPixel;
inline void fillDescriptorFromImage(const Float3DImage::Pointer &image,
                                    NMVolumeDescriptor *outDescriptor) {
    if (!outDescriptor || !image) { return; }

    using SizeType      = Float3DImage::SizeType;
    using SpacingType   = Float3DImage::SpacingType;
    using PointType     = Float3DImage::PointType;
    using DirectionType = Float3DImage::DirectionType;

    const SizeType      &size    = image->GetLargestPossibleRegion().GetSize();
    const SpacingType   &spacing = image->GetSpacing();
    const PointType     &origin  = image->GetOrigin();
    const DirectionType &dir     = image->GetDirection();

    // We currently assume 3D volumes.
    outDescriptor->dimension = 3;

    // Sizes.
    outDescriptor->size[0] = static_cast<uint32_t>(size[0]);
    outDescriptor->size[1] = static_cast<uint32_t>(size[1]);
    outDescriptor->size[2] = static_cast<uint32_t>(size[2]);

    // Spacing.
    outDescriptor->spacing[0] = spacing[0];
    outDescriptor->spacing[1] = spacing[1];
    outDescriptor->spacing[2] = spacing[2];

    // Origin.
    outDescriptor->origin[0] = origin[0];
    outDescriptor->origin[1] = origin[1];
    outDescriptor->origin[2] = origin[2];

    // Direction: 3x3 matrix flattened row-major.
    std::memset(outDescriptor->direction, 0, sizeof(outDescriptor->direction));
    for (unsigned int r = 0; r < 3; ++r) {
        for (unsigned int c = 0; c < 3; ++c) {
            outDescriptor->direction[r * 3 + c] = dir(r, c);
        }
    }

    // Component metadata – we are currently using float scalar voxels.
    outDescriptor->componentType =
        static_cast<int32_t>(itk::IOComponentEnum::FLOAT);
    outDescriptor->componentsPerPixel = 1;
}

inline size_t voxelCount(const NMVolumeDescriptor &desc) {
    return static_cast<size_t>(desc.size[0]) *
           static_cast<size_t>(desc.size[1]) *
           static_cast<size_t>(desc.size[2]);
}

inline size_t bytesPerComponent(int32_t componentType) {
    using itk::IOComponentEnum;
    switch (static_cast<IOComponentEnum>(componentType)) {
        case IOComponentEnum::UCHAR:
        case IOComponentEnum::CHAR:
            return 1;
        case IOComponentEnum::USHORT:
        case IOComponentEnum::SHORT:
            return 2;
        case IOComponentEnum::UINT:
        case IOComponentEnum::INT:
        case IOComponentEnum::FLOAT:
            return 4;
        case IOComponentEnum::DOUBLE:
            return 8;
        default:
            return 0;
    }
}

/// Internal helper that loads an ITK image from either a single file
/// (NIfTI/NRRD/MHA/single DICOM, etc.) or a DICOM series directory.
Float3DImage::Pointer loadImageFromPath(const char *path) {
    if (!path) {
        throw itk::ExceptionObject(__FILE__, __LINE__,
                                   "loadImageFromPath: null path",
                                   "ITKBridge");
    }

    if (isDirectory(path)) {
        // Treat as a DICOM series directory using GDCM.
        using ImageType   = Float3DImage;
        using ReaderType  = itk::ImageSeriesReader<ImageType>;
        using ImageIOType = itk::GDCMImageIO;
        using NameGenType = itk::GDCMSeriesFileNames;

        NameGenType::Pointer nameGen = NameGenType::New();
        nameGen->SetUseSeriesDetails(true);
        nameGen->AddSeriesRestriction("0008|0021"); // Series Date; keeps similar series together.
        nameGen->SetDirectory(path);

        const std::vector<std::string> &seriesUIDs = nameGen->GetSeriesUIDs();
        if (seriesUIDs.empty()) {
            throw itk::ExceptionObject(__FILE__, __LINE__,
                                       "No DICOM series found in directory",
                                       "ITKBridge");
        }

        // For now, just take the first series.
        const std::string &seriesUID = seriesUIDs[0];
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
    } else {
        // Treat as a single volume file (NIfTI, NRRD, MHA, single-slice DICOM, etc.).
        using ReaderType = itk::ImageFileReader<Float3DImage>;
        ReaderType::Pointer reader = ReaderType::New();
        reader->SetFileName(std::string(path));
        reader->Update();
        return reader->GetOutput();
    }
}

} // anonymous namespace

extern "C" {

#pragma mark - Version

/// Canonical version function used by Swift (ITKInfo).
const char *ITKBridgeGetVersionString(void) {
    static std::string version = itk::Version::GetITKVersion();
    return version.c_str();
}

// Optional aliases if you had older code calling these:
const char *nm_itk_version_string(void) {
    return ITKBridgeGetVersionString();
}

const char *itkVersionString(void) {
    return ITKBridgeGetVersionString();
}

#pragma mark - Volume Lifetime

NMVolumeHandle nm_itk_load_volume(const char *path,
                                  NMVolumeDescriptor *outDescriptor,
                                  NMIError *outError) {
    if (outError) {
        *outError = makeError(NMIErrorCode_None, nullptr);
    }
    if (!path || !outDescriptor) {
        if (outError) {
            *outError = makeError(NMIErrorCode_InvalidArgument,
                                  "nm_itk_load_volume: null argument");
        }
        return nullptr;
    }

    // Clear descriptor to a known state up front.
    std::memset(outDescriptor, 0, sizeof(*outDescriptor));

    try {
        Float3DImage::Pointer image = loadImageFromPath(path);
        if (!image) {
            if (outError) {
                *outError = makeError(NMIErrorCode_LoadFailed,
                                      "nm_itk_load_volume: reader returned null image");
            }
            return nullptr;
        }

        // Allocate our handle wrapper.
        NMVolume *volume = new NMVolume();
        volume->image = image;

        fillDescriptorFromImage(image, outDescriptor);
        return wrap(volume);
    }
    catch (const itk::ExceptionObject &ex) {
        if (outError) {
            *outError = makeErrorFromException(ex, NMIErrorCode_LoadFailed);
        }
        return nullptr;
    }
    catch (...) {
        if (outError) {
            *outError = makeError(NMIErrorCode_Unknown,
                                  "nm_itk_load_volume: unknown exception");
        }
        return nullptr;
    }
}

void nm_itk_release_volume(NMVolumeHandle handle) {
    if (!handle) { return; }
    NMVolume *volume = unwrap(handle);
    delete volume;
}

#pragma mark - Volume Data Copy

int nm_itk_copy_volume_data(NMVolumeHandle handle,
                            void *destBuffer,
                            size_t destBufferSizeBytes,
                            NMIError *outError) {
    if (outError) {
        *outError = makeError(NMIErrorCode_None, nullptr);
    }

    if (!handle || !destBuffer) {
        if (outError) {
            *outError = makeError(NMIErrorCode_InvalidArgument,
                                  "nm_itk_copy_volume_data: null argument");
        }
        return NMIErrorCode_InvalidArgument;
    }

    NMVolume *volume = unwrap(handle);
    if (!volume || !volume->image) {
        if (outError) {
            *outError = makeError(NMIErrorCode_InvalidArgument,
                                  "nm_itk_copy_volume_data: invalid handle");
        }
        return NMIErrorCode_InvalidArgument;
    }

    // Rebuild a descriptor to compute expected size.
    NMVolumeDescriptor desc = {};
    fillDescriptorFromImage(volume->image, &desc);

    const size_t voxel_count         = voxelCount(desc);
    const size_t bytes_per_component = bytesPerComponent(desc.componentType);
    if (bytes_per_component == 0) {
        if (outError) {
            *outError = makeError(NMIErrorCode_UnsupportedType,
                                  "nm_itk_copy_volume_data: unsupported component type");
        }
        return NMIErrorCode_UnsupportedType;
    }

    const size_t expected_bytes =
        voxel_count *
        static_cast<size_t>(desc.componentsPerPixel) *
        bytes_per_component;

    if (destBufferSizeBytes < expected_bytes) {
        if (outError) {
            *outError = makeError(NMIErrorCode_BufferTooSmall,
                                  "nm_itk_copy_volume_data: destination buffer too small");
        }
        return NMIErrorCode_BufferTooSmall;
    }

    // For now we assume Float32 scalar voxels and copy directly.
    Float3DImage::Pointer image = volume->image;
    const float *src = image->GetBufferPointer();
    std::memcpy(destBuffer, src, expected_bytes);

    return NMIErrorCode_None;
}

} // extern "C"
