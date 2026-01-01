#pragma once

#include <string>
#include <vector>

#include "itkMetaDataDictionary.h"

std::string buildSliceProvenanceJSON(const std::vector<itk::MetaDataDictionary> &dictionaries);

