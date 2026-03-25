#include "DicomTagExtractors.h"

#include <algorithm>
#include <sstream>
#include <iomanip>

#include "itkMetaDataObject.h"

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

bool extractDicomVectorOptional(const itk::MetaDataDictionary &dict,
                                const std::string &tag,
                                size_t expectedCount,
                                std::vector<double> &out) {
    if (!extractDicomVector(dict, tag, expectedCount, out)) {
        out.clear();
        return false;
    }
    return true;
}

bool extractDicomString(const itk::MetaDataDictionary &dict,
                        const std::string &tag,
                        std::string &out) {
    std::string raw;
    if (!itk::ExposeMetaData<std::string>(dict, tag, raw)) {
        return false;
    }
    out = raw;
    return true;
}

std::string vectorKey(const std::vector<double> &values, int precision) {
    std::ostringstream stream;
    stream.setf(std::ios::fixed);
    stream << std::setprecision(precision);
    for (size_t i = 0; i < values.size(); ++i) {
        if (i > 0) { stream << ","; }
        stream << values[i];
    }
    return stream.str();
}
