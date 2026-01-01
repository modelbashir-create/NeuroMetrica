# ChromaImagingCore

## Overview
ChromaImagingCore is the NeuroMetrica workspace’s foundational medical imaging I/O package for Apple platforms. It provides deterministic ITK-backed loading and metadata capture for clinical image data, producing a canonical in-memory volume representation that higher-level engines can rely on without exposing ObjC++ or ITK details to Swift callers.

## Design Goals
- Deterministic image loading
- Canonical in-memory volume representation
- Clear separation between I/O, metadata, and higher-level processing
- Medical-grade traceability and auditability

## Package Scope
What this package does:
- Loads medical image volumes (DICOM series and single-file volumes) via ITKBridge
- Normalizes and exposes imaging metadata produced by ITK
- Provides a canonical, strongly-typed volume model for downstream engines

What this package does not do:
- UI, visualization, or rendering
- Window/level computation or presentation logic
- GPU/Metal processing
- Machine learning or inference

## High-Level Architecture
- Public/
  - Entry point and public-facing protocol for image I/O.
- Models/
  - Canonical volume and scalar type definitions used across the engine stack.
- Errors/
  - Typed error surface for image I/O failures and validation.
- ITK/
  - Swift-facing I/O layer that wraps ITKBridge and produces strongly-typed descriptors.
- Utils/
  - Generic support utilities (non-medical semantics).

ITKBridge provides the ObjC++ boundary to ITK and DICOM parsing. ChromaImagingCore consumes its descriptors through Swift APIs, ensuring ObjC++ and ITK remain encapsulated and do not surface in application code.

## Package Tree
```
ChromaImagingCore/
├─ Package.swift
├─ README.md
├─ Sources/
│  ├─ ChromaImagingCore/
│  │  ├─ Public/
│  │  │  └─ ChromaImagingCore.swift
│  │  ├─ Models/
│  │  │  ├─ NMScalarType.swift
│  │  │  └─ NMVolume.swift
│  │  ├─ Errors/
│  │  │  └─ ImageIOErrors.swift
│  │  ├─ ITK/
│  │  │  ├─ ITKImageIO.swift
│  │  │  ├─ ITKInfo.swift
│  │  │  └─ ITKDescriptors.swift
│  └─ ITKBridge/
│     ├─ include/
│     │  └─ ITKBridge.h
│     └─ src/
│        ├─ Core/
│        │  ├─ ITKBridgePublicAPI.mm
│        │  └─ ITKBridgeInternal.h
│        ├─ Loaders/
│        │  ├─ DicomSeriesLoader.cpp
│        │  ├─ DicomSeriesLoader.h
│        │  ├─ SingleFileLoader.cpp
│        │  └─ SingleFileLoader.h
│        ├─ DICOM/
│        │  ├─ DicomTagExtractors.cpp
│        │  ├─ DicomTagExtractors.h
│        │  ├─ SeriesGrouping.cpp
│        │  ├─ SeriesGrouping.h
│        │  ├─ SliceOrdering.cpp
│        │  ├─ SliceOrdering.h
│        │  ├─ GeometryValidation.cpp
│        │  └─ GeometryValidation.h
│        ├─ Diagnostics/
│        │  ├─ SeriesDiagnostics.cpp
│        │  ├─ SeriesDiagnostics.h
│        │  ├─ SliceProvenance.cpp
│        │  └─ SliceProvenance.h
│        ├─ Descriptor/
│        │  ├─ DescriptorBuilder.cpp
│        │  └─ DescriptorBuilder.h
│        └─ Utils/
│           ├─ FileUtils.cpp
│           ├─ FileUtils.h
│           ├─ ITKBridgeUtils.cpp
│           ├─ ITKBridgeUtils.h
│           ├─ JSONUtils.cpp
│           ├─ JSONUtils.h
│           ├─ StringUtils.cpp
│           └─ StringUtils.h
└─ Tests/
   └─ ImagingCoreTests/
      ├─ ImagingCoreTests.swift
      └─ ITKinfoTests.swift
└─ ThirdParty/
   └─ ITK/
      └─ ITK.xcframework/
         ├─ Info.plist
         ├─ ios-arm64/
         ├─ ios-arm64-simulator/
         ├─ macos-arm64/
         ├─ xros-arm64/
         └─ xros-arm64-simulator/
```

## Data Model
- NMVolume is the canonical in-memory representation of a volume, including dimensions, spacing, origin, direction, scalar type, and raw voxel data.
- NMScalarType defines the scalar typing for voxel buffers and enables consistent size calculations.
- Descriptor-based loading ensures volume buffers and metadata are captured consistently from ITK, preserving correctness and auditability.

The model is designed for correctness and stable interpretation; downstream engines treat the volume representation as authoritative.

## Error Handling
ChromaImagingCore uses typed error models to report invalid inputs, load failures, and format mismatches. The package favors explicit error reporting over silent fallbacks, preserving auditability and deterministic behavior.

## Threading & Performance
This package is compute-oriented and UI-agnostic. It performs no rendering and makes no assumptions about scheduling, allowing higher layers to control threading and execution policy.

## Intended Usage
ChromaImagingCore is consumed by higher-level engine modules such as ChromaEngineKit, which perform CPU/GPU processing and rendering.

Illustrative (non-executable) example:
```swift
import ChromaImagingCore

let io: NMImageIO = ITKImageIO()
let volume = try await io.loadVolume(from: [dicomFolderURL])
// Use `volume` in higher-level processing.
```

## Stability & Change Policy
Public APIs are intentionally conservative. Internal refactors focus on structure and auditability and do not change runtime behavior or metadata outputs.

## Regulatory Note
ChromaImagingCore is infrastructure intended to support medical imaging workflows. It is not a diagnostic product and does not provide clinical interpretation.

## License / Third-Party
This package depends on ITK (Insight Toolkit) for medical image I/O.
