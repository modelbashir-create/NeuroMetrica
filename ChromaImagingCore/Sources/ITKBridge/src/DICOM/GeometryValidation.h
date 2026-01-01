#pragma once

#include <string>
#include <vector>

#include "itkImageBase.h"
#include "itkMetaDataDictionary.h"

struct GeometryValidationResult {
    std::string sliceOrder = "incomplete";
    bool spacingUniform = false;
    double spacingMin = 0.0;
    double spacingMax = 0.0;
    bool directionOrthonormal = false;
    double directionDeterminant = 0.0;
    bool leftHanded = false;
    bool usedDefaults = false;
    std::string validationStatus = "warning";
};

GeometryValidationResult validateGeometryFromDictionaries(
    const std::vector<std::string> &fileNames,
    const std::vector<itk::MetaDataDictionary> &dictionaries,
    const itk::ImageBase<3>::Pointer &image,
    double orientationEpsilon,
    double spacingEpsilon,
    const std::vector<std::string> &missingGeometryTags);

