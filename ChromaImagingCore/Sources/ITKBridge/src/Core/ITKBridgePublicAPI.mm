#import "ITKBridge.h"

#include "ITKBridgeInternal.h"

#include <cstring>

#include "itkVersion.h"

#include "../Utils/ITKBridgeUtils.h"
#include "../Descriptor/DescriptorBuilder.h"

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

        std::string buildError;
        if (!buildDescriptorFromResult(result, outDescriptor, "ITKLoadDicomSeries", &buildError)) {
            writeError(errorBuffer, errorBufferLength, buildError.c_str());
            return false;
        }
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

        std::string buildError;
        if (!buildDescriptorFromResult(result, outDescriptor, "ITKLoadSingleFileVolume", &buildError)) {
            writeError(errorBuffer, errorBufferLength, buildError.c_str());
            return false;
        }
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

extern "C" bool ITKLoadDicomFileWithBackend(const char *filePath,
                                            ITKDicomBackendC backend,
                                            ITKImageDescriptorC *outDescriptor,
                                            char *errorBuffer,
                                            int errorBufferLength) {
    zeroDescriptor(outDescriptor);

    if (!filePath || !outDescriptor) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadDicomFileWithBackend: null argument");
        return false;
    }

    if (!isDicomPath(filePath)) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadDicomFileWithBackend: file is not a .dcm path");
        return false;
    }

    try {
#if !ITKBRIDGE_HAS_DCMTK
        if (backend == ITKDicomBackend_DCMTK || backend == ITKDicomBackend_Auto) {
            backend = ITKDicomBackend_GDCM;
        }
#endif
        VolumeLoadResult result = loadDicomFile(filePath, backend);
        if (!result.image) {
            writeError(errorBuffer, errorBufferLength,
                       "ITKLoadDicomFileWithBackend: reader returned null image");
            return false;
        }

        std::string buildError;
        if (!buildDescriptorFromResult(result, outDescriptor, "ITKLoadDicomFileWithBackend", &buildError)) {
            writeError(errorBuffer, errorBufferLength, buildError.c_str());
            return false;
        }
        return true;
    }
    catch (const itk::ExceptionObject &ex) {
        writeError(errorBuffer, errorBufferLength, ex.GetDescription());
        return false;
    }
    catch (...) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadDicomFileWithBackend: unknown exception");
        return false;
    }
}

extern "C" void ITKFreeImageDescriptor(ITKImageDescriptorC *descriptor) {
    freeDescriptor(descriptor);
}
