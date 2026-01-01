#include "SingleFileLoader.h"

#include "itkImageFileReader.h"
#include "itkNiftiImageIO.h"
#include "itkNiftiImageIOFactory.h"

#include "../Utils/ITKBridgeUtils.h"
#include "../DICOM/DicomTagExtractors.h"

VolumeLoadResult loadSingleFileVolume(const char *filePath) {
    using ReaderType = itk::ImageFileReader<Float3DImage>;
    ReaderType::Pointer reader = ReaderType::New();
    if (isNiftiPath(filePath)) {
        static bool niftiFactoryRegistered = false;
        if (!niftiFactoryRegistered) {
            itk::NiftiImageIOFactory::RegisterOneFactory();
            niftiFactoryRegistered = true;
        }
        reader->SetImageIO(itk::NiftiImageIO::New());
    }
    reader->SetFileName(std::string(filePath));
    reader->Update();

    MetadataContext metadata;
    metadata.baseDictionary = reader->GetImageIO()->GetMetaDataDictionary();

    VolumeLoadResult result;
    result.image = reader->GetOutput();
    result.metadata = metadata;
    return result;
}

VolumeLoadResult loadDicomFile(const char *filePath,
                               ITKDicomBackendC backend) {
    using ReaderType = itk::ImageFileReader<Float3DImage>;
    ReaderType::Pointer reader = ReaderType::New();
    registerDicomIOFactories();
    reader->SetImageIO(makeDicomIO(backend));
    reader->SetFileName(std::string(filePath));
    reader->Update();

    MetadataContext metadata;
    metadata.baseDictionary = reader->GetImageIO()->GetMetaDataDictionary();

    auto &numericOverrides = metadata.overrides.numericOverrides;
    auto &scalarOverrides = metadata.overrides.scalarOverrides;
    auto &boolOverrides = metadata.overrides.boolOverrides;

    std::vector<double> iop;
    std::vector<double> ipp;
    const auto &dict = reader->GetImageIO()->GetMetaDataDictionary();
    if (extractDicomVector(dict, "0020|0037", 6, iop)) {
        numericOverrides["0020,0037"] = iop;
    }
    if (extractDicomVector(dict, "0020|0032", 3, ipp)) {
        numericOverrides["0020,0032"] = ipp;
    }
    std::vector<double> pixelSpacing;
    if (extractDicomVector(dict, "0028|0030", 2, pixelSpacing)) {
        numericOverrides["0028,0030"] = pixelSpacing;
    }
    std::vector<double> windowCenter;
    if (extractDicomVectorAny(dict, "0028|1050", windowCenter)) {
        numericOverrides["0028,1050"] = windowCenter;
    }
    std::vector<double> windowWidth;
    if (extractDicomVectorAny(dict, "0028|1051", windowWidth)) {
        numericOverrides["0028,1051"] = windowWidth;
    }

    double scalarValue = 0.0;
    bool isMultiFrame = false;
    if (extractDicomScalar(dict, "0018|0050", scalarValue)) {
        scalarOverrides["0018,0050"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0018|0088", scalarValue)) {
        scalarOverrides["0018,0088"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0010", scalarValue)) {
        scalarOverrides["0028,0010"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0011", scalarValue)) {
        scalarOverrides["0028,0011"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0100", scalarValue)) {
        scalarOverrides["0028,0100"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0101", scalarValue)) {
        scalarOverrides["0028,0101"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0102", scalarValue)) {
        scalarOverrides["0028,0102"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0103", scalarValue)) {
        scalarOverrides["0028,0103"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|1052", scalarValue)) {
        scalarOverrides["0028,1052"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|1053", scalarValue)) {
        scalarOverrides["0028,1053"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0028|0008", scalarValue)) {
        scalarOverrides["0028,0008"] = scalarValue;
        if (scalarValue > 1.0) {
            isMultiFrame = true;
        }
    }
    if (extractDicomScalar(dict, "0020|1209", scalarValue)) {
        scalarOverrides["0020,1209"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0020|0011", scalarValue)) {
        scalarOverrides["0020,0011"] = scalarValue;
    }
    if (extractDicomScalar(dict, "0020|0013", scalarValue)) {
        scalarOverrides["0020,0013"] = scalarValue;
    }

    const auto &dir = reader->GetOutput()->GetDirection();
    double det = dir(0, 0) * (dir(1, 1) * dir(2, 2) - dir(1, 2) * dir(2, 1)) -
        dir(0, 1) * (dir(1, 0) * dir(2, 2) - dir(1, 2) * dir(2, 0)) +
        dir(0, 2) * (dir(1, 0) * dir(2, 1) - dir(1, 1) * dir(2, 0));
    boolOverrides["_leftHanded"] = (det < 0.0);

    metadata.sliceDictionaries.push_back(dict);
    metadata.hasDicomMetadata = true;
    metadata.dicomMetadata.hasSeriesDiagnostics = false;
    metadata.dicomMetadata.hasGeometryValidation = false;

    if (isMultiFrame) {
        boolOverrides["_multiFrame"] = true;
        metadata.dicomMetadata.isMultiFrame = true;
        metadata.dicomMetadata.multiFrameWarning =
            "Multi-frame image detected. If slice orientation or spacing is non-uniform then the image may be displayed incorrectly. Use with caution.";
    }

    VolumeLoadResult result;
    result.image = reader->GetOutput();
    result.metadata = metadata;
    return result;
}
