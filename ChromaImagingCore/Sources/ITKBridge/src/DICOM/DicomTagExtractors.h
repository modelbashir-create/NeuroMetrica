#pragma once

#include <string>
#include <vector>

#include "itkMetaDataDictionary.h"

bool extractDicomScalar(const itk::MetaDataDictionary &dict,
                        const std::string &tag,
                        double &out);

bool extractDicomVector(const itk::MetaDataDictionary &dict,
                        const std::string &tag,
                        size_t expectedCount,
                        std::vector<double> &out);

bool extractDicomVectorAny(const itk::MetaDataDictionary &dict,
                           const std::string &tag,
                           std::vector<double> &out);

bool extractDicomVectorOptional(const itk::MetaDataDictionary &dict,
                                const std::string &tag,
                                size_t expectedCount,
                                std::vector<double> &out);

bool extractDicomString(const itk::MetaDataDictionary &dict,
                        const std::string &tag,
                        std::string &out);

std::string vectorKey(const std::vector<double> &values, int precision = 6);

bool parseDICOMDoubleArray(const std::string &raw,
                           std::vector<double> &out,
                           size_t expectedCount);

bool parseDICOMDoubleList(const std::string &raw,
                          std::vector<double> &out);
