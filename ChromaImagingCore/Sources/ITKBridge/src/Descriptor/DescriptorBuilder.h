#pragma once

#include <string>

#include "../Core/ITKBridgeInternal.h"

bool buildDescriptorFromResult(const VolumeLoadResult &result,
                               ITKImageDescriptorC *outDescriptor,
                               const char *context,
                               std::string *errorMessage);

// Descriptor memory helpers
void zeroDescriptor(ITKImageDescriptorC *desc);
void freeDescriptor(ITKImageDescriptorC *descriptor);
