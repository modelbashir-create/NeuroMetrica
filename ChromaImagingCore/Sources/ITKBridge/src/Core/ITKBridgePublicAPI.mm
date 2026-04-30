#import "ITKBridge.h"

#include "ITKBridgeInternal.h"

#include <cstdlib>
#include <cstring>

#include "itkVersion.h"

#include "../Utils/ITKBridgeUtils.h"
#include "../Descriptor/DescriptorBuilder.h"

namespace {

void zeroJSONStringResult(ITKJSONStringResultC *result) {
    if (!result) {
        return;
    }
    result->json = nullptr;
    result->jsonLength = 0;
}

bool attachJSONString(ITKJSONStringResultC *outResult,
                      const std::string &json,
                      std::string *errorMessage = nullptr) {
    if (!outResult) {
        if (errorMessage) {
            *errorMessage = "ITK JSON result: null output pointer";
        }
        return false;
    }

    zeroJSONStringResult(outResult);
    if (json.empty()) {
        return true;
    }

    const size_t length = json.size();
    char *buffer = static_cast<char *>(std::malloc(length + 1));
    if (!buffer) {
        if (errorMessage) {
            *errorMessage = "ITK JSON result: memory allocation failed";
        }
        return false;
    }

    std::memcpy(buffer, json.c_str(), length);
    buffer[length] = '\0';
    outResult->json = buffer;
    outResult->jsonLength = static_cast<int32_t>(length);
    return true;
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

extern "C" bool ITKLoadDicomSeriesSelectionWithBackend(const char *directoryPath,
                                                       const char *seriesInstanceUID,
                                                       const char *subseriesKey,
                                                       ITKDicomBackendC backend,
                                                       ITKImageDescriptorC *outDescriptor,
                                                       char *errorBuffer,
                                                       int errorBufferLength) {
    zeroDescriptor(outDescriptor);

    if (!directoryPath || !outDescriptor) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadDicomSeriesSelectionWithBackend: null argument");
        return false;
    }

    if (!isDirectory(directoryPath)) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKLoadDicomSeriesSelectionWithBackend: path is not a directory");
        return false;
    }

    try {
        ITKDicomBackendC resolvedBackend = backend;
#if !ITKBRIDGE_HAS_DCMTK
        if (resolvedBackend == ITKDicomBackend_DCMTK || resolvedBackend == ITKDicomBackend_Auto) {
            resolvedBackend = ITKDicomBackend_GDCM;
        }
#endif

        VolumeLoadResult result = loadDicomSeriesSelection(
            directoryPath,
            seriesInstanceUID,
            subseriesKey,
            resolvedBackend
        );
        if (!result.image) {
            writeError(errorBuffer, errorBufferLength,
                       "ITKLoadDicomSeriesSelectionWithBackend: reader returned null image");
            return false;
        }

        std::string buildError;
        if (!buildDescriptorFromResult(result, outDescriptor, "ITKLoadDicomSeriesSelectionWithBackend", &buildError)) {
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
                   "ITKLoadDicomSeriesSelectionWithBackend: unknown exception");
        return false;
    }
}

extern "C" bool ITKInspectDicomDirectory(const char *directoryPath,
                                         ITKJSONStringResultC *outResult,
                                         char *errorBuffer,
                                         int errorBufferLength) {
    return ITKInspectDicomDirectoryWithBackend(
        directoryPath,
        ITKDicomBackend_Auto,
        outResult,
        errorBuffer,
        errorBufferLength
    );
}

extern "C" bool ITKInspectDicomDirectoryWithBackend(const char *directoryPath,
                                                    ITKDicomBackendC backend,
                                                    ITKJSONStringResultC *outResult,
                                                    char *errorBuffer,
                                                    int errorBufferLength) {
    zeroJSONStringResult(outResult);

    if (!directoryPath || !outResult) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKInspectDicomDirectoryWithBackend: null argument");
        return false;
    }

    if (!isDirectory(directoryPath)) {
        writeError(errorBuffer, errorBufferLength,
                   "ITKInspectDicomDirectoryWithBackend: path is not a directory");
        return false;
    }

    try {
        ITKDicomBackendC resolvedBackend = backend;
#if !ITKBRIDGE_HAS_DCMTK
        if (resolvedBackend == ITKDicomBackend_DCMTK || resolvedBackend == ITKDicomBackend_Auto) {
            resolvedBackend = ITKDicomBackend_GDCM;
        }
#endif
        const std::string inspectionJSON = inspectDicomDirectory(directoryPath, resolvedBackend);
        std::string attachError;
        if (!attachJSONString(outResult, inspectionJSON, &attachError)) {
            writeError(errorBuffer, errorBufferLength, attachError.c_str());
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
                   "ITKInspectDicomDirectoryWithBackend: unknown exception");
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

extern "C" void ITKFreeJSONStringResult(ITKJSONStringResultC *result) {
    if (!result) {
        return;
    }
    if (result->json != nullptr) {
        void *ptr = const_cast<char *>(result->json);
        std::free(ptr);
    }
    zeroJSONStringResult(result);
}
