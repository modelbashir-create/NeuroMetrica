#include "GeometryValidation.h"

#include <algorithm>
#include <cmath>
#include <limits>

#include "DicomTagExtractors.h"

GeometryValidationResult validateGeometryFromDictionaries(
    const std::vector<std::string> &fileNames,
    const std::vector<itk::MetaDataDictionary> &dictionaries,
    const itk::ImageBase<3>::Pointer &image,
    double orientationEpsilon,
    double spacingEpsilon,
    const std::vector<std::string> &missingGeometryTags) {
    GeometryValidationResult result;
    result.usedDefaults = !missingGeometryTags.empty();

    std::vector<double> positions;
    bool canComputePositions = false;
    bool usedSliceLocation = false;

    if (fileNames.size() >= 2 && dictionaries.size() == fileNames.size()) {
        const auto &firstDict = dictionaries.front();

        std::vector<double> iop;
        std::vector<double> ipp;
        bool hasIOP = extractDicomVector(firstDict, "0020|0037", 6, iop);
        bool hasIPP = extractDicomVector(firstDict, "0020|0032", 3, ipp);

        if (hasIOP && hasIPP) {
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
            if (norm > 0.0) {
                scanAxis[0] /= norm;
                scanAxis[1] /= norm;
                scanAxis[2] /= norm;
                positions.reserve(dictionaries.size());
                bool orientationConsistent = true;
                for (size_t i = 0; i < dictionaries.size(); ++i) {
                    const auto &dict = dictionaries[i];
                    std::vector<double> currentIOP;
                    std::vector<double> currentIPP;
                    if (!extractDicomVector(dict, "0020|0037", 6, currentIOP) ||
                        !extractDicomVector(dict, "0020|0032", 3, currentIPP)) {
                        orientationConsistent = false;
                        break;
                    }
                    for (size_t j = 0; j < currentIOP.size(); ++j) {
                        if (std::abs(currentIOP[j] - iop[j]) > orientationEpsilon) {
                            orientationConsistent = false;
                            break;
                        }
                    }
                    if (!orientationConsistent) {
                        break;
                    }
                    const double dx = currentIPP[0] - ipp[0];
                    const double dy = currentIPP[1] - ipp[1];
                    const double dz = currentIPP[2] - ipp[2];
                    positions.push_back(dx * scanAxis[0] + dy * scanAxis[1] + dz * scanAxis[2]);
                }
                if (orientationConsistent && positions.size() == dictionaries.size()) {
                    canComputePositions = true;
                }
            }
        }

        if (!canComputePositions) {
            positions.clear();
            positions.reserve(dictionaries.size());
            bool hasAllSliceLocations = true;
            for (size_t i = 0; i < dictionaries.size(); ++i) {
                const auto &dict = dictionaries[i];
                double sliceLocation = 0.0;
                if (!extractDicomScalar(dict, "0020|1041", sliceLocation)) {
                    hasAllSliceLocations = false;
                    break;
                }
                positions.push_back(sliceLocation);
            }
            if (hasAllSliceLocations && positions.size() == dictionaries.size()) {
                canComputePositions = true;
                usedSliceLocation = true;
            }
        }
    }

    if (canComputePositions && positions.size() >= 2) {
        const double zeroEpsilon = 1e-6;
        double direction = 0.0;
        bool inconsistent = false;
        std::vector<double> deltas;
        deltas.reserve(positions.size() - 1);
        for (size_t i = 1; i < positions.size(); ++i) {
            const double delta = positions[i] - positions[i - 1];
            deltas.push_back(delta);
            if (std::abs(delta) <= zeroEpsilon) {
                inconsistent = true;
                continue;
            }
            if (direction == 0.0) {
                direction = (delta > 0.0) ? 1.0 : -1.0;
            } else if ((delta > 0.0 && direction < 0.0) || (delta < 0.0 && direction > 0.0)) {
                inconsistent = true;
            }
        }

        if (inconsistent || direction == 0.0) {
            result.sliceOrder = "inconsistent";
        } else if (direction < 0.0) {
            result.sliceOrder = "reversed";
        } else {
            result.sliceOrder = "monotonic";
        }

        double minSpacing = std::numeric_limits<double>::max();
        double maxSpacing = 0.0;
        for (double delta : deltas) {
            const double spacing = std::abs(delta);
            minSpacing = std::min(minSpacing, spacing);
            maxSpacing = std::max(maxSpacing, spacing);
        }
        result.spacingMin = (minSpacing == std::numeric_limits<double>::max()) ? 0.0 : minSpacing;
        result.spacingMax = maxSpacing;
        result.spacingUniform = (maxSpacing - result.spacingMin) <= spacingEpsilon;
    } else if (canComputePositions && positions.size() == 1) {
        result.sliceOrder = "monotonic";
        result.spacingUniform = true;
        result.spacingMin = 0.0;
        result.spacingMax = 0.0;
    }

    if (image) {
        const auto direction = image->GetDirection();
        const double x[3] = {direction[0][0], direction[1][0], direction[2][0]};
        const double y[3] = {direction[0][1], direction[1][1], direction[2][1]};
        const double z[3] = {direction[0][2], direction[1][2], direction[2][2]};
        const double xNorm = std::sqrt(x[0] * x[0] + x[1] * x[1] + x[2] * x[2]);
        const double yNorm = std::sqrt(y[0] * y[0] + y[1] * y[1] + y[2] * y[2]);
        const double zNorm = std::sqrt(z[0] * z[0] + z[1] * z[1] + z[2] * z[2]);
        const double xy = std::abs(x[0] * y[0] + x[1] * y[1] + x[2] * y[2]);
        const double xz = std::abs(x[0] * z[0] + x[1] * z[1] + x[2] * z[2]);
        const double yz = std::abs(y[0] * z[0] + y[1] * z[1] + y[2] * z[2]);
        const double orthoEpsilon = 1e-3;
        result.directionOrthonormal = std::abs(xNorm - 1.0) <= orthoEpsilon &&
            std::abs(yNorm - 1.0) <= orthoEpsilon &&
            std::abs(zNorm - 1.0) <= orthoEpsilon &&
            xy <= orthoEpsilon && xz <= orthoEpsilon && yz <= orthoEpsilon;

        result.directionDeterminant = direction[0][0] * (direction[1][1] * direction[2][2] - direction[1][2] * direction[2][1]) -
            direction[0][1] * (direction[1][0] * direction[2][2] - direction[1][2] * direction[2][0]) +
            direction[0][2] * (direction[1][0] * direction[2][1] - direction[1][1] * direction[2][0]);
        result.leftHanded = result.directionDeterminant < 0.0;
    }

    if (usedSliceLocation) {
        result.usedDefaults = true;
    }

    bool ok = true;
    if (result.sliceOrder == "inconsistent") {
        ok = false;
    }
    if (!result.spacingUniform) {
        ok = false;
    }
    if (!result.directionOrthonormal || std::abs(result.directionDeterminant) < 1e-6) {
        ok = false;
    }
    if (result.usedDefaults) {
        ok = false;
    }
    result.validationStatus = ok ? "ok" : "warning";
    return result;
}

