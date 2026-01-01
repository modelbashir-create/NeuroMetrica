#pragma once

#include <string>
#include <vector>

#include "itkMetaDataDictionary.h"

struct SliceOrderingResult {
    bool canOrder = false;
    bool orientationConsistent = true;
    std::vector<size_t> order;
    std::vector<double> distances;
    std::string method;
};

SliceOrderingResult computeSliceOrderingFromDictionaries(
    const std::vector<std::string> &fileNames,
    const std::vector<itk::MetaDataDictionary> &dictionaries,
    double orientationEpsilon);

bool isMultiFrameSeries(const std::vector<itk::MetaDataDictionary> &dictionaries);

