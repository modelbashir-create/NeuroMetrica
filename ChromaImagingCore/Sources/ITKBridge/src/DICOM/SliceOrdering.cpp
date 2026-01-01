#include "SliceOrdering.h"

#include <algorithm>
#include <cmath>

#include "DicomTagExtractors.h"

SliceOrderingResult computeSliceOrderingFromDictionaries(
    const std::vector<std::string> &fileNames,
    const std::vector<itk::MetaDataDictionary> &dictionaries,
    double orientationEpsilon) {
    SliceOrderingResult result;
    if (fileNames.empty() || dictionaries.size() != fileNames.size()) {
        return result;
    }

    auto orderByFileIndex = [&](size_t count) {
        SliceOrderingResult fallback;
        fallback.canOrder = true;
        fallback.orientationConsistent = false;
        fallback.method = "file_index";
        fallback.order.resize(count);
        for (size_t i = 0; i < count; ++i) {
            fallback.order[i] = i;
        }
        return fallback;
    };

    auto orderBySliceLocation = [&](const std::vector<itk::MetaDataDictionary> &dicts) {
        std::vector<std::pair<size_t, double>> sortList;
        sortList.reserve(dicts.size());
        for (size_t i = 0; i < dicts.size(); ++i) {
            const auto &dict = dicts[i];
            double sliceLocation = 0.0;
            if (!extractDicomScalar(dict, "0020|1041", sliceLocation)) {
                return orderByFileIndex(dicts.size());
            }
            sortList.emplace_back(i, sliceLocation);
        }
        std::sort(sortList.begin(), sortList.end(), [](const auto &a, const auto &b) {
            if (a.second == b.second) {
                return a.first < b.first;
            }
            return a.second < b.second;
        });
        SliceOrderingResult fallback;
        fallback.canOrder = true;
        fallback.orientationConsistent = false;
        fallback.method = "slice_location";
        fallback.order.reserve(sortList.size());
        for (const auto &entry : sortList) {
            fallback.order.push_back(entry.first);
        }
        return fallback;
    };

    const auto &firstDict = dictionaries.front();

    std::vector<double> iop;
    std::vector<double> ipp;
    if (!extractDicomVector(firstDict, "0020|0037", 6, iop) ||
        !extractDicomVector(firstDict, "0020|0032", 3, ipp)) {
        return orderBySliceLocation(dictionaries);
    }

    const double row[3] = {iop[0], iop[1], iop[2]};
    const double col[3] = {iop[3], iop[4], iop[5]};
    double scanAxis[3] = {
        row[1] * col[2] - row[2] * col[1],
        row[2] * col[0] - row[0] * col[2],
        row[0] * col[1] - row[1] * col[0]
    };
    const double norm = std::sqrt(scanAxis[0] * scanAxis[0] +
                                  scanAxis[1] * scanAxis[1] +
                                  scanAxis[2] * scanAxis[2]);
    if (norm == 0.0) {
        return orderBySliceLocation(dictionaries);
    }
    scanAxis[0] /= norm;
    scanAxis[1] /= norm;
    scanAxis[2] /= norm;

    std::vector<std::pair<size_t, double>> sortList;
    sortList.reserve(dictionaries.size());

    for (size_t i = 0; i < dictionaries.size(); ++i) {
        const auto &dict = dictionaries[i];

        std::vector<double> currentIOP;
        std::vector<double> currentIPP;
        if (!extractDicomVector(dict, "0020|0037", 6, currentIOP) ||
            !extractDicomVector(dict, "0020|0032", 3, currentIPP)) {
            return orderBySliceLocation(dictionaries);
        }

        for (size_t j = 0; j < currentIOP.size(); ++j) {
            if (std::abs(currentIOP[j] - iop[j]) > orientationEpsilon) {
                return orderBySliceLocation(dictionaries);
            }
        }

        const double dx = currentIPP[0] - ipp[0];
        const double dy = currentIPP[1] - ipp[1];
        const double dz = currentIPP[2] - ipp[2];
        const double dist = dx * scanAxis[0] + dy * scanAxis[1] + dz * scanAxis[2];
        sortList.emplace_back(i, dist);
    }

    std::sort(sortList.begin(), sortList.end(), [](const auto &a, const auto &b) {
        return a.second < b.second;
    });

    result.order.reserve(sortList.size());
    result.distances.reserve(sortList.size());
    for (const auto &entry : sortList) {
        result.order.push_back(entry.first);
        result.distances.push_back(entry.second);
    }

    result.canOrder = true;
    result.method = "ipp_iop";
    return result;
}

bool isMultiFrameSeries(const std::vector<itk::MetaDataDictionary> &dictionaries) {
    if (dictionaries.empty()) {
        return false;
    }

    const auto &dict = dictionaries.front();
    double frames = 0.0;
    if (extractDicomScalar(dict, "0028|0008", frames)) {
        return frames > 1.0;
    }
    return false;
}

