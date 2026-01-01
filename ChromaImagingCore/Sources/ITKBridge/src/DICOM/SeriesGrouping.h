#pragma once

#include <string>
#include <vector>

#include "itkMetaDataDictionary.h"

struct SeriesCandidateRecord {
    std::string candidateId;
    size_t sliceCount = 0;
    std::vector<std::string> groupingKeys;
    std::string orderingMethod;
    std::string rejectionReason;
};

struct GroupingResult {
    std::string selectedKey;
    std::vector<size_t> selectedIndices;
    std::vector<std::string> keysUsed;
    std::vector<SeriesCandidateRecord> candidates;
    std::string selectionReason;
    size_t selectedSliceCount = 0;
};

GroupingResult groupFilesByTags(
    const std::vector<std::string> &fileNames,
    const std::vector<itk::MetaDataDictionary> &dictionaries);

