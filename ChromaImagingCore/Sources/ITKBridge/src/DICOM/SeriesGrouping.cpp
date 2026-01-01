#include "SeriesGrouping.h"

#include <map>

#include "DicomTagExtractors.h"
#include "../Utils/ITKBridgeUtils.h"

GroupingResult groupFilesByTags(
    const std::vector<std::string> &fileNames,
    const std::vector<itk::MetaDataDictionary> &dictionaries) {
    GroupingResult result;
    if (fileNames.empty() || dictionaries.size() != fileNames.size()) {
        return result;
    }

    bool anyEcho = false;
    bool anyTrigger = false;
    bool anyIPP = false;
    bool anySliceLocation = false;

    for (size_t i = 0; i < dictionaries.size(); ++i) {
        const auto &dict = dictionaries[i];

        double echo = 0.0;
        bool hasEcho = extractDicomScalar(dict, "0018|0086", echo);
        double trigger = 0.0;
        bool hasTrigger = extractDicomScalar(dict, "0018|1060", trigger);
        std::vector<double> ipp;
        bool hasIPP = extractDicomVector(dict, "0020|0032", 3, ipp);
        double sliceLocation = 0.0;
        bool hasSliceLocation = extractDicomScalar(dict, "0020|1041", sliceLocation);

        anyEcho = anyEcho || hasEcho;
        anyTrigger = anyTrigger || hasTrigger;
        anyIPP = anyIPP || hasIPP;
        anySliceLocation = anySliceLocation || hasSliceLocation;
    }

    std::map<std::string, std::vector<size_t>> groups;
    for (size_t i = 0; i < dictionaries.size(); ++i) {
        const auto &dict = dictionaries[i];

        std::vector<double> iop;
        bool hasIOP = extractDicomVector(dict, "0020|0037", 6, iop);

        double echo = 0.0;
        bool hasEcho = extractDicomScalar(dict, "0018|0086", echo);
        double trigger = 0.0;
        bool hasTrigger = extractDicomScalar(dict, "0018|1060", trigger);

        std::vector<double> ipp;
        bool hasIPP = extractDicomVector(dict, "0020|0032", 3, ipp);
        double sliceLocation = 0.0;
        bool hasSliceLocation = extractDicomScalar(dict, "0020|1041", sliceLocation);

        std::string key = "iop=" + (hasIOP ? vectorKey(iop) : "nil");
        if (anyEcho) {
            key += "|echo=";
            key += hasEcho ? formatNumber(echo, 17) : "nil";
        }
        if (anyTrigger) {
            key += "|trigger=";
            key += hasTrigger ? formatNumber(trigger, 17) : "nil";
        }

        if (hasIPP) {
            key += "|spatial=ipp";
        } else if (hasSliceLocation) {
            key += "|spatial=slice_location";
        } else {
            key += "|spatial=none";
        }

        groups[key].push_back(i);
    }

    if (groups.empty()) {
        return result;
    }

    auto best = groups.begin();
    size_t bestSize = best->second.size();
    for (auto it = groups.begin(); it != groups.end(); ++it) {
        if (it->second.size() > bestSize) {
            best = it;
            bestSize = it->second.size();
        } else if (it->second.size() == bestSize && it->first < best->first) {
            best = it;
            bestSize = it->second.size();
        }
    }

    result.selectedKey = best->first;
    result.selectedIndices = best->second;
    result.selectedSliceCount = best->second.size();
    if (groups.size() == 1) {
        result.selectionReason = "single_group_default";
    } else {
        bool tie = false;
        for (const auto &entry : groups) {
            if (entry.first != best->first && entry.second.size() == bestSize) {
                tie = true;
                break;
            }
        }
        result.selectionReason = tie ? "tie_breaker_by_key" : "largest_group_by_slice_count";
    }

    result.keysUsed.push_back("0020|0037");
    if (anyIPP) {
        result.keysUsed.push_back("0020|0032");
    } else if (anySliceLocation) {
        result.keysUsed.push_back("0020|1041");
    }
    if (anyEcho) {
        result.keysUsed.push_back("0018|0086");
    }
    if (anyTrigger) {
        result.keysUsed.push_back("0018|1060");
    }

    for (const auto &entry : groups) {
        SeriesCandidateRecord candidate;
        candidate.candidateId = "group:" + entry.first;
        candidate.sliceCount = entry.second.size();
        candidate.groupingKeys = result.keysUsed;
        if (entry.first != result.selectedKey) {
            if (entry.first.find("spatial=none") != std::string::npos) {
                candidate.rejectionReason = "missing_geometry";
            } else if (entry.second.size() < result.selectedSliceCount) {
                candidate.rejectionReason = "smaller_stack";
            } else {
                candidate.rejectionReason = "tie_breaker_by_key";
            }
        }
        result.candidates.push_back(candidate);
    }
    return result;
}
