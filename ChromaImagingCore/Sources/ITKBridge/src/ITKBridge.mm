#import "ITKBridge.h"

#include <string>
#include <vector>
#include <cstring>
#include <algorithm>
#include <sys/stat.h>
#include <map>
#include <sstream>
#include <iomanip>
#include <cmath>

#include "itkImage.h"
#include "itkImageFileReader.h"
#include "itkImageSeriesReader.h"
#include "itkGDCMImageIO.h"
#include "itkGDCMImageIOFactory.h"
#include "itkGDCMSeriesFileNames.h"
#if __has_include("itkDCMTKImageIO.h")
#include "itkDCMTKImageIO.h"
#define ITKBRIDGE_HAS_DCMTK 1
#else
#define ITKBRIDGE_HAS_DCMTK 0
#endif
#if __has_include("itkDCMTKImageIOFactory.h")
#include "itkDCMTKImageIOFactory.h"
#define ITKBRIDGE_HAS_DCMTK_FACTORY 1
#else
#define ITKBRIDGE_HAS_DCMTK_FACTORY 0
#endif
#include "itkImageIOBase.h"
#include "itkMetaDataObject.h"
#include "itkNiftiImageIO.h"
#include "itkNiftiImageIOFactory.h"
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

bool hasSuffix(const std::string &value, const std::string &suffix) {
    if (suffix.size() > value.size()) {
        return false;
    }
    return std::equal(suffix.rbegin(), suffix.rend(), value.rbegin());
}

bool isNiftiPath(const char *path) {
    if (!path) {
        return false;
    }
    std::string lower(path);
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return hasSuffix(lower, ".nii") || hasSuffix(lower, ".nii.gz");
}

bool isDicomPath(const char *path) {
    if (!path) {
        return false;
    }
    std::string lower(path);
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return hasSuffix(lower, ".dcm");
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

std::string normalizeTagKey(const std::string &key) {
    std::string normalized = key;
    std::replace(normalized.begin(), normalized.end(), '|', ',');
    return normalized;
}

bool parseDICOMDoubleArray(const std::string &raw,
                           std::vector<double> &out,
                           size_t expectedCount) {
    out.clear();
    std::string cleaned = raw;
    std::replace(cleaned.begin(), cleaned.end(), ',', '\\');
    std::istringstream stream(cleaned);
    std::string token;
    while (std::getline(stream, token, '\\')) {
        if (token.empty()) { continue; }
        std::istringstream valueStream(token);
        double value = 0.0;
        valueStream >> value;
        if (valueStream.fail()) {
            out.clear();
            return false;
        }
        out.push_back(value);
    }
    if (out.size() < expectedCount) {
        out.clear();
        return false;
    }
    if (expectedCount > 0 && out.size() > expectedCount) {
        out.resize(expectedCount);
    }
    return true;
}

bool parseDICOMDoubleList(const std::string &raw,
                          std::vector<double> &out) {
    out.clear();
    std::string cleaned = raw;
    std::replace(cleaned.begin(), cleaned.end(), ',', '\\');
    std::istringstream stream(cleaned);
    std::string token;
    while (std::getline(stream, token, '\\')) {
        if (token.empty()) { continue; }
        std::istringstream valueStream(token);
        double value = 0.0;
        valueStream >> value;
        if (valueStream.fail()) {
            out.clear();
            return false;
        }
        out.push_back(value);
    }
    return !out.empty();
}

bool extractDicomScalar(const itk::MetaDataDictionary &dict,
                        const std::string &tag,
                        double &out) {
    std::string raw;
    if (!itk::ExposeMetaData<std::string>(dict, tag, raw)) {
        return false;
    }
    std::vector<double> values;
    if (!parseDICOMDoubleArray(raw, values, 1)) {
        return false;
    }
    out = values.front();
    return true;
}

bool extractDicomVector(const itk::MetaDataDictionary &dict,
                        const std::string &tag,
                        size_t expectedCount,
                        std::vector<double> &out) {
    std::string raw;
    if (!itk::ExposeMetaData<std::string>(dict, tag, raw)) {
        return false;
    }
    return parseDICOMDoubleArray(raw, out, expectedCount);
}

bool extractDicomVectorAny(const itk::MetaDataDictionary &dict,
                           const std::string &tag,
                           std::vector<double> &out) {
    std::string raw;
    if (!itk::ExposeMetaData<std::string>(dict, tag, raw)) {
        return false;
    }
    return parseDICOMDoubleList(raw, out);
}

std::string jsonNumber(double value) {
    std::ostringstream stream;
    stream.setf(std::ios::fixed);
    stream << std::setprecision(17) << value;
    return stream.str();
}

std::string metadataDictionaryToJSON(
    const itk::MetaDataDictionary &dict,
    const std::map<std::string, std::vector<double>> &numericOverrides = {},
    const std::map<std::string, double> &scalarOverrides = {},
    const std::map<std::string, bool> &boolOverrides = {}
) {
    std::string json = "{";
    bool first = true;

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

    registerDicomIOFactories();
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

    const auto *dictArray = reader->GetMetaDataDictionaryArray();
    std::map<std::string, std::vector<double>> numericOverrides;
    std::map<std::string, double> scalarOverrides;
    std::map<std::string, bool> boolOverrides;

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
        if (firstDict && extractDicomScalar(*firstDict, "0028|0008", scalarValue)) {
            scalarOverrides["0028,0008"] = scalarValue;
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

        if ((hasIOP || hasIPP) && dictArray->size() > 1) {
            bool consistent = true;
            const double epsilon = 1e-4;
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
            for (size_t i = 0; i < dictArray->size(); ++i) {
                const auto *dict = dictArray->at(i);
                if (!dict) {
                    consistent = false;
                    break;
                }
                if (hasIOP) {
                    std::vector<double> currentIOP;
                    if (!extractDicomVector(*dict, "0020|0037", 6, currentIOP)) {
                        consistent = false;
                        break;
                    }
                    for (size_t j = 0; j < currentIOP.size(); ++j) {
                        if (std::abs(currentIOP[j] - iop[j]) > epsilon) {
                            consistent = false;
                            break;
                        }
                    }
                }
                if (!consistent) { break; }
                if (hasIPP) {
                    std::vector<double> currentIPP;
                    if (!extractDicomVector(*dict, "0020|0032", 3, currentIPP)) {
                        consistent = false;
                        break;
                    }
                    for (size_t j = 0; j < currentIPP.size(); ++j) {
                        if (std::abs(currentIPP[j] - ipp[j]) > epsilon) {
                            consistent = false;
                            break;
                        }
                    }
                }
                if (!consistent) { break; }

                if (hasRows) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0010", current) || std::abs(current - firstRows) > epsilon) {
                        pixelDataConsistent = false;
                    }
                }
                if (hasColumns) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0011", current) || std::abs(current - firstColumns) > epsilon) {
                        pixelDataConsistent = false;
                    }
                }
                if (hasBitsAllocated) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0100", current) || std::abs(current - firstBitsAllocated) > epsilon) {
                        pixelDataConsistent = false;
                    }
                }
                if (hasBitsStored) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0101", current) || std::abs(current - firstBitsStored) > epsilon) {
                        pixelDataConsistent = false;
                    }
                }
                if (hasPixelRep) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0028|0103", current) || std::abs(current - firstPixelRep) > epsilon) {
                        pixelDataConsistent = false;
                    }
                }

                if (hasPixelSpacing) {
                    std::vector<double> currentSpacing;
                    if (!extractDicomVector(*dict, "0028|0030", 2, currentSpacing)) {
                        geometryConsistent = false;
                    } else {
                        for (size_t j = 0; j < currentSpacing.size(); ++j) {
                            if (std::abs(currentSpacing[j] - firstPixelSpacing[j]) > epsilon) {
                                geometryConsistent = false;
                                break;
                            }
                        }
                    }
                }
                if (hasSliceThickness) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0018|0050", current) || std::abs(current - firstSliceThickness) > epsilon) {
                        geometryConsistent = false;
                    }
                }
                if (hasSpacingBetween) {
                    double current = 0.0;
                    if (!extractDicomScalar(*dict, "0018|0088", current) || std::abs(current - firstSpacingBetween) > epsilon) {
                        geometryConsistent = false;
                    }
                }
            }
            boolOverrides["_orientationConsistent"] = consistent;
            boolOverrides["_pixelDataConsistent"] = pixelDataConsistent;
            boolOverrides["_geometryConsistent"] = geometryConsistent;
        }
    }

    VolumeLoadResult result;
    result.image = reader->GetOutput();
    result.metadataJSON = metadataDictionaryToJSON(
        reader->GetImageIO()->GetMetaDataDictionary(),
        numericOverrides,
        scalarOverrides,
        boolOverrides
    );
    return result;
}

// Load a 3D float volume from a single volume file (NIfTI, NRRD, etc).
VolumeLoadResult loadSingleFileVolume(const char *filePath) {
    using ReaderType = itk::ImageFileReader<Float3DImage>;
    ReaderType::Pointer reader = ReaderType::New();
    if (isNiftiPath(filePath)) {
        static bool niftiFactoryRegistered = false;
        if (!niftiFactoryRegistered) {
            itk::NiftiImageIOFactory::RegisterOneFactory();
            niftiFactoryRegistered = true;
        }
        reader->SetImageIO(itk::NiftiImageIO::New());
    }
    reader->SetFileName(std::string(filePath));
    reader->Update();
    VolumeLoadResult result;
    result.image = reader->GetOutput();
    result.metadataJSON = metadataDictionaryToJSON(reader->GetImageIO()->GetMetaDataDictionary());
    return result;
}

VolumeLoadResult loadDicomFile(const char *filePath,
                               ITKDicomBackendC backend) {
    using ReaderType = itk::ImageFileReader<Float3DImage>;
    ReaderType::Pointer reader = ReaderType::New();
    registerDicomIOFactories();
    reader->SetImageIO(makeDicomIO(backend));
    reader->SetFileName(std::string(filePath));
    reader->Update();

    std::map<std::string, std::vector<double>> numericOverrides;
    std::map<std::string, double> scalarOverrides;
    std::vector<double> iop;
    std::vector<double> ipp;
    const auto &dict = reader->GetImageIO()->GetMetaDataDictionary();
    if (extractDicomVector(dict, "0020|0037", 6, iop)) {
        numericOverrides["0020,0037"] = iop;
    }
    if (extractDicomVector(dict, "0020|0032", 3, ipp)) {
        numericOverrides["0020,0032"] = ipp;
    }
    std::vector<double> pixelSpacing;
    if (extractDicomVector(dict, "0028|0030", 2, pixelSpacing)) {
        numericOverrides["0028,0030"] = pixelSpacing;
    }
    std::vector<double> windowCenter;
    if (extractDicomVectorAny(dict, "0028|1050", windowCenter)) {
        numericOverrides["0028,1050"] = windowCenter;
    }
    std::vector<double> windowWidth;
    if (extractDicomVectorAny(dict, "0028|1051", windowWidth)) {
        numericOverrides["0028,1051"] = windowWidth;
    }

    double scalarValue = 0.0;
    if (extractDicomScalar(dict, "0018|0050", scalarValue)) {
        scalarOverrides["0018,0050"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0018|0088", scalarValue)) {
        scalarOverrides["0018,0088"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0010", scalarValue)) {
        scalarOverrides["0028,0010"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0011", scalarValue)) {
        scalarOverrides["0028,0011"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0100", scalarValue)) {
        scalarOverrides["0028,0100"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0101", scalarValue)) {
        scalarOverrides["0028,0101"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0102", scalarValue)) {
        scalarOverrides["0028,0102"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0103", scalarValue)) {
        scalarOverrides["0028,0103"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|1052", scalarValue)) {
        scalarOverrides["0028,1052"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|1053", scalarValue)) {
        scalarOverrides["0028,1053"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0008", scalarValue)) {
        scalarOverrides["0028,0008"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0020|1209", scalarValue)) {
        scalarOverrides["0020,1209"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0020|0011", scalarValue)) {
        scalarOverrides["0020,0011"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0020|0013", scalarValue)) {
        scalarOverrides["0020,0013"] = scalarValue;
    }

    VolumeLoadResult result;
    result.image = reader->GetOutput();
    result.metadataJSON = metadataDictionaryToJSON(
        reader->GetImageIO()->GetMetaDataDictionary(),
        numericOverrides,
        scalarOverrides,
        {}
    );
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
                       "ITKLoadDicomFileWithBackend: failed to allocate voxel buffer");
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
                   "ITKLoadDicomFileWithBackend: unknown exception");
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
