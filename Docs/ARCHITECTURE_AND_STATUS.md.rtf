{\rtf1\ansi\ansicpg1252\cocoartf2865
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 # NeuroMetrica / ChromaImagingKit \'97 Architecture & Status\
\
This document describes:\
\
- The **overall architecture** of the NeuroMetrica workspace  \
- The **directory and file layout** (including empty/scaffold files)  \
- For each major file or group:\
  - What is **implemented**\
  - What is **stub / placeholder**\
  - What is **planned** but not yet written  \
- The **design philosophy** behind the project  \
\
The goal is that any developer (or future ChatGPT session) can read this and immediately pick up where work stopped.\
\
---\
\
## 1. Workspace Overview\
\
The project is organized as an Xcode **workspace**:\
\
```text\
NeuroMetricaWorkspace/\
    NeuroMetrica.xcworkspace        # Workspace file\
    NeuroMetrica/                   # App project (SwiftUI / MVVM)\
    ChromaImagingKit/               # Swift package (image engine)\
    DCMTKLoader/                    # Swift package (DICOM loading)\
```\
\
### 1.1 NeuroMetrica (App Project)\
\
**Purpose**\
\
- A neurosurgical imaging viewer for CT/MRI and other volumetric data.  \
- Uses **MVVM** (Model\'96View\'96ViewModel) with SwiftUI.  \
- Delegates all heavy imaging work to `ChromaImagingKit`.  \
- Will delegate DICOM parsing to `DCMTKLoader` rather than bundling DICOM code directly in the app.\
\
**Current status (high level)**\
\
- Project builds after workspace + target cleanup.  \
- Viewer / model / viewmodel scaffolding exists (file names may vary slightly):\
\
  - `ViewerView.swift`  \
  - `ViewerViewModel.swift`  \
  - Core models / protocols for working with volumes and slices  \
\
- A previous local `DICOM/` folder (with `NeuroMetrica-Bridging-Header.h` and `DicomBridge.*`) was **removed from the app** and that responsibility moved to `DCMTKLoader`.\
\
**What\'92s next for NeuroMetrica**\
\
- Hook ChromaImagingKit\'92s volume + slice pipeline into `ViewerViewModel`:\
  - Load a `CIImageVolume`.  \
  - Extract axial/coronal/sagittal slices.  \
  - Apply window/level.  \
  - Convert to `CGImage` / SwiftUI `Image` for display.  \
- Add plane controls (AX/COR/SAG), slice sliders, WW/WL controls.  \
- Later: integrate `DCMTKLoader` to load real DICOM studies into `CIImageVolume`.\
\
---\
\
## 2. ChromaImagingKit (Swift Package)\
\
**Purpose**\
\
- Apple-native imaging engine that does the \'93ITK-style\'94 parts, but:\
  - Written in Swift.  \
  - Uses **Metal 4**, **Accelerate/vDSP**, and modern Apple APIs.  \
  - Focused on CT/MRI slice and volume processing for NeuroMetrica.\
\
Think of it as: **\'93ITK-lite, but built specifically for Apple hardware and neuro imaging.\'94**\
\
### 2.1 Directory Layout\
\
Inside `ChromaImagingKit/Sources/ChromaImagingKit`:\
\
```text\
ChromaImagingKit/\
    Core/\
        ChromaContext.swift\
        ChromaDevice.swift\
        ChromaError.swift\
        ChromaLogger.swift\
\
    Models/\
        ChromaPixelFormat.swift\
        ChromaSpacing.swift\
        CIImage2D.swift\
        CIImageVolume.swift\
        CIMetadata.swift\
        CISlice.swift\
        SliceOrientation.swift\
\
    Processing/\
        CPU/\
            ConvertCPU.swift\
            HistogramCPU.swift\
            NormalizeCPU.swift\
            ResizeCPU.swift\
            ThresholdCPU.swift\
            WindowLevelCPU.swift\
\
        GPU/\
            MPSGaussian.swift\
            MPSLaplacian.swift\
            MPSSobel.swift\
            RegistrationGPU.swift\
            SliceExtractGPU.swift\
            SliceExtractKernel.metal\
            VolumeConvolutionGPU.swift\
            VolumeResampleGPU.swift\
            WindowLevelGPU.swift\
            WindowLevelKernel.metal\
\
    Filters/\
        CPU/\
            MedianCPU.swift\
            SharpenCPU.swift\
            SmoothCPU.swift\
\
        GPU/\
            Gaussian3D.metal\
            Laplacian3D.metal\
            Sobel3D.metal\
\
    Volume/\
        VolumeInterpolator.swift\
        VolumeMapper.swift\
        VolumeOrientation.swift\
        VolumeReducer.swift\
        VolumeSlicer.swift\
\
    IO/\
        ImageLoaderProtocol.swift\
        MetaImageLoader.swift\
        NIfTILoader.swift\
        NRRDLoader.swift\
        PNGLoader.swift\
        RAWVolumeLoader.swift\
\
    Protocols/\
        ImageLoader.swift\
        ImageProcessor.swift\
        SliceProcessor.swift\
        VolumeProcessor.swift\
\
    Utils/\
        BufferUtils.swift\
        MathUtils.swift\
        MetalUtils.swift\
        TimingUtils.swift\
        vImageUtils.swift\
        CIImage2D+CGImage.swift\
```\
\
> **Important note:**  \
> You created **a lot of files as scaffolding**, many of which are currently empty or nearly empty. That\'92s expected. This doc treats them as **placeholders**: the folder structure is there, but the logic is not implemented yet.\
\
Additionally, there is a C-based target `CNifti` under `ChromaImagingKit/Sources/CNifti` which embeds the official NIfTI-2 reference implementation and its small compression helper library:\
\
```text\
ChromaImagingKit/\
    Sources/\
        CNifti/\
            NiftiBridge.c\
            NiftiBridge.h\
            nifti2/\
                nifti2.h\
                nifti2_io.h\
                nifti2_io.c\
                nifti2_io_version.h\
                nifti1.h\
            znzlib/\
                znzlib.c\
                znzlib.h\
                znzlib_version.h\
```\
\
- `NiftiBridge.c/.h` exposes a tiny C API (`nm_nifti_load`, `nm_nifti_free`) that NeuroMetrica uses from Swift.\
- The NIfTI-2 and `znzlib` sources are compiled as-is, with Apple\'92s `libz` wired in via `Package.swift`, giving us support for both `.nii` and `.nii.gz` files.\
\
---\
\
## 3. ChromaImagingKit \'97 Implemented Files\
\
This section focuses on files that actually contain meaningful logic right now.\
\
### 3.1 `Core/ChromaContext.swift` \'97 Metal / GPU Context\
\
**What it does**\
\
- Creates and holds a **global Metal context** for the package:\
\
  - `device: MTLDevice` \'97 system default GPU device.  \
  - `commandQueue: MTLCommandQueue` \'97 used for all GPU command buffers.  \
  - `library: MTLLibrary` \'97 default Metal library loaded from `.module` (SwiftPM-friendly).\
\
- Provides helpers:\
\
  ```swift\
  public func makeCommandBuffer() -> MTLCommandBuffer\
  public func makeBuffer(from array: [Float]) -> MTLBuffer\
  ```\
\
**Status**\
\
- \uc0\u9989  Implemented and working.  \
- Used by `WindowLevelGPU` and `SliceExtractGPU` for all GPU work.\
\
**Future plans**\
\
- Add:\
  - Pipeline state cache (for multiple kernels).  \
  - Optional MTLHeap / buffer pooling.  \
  - Debug / profiling hooks for GPU timings.  \
\
---\
\
### 3.2 `Models/CIImage2D.swift` \'97 2D Image Slice Model\
\
**What it represents**\
\
A **2D float image**, usually a single slice from a CT/MRI volume.\
\
**Fields (implemented)**\
\
- `width: Int`  \
- `height: Int`  \
- `pixels: [Float]` \'97 row-major layout (`y * width + x`)  \
- `orientation: SliceOrientation?` \'97 optional (axial/coronal/sagittal)  \
\
**Helpers**\
\
- `count: Int \{ width * height \}`  \
- Subscript operator:\
\
  ```swift\
  public subscript(x: Int, y: Int) -> Float\
  ```\
\
**Status**\
\
- \uc0\u9989  Implemented and used by CPU & GPU processing code.\
\
**Future extensions**\
\
- Stats (min / max / mean) using Accelerate (not implemented yet but planned).  \
- Additional metadata (patient space, transform matrices) if needed.\
\
---\
\
### 3.3 `Models/CIImageVolume.swift` \'97 3D Volume Model\
\
**What it represents**\
\
A **3D float volume** (e.g., CT/MRI scan).\
\
**Fields (intended / implemented)**\
\
- `width: Int`  \
- `height: Int`  \
- `depth: Int`  \
- `spacing: (Float, Float, Float)` \'97 voxel spacing in mm (x, y, z)  \
- `voxels: [Float]` \'97 flattened in z\'96y\'96x order:\
\
  ```text\
  index = z * (width * height) + y * width + x\
  ```\
\
**Status**\
\
- \uc0\u9989  Implemented basic structure for storing volume data.  \
- \uc0\u9989  Used as input to `SliceExtractGPU`.\
\
**Future extensions**\
\
- Convenience APIs for:\
  - Accessing `(x, y, z)` directly.  \
  - Getting slice counts per orientation.  \
  - Running volume-level stats (min/max/mean) using Accelerate.  \
\
---\
\
### 3.4 `Models/SliceOrientation.swift` \'97 Orientation Enum\
\
**What it is**\
\
An enum describing anatomical planes:\
\
```swift\
public enum SliceOrientation: String, Sendable \{\
    case axial\
    case coronal\
    case sagittal\
\}\
```\
\
**Status**\
\
- \uc0\u9989  Implemented and used by `CIImage2D` and `SliceExtractGPU`.\
\
**Planned niceties**\
\
- Extensions for labels (if not already added):\
\
  ```swift\
  var shortLabel: String \{ "AX" / "COR" / "SAG" \}\
  var displayName: String \{ "Axial" / "Coronal" / "Sagittal" \}\
  ```\
\
---\
\
### 3.5 `Processing/CPU/WindowLevelCPU.swift` \'97 CPU WW/WL (Accelerate)\
\
**Purpose**\
\
- Implement WW/WL (window / level) on CPU using **Accelerate/vDSP**, not plain loops.\
\
**Current implementation**\
\
- Uses:\
\
  ```swift\
  vDSP.multiply(slope, srcPixels, result: &dstPixels)\
  vDSP.add(intercept, dstPixels, result: &dstPixels)\
  vDSP.clip(dstPixels, to: 0.0...1.0, result: &dstPixels)\
  ```\
\
- Formula:\
\
  ```text\
  slope     = 1 / window\
  intercept = -((level - window / 2) * slope)\
\
  norm      = slope * pixel + intercept\
  output    = clamp(norm, 0, 1)\
  ```\
\
- Returns a new `CIImage2D` with:\
  - Same width/height  \
  - Clamped pixels in [0, 1]  \
  - Orientation preserved  \
\
**Status**\
\
- \uc0\u9989  Implemented and builds cleanly.  \
- \uc0\u9989  Uses Accelerate (no \'93fallback to plain Swift\'94 here).\
\
**Future extensions**\
\
- Optionally support output ranges other than [0, 1] (e.g. [0, 255] or raw).  \
- Auto-window presets by analyzing volume/slice stats.  \
\
---\
\
### 3.6 `Processing/GPU/WindowLevelKernel.metal` + `WindowLevelGPU.swift` \'97 GPU WW/WL\
\
**Metal kernel (`WindowLevelKernel.metal`)**\
\
- Function name: `windowLevelKernel`.  \
- Operates on 1D index across the entire pixel buffer:\
  - `inPixels` \uc0\u8594  `outPixels`.  \
  - Applies same slope/intercept + clamp as CPU version.\
\
**Swift wrapper (`WindowLevelGPU.swift`)**\
\
- Builds a `MTLComputePipelineState` for `windowLevelKernel`.  \
- Uses `ChromaContext` to:\
  - Create buffers.  \
  - Create a command buffer.  \
  - Dispatch a compute grid over all pixels.  \
- Reads back into a new `[Float]` and constructs `CIImage2D`.\
\
**Status**\
\
- \uc0\u9989  Implemented and ready for use.  \
- Not yet wired into a high-level pipeline, but fully functional.\
\
**Future use cases**\
\
- When the image is **already on GPU** and you want to:\
  - Chain WW/WL after other GPU filters.  \
  - Avoid round-tripping data back to CPU.  \
\
---\
\
### 3.7 `Processing/GPU/SliceExtractKernel.metal` + `SliceExtractGPU.swift` \'97 GPU Slice Extraction\
\
**Metal kernels (`SliceExtractKernel.metal`)**\
\
Implements three kernels:\
\
1. `axialSliceKernel`  \
   - Produces a plane of size **width \'d7 height** (x, y).  \
   - Fixed z index (`sliceIndex`).\
\
2. `coronalSliceKernel`  \
   - Produces a plane of size **width \'d7 depth** (x, z).  \
   - Fixed y index (`sliceIndex`).\
\
3. `sagittalSliceKernel`  \
   - Produces a plane of size **height \'d7 depth** (y, z).  \
   - Fixed x index (`sliceIndex`).\
\
All kernels read from a flattened volume with:\
\
```text\
volumeIndex = z * (width * height) + y * width + x\
```\
\
**Swift wrapper (`SliceExtractGPU.swift`)**\
\
Provides three functions:\
\
```swift\
public static func axialSlice(from volume: CIImageVolume, z: Int) -> CIImage2D\
public static func coronalSlice(from volume: CIImageVolume, y: Int) -> CIImage2D\
public static func sagittalSlice(from volume: CIImageVolume, x: Int) -> CIImage2D\
```\
\
Each:\
\
- Uses `ChromaContext` for the Metal device and queue.  \
- Uploads `CIImageVolume.voxels` to a `MTLBuffer`.  \
- Dispatches the appropriate kernel with a 2D grid.  \
- Reads back the 2D slice as `[Float]`.  \
- Returns a `CIImage2D` with:\
  - Correct `width` and `height` for that orientation.  \
  - Correct `orientation` (`.axial`, `.coronal`, `.sagittal`).  \
\
**Status**\
\
- \uc0\u9989  Implemented and consistent across AX/COR/SAG.  \
- This is the backbone for **scrolling through slices** and **multi-planar views**.\
\
**Future improvements**\
\
- Keep volume data **resident on GPU** to avoid re-uploading on each slice extraction.  \
- Provide an async/await version instead of blocking on `waitUntilCompleted()`.  \
\
---\
\
### 3.8 NIfTI IO Bridge \'97 CNifti + `NIfTILoader.swift`\
\
**What it does**\
\
- Uses a dedicated C target `CNifti` (see Section 2.1) that bundles the official NIfTI-2 reference implementation plus `znzlib` for compressed file support.\
- Exposes a tiny C API via `NiftiBridge.c/.h`:\
  - `nm_nifti_load(const char *path)` \uc0\u8594  returns an `NM_NiftiVolume *` with dimensions, spacing, voxel count, and a `float *` voxel buffer.\
  - `nm_nifti_free(NM_NiftiVolume *)` \uc0\u8594  releases all C-allocated memory.\
- `NIfTILoader.swift` calls into this bridge and converts the result into a Swift `CIImageVolume`:\
  - Copies the C `float *` buffer into a Swift `[Float]`.\
  - Fills `width`, `height`, `depth`, `timepoints`, and spacing.\
  - Logs a short summary (`ndim`, size, timepoints, voxelCount, spacing, NIfTI-2 flag) for smoke-testing.\
\
**Status**\
\
- \uc0\u9989  CNifti target is integrated into `ChromaImagingKit` and builds cleanly with Apple\'92s `libz`.\
- \uc0\u9989  `NIfTILoader.loadVolume(from:)` is implemented and returns a real `CIImageVolume` for `.nii` and `.nii.gz` float volumes. This path has been smoke\u8209 tested with a real clinical-style volume (e.g. `chris_t1.nii.gz`, 188 \'d7 256 \'d7 190, spacing \u8776  0.88 mm) and logs header/spacing/voxel count on load.\
- \uc0\u9989  A SwiftPM unit test (`testNIfTILoadsVolumeMetadata`) loads `TestVolume.nii.gz` from `ChromaImagingKitTests/TestResources` and asserts that width/height/depth are all > 0.\
- \uc0\u9989  The NIfTI path is now wired end\u8209 to\u8209 end: `ChromaEngine.loadNIfTI(at:)` calls `NIfTILoader`, `ChromaEngineBridge` exposes this to the app, and `ViewerViewModel` + `ViewerView` use it via the SwiftUI `.fileImporter` flow with security\u8209 scoped URL access. Axial slices can be loaded and displayed in the viewer; coronal/sagittal orientations are scaffolded but still need a full, correct implementation in the slice extraction path.\
\
**Next steps (NIfTI)**\
- Implement and verify true coronal/sagittal extraction for NIfTI volumes in the GPU path (correct strides and output dimensions for YZ/XZ planes instead of treating everything as axial).\
- Add small diagnostics in the viewer (orientation label, slice count per orientation) to make it obvious when AX/COR/SAG are behaving correctly.\
\
---\
\
## 4. ChromaImagingKit \'97 Scaffolding & Empty Files\
\
You created a lot of **empty or near-empty files** to reflect the long-term architecture. They are mostly located in:\
\
- `Processing/CPU/` (other CPU operations)  \
- `Processing/GPU/` (other GPU operations)  \
- `Filters/CPU/` and `Filters/GPU/`  \
- `Volume/`  \
- `IO/`  \
- `Utils/`  \
- `Protocols/`  \
\
These may include files with names like:\
\
- `NormalizeCPU.swift`, `HistogramCPU.swift`, `ResizeCPU.swift`, `ThresholdCPU.swift`, `ConvertCPU.swift`, etc.  \
- `VolumeResampleGPU.swift`, `VolumeConvolutionGPU.swift`, `RegistrationGPU.swift`.  \
- `VolumeSlicer.swift`, `VolumeInterpolator.swift`, `VolumeMapper.swift`, `VolumeReducer.swift`, `VolumeOrientation.swift`.  \
- `NIfTILoader.swift`, `NRRDLoader.swift`, `MetaImageLoader.swift`, `RAWVolumeLoader.swift`, `PNGLoader.swift`.  \
- `BufferUtils.swift`, `MetalUtils.swift`, `TimingUtils.swift`, `MathUtils.swift`, `vImageUtils.swift`.  \
- `ImageLoader.swift`, `ImageProcessor.swift`, `VolumeProcessor.swift`, `SliceProcessor.swift`.  \
\
> Earlier brainstorm names like `MIPRenderer.swift`, `MPRRenderer.swift`, or `GaussianBlurCPU.swift`/`GaussianBlurGPU.swift` have been dropped in favor of the actual file names listed in sections 2.1 and 13.\
\
**Status of these files**\
\
- \uc0\u55357 \u57313  Present in the project, but:\
  - Empty or nearly empty.  \
  - No real implementation yet.  \
\
- That\'92s intentional: they are **reserved namespaces** for future work.\
\
**How to treat them**\
\
- Do **not** delete them; they express the intended architecture.  \
- Implement features as you need them, filling these existing stubs.  \
- If a future dev sees an empty file in one of these folders, they should:\
  - Check this doc.  \
  - Implement the feature according to the design philosophy below.  \
\
---\
\
## 5. DCMTKLoader (Swift Package)\
\
**Purpose**\
\
- Own all DICOM-specific responsibilities so the app and ChromaImagingKit don\'92t need to know the details of the DICOM standard.  \
- Bridge **DCMTK** (C++ DICOM library) into Swift via ObjC++.\
\
### 5.1 Directory Layout (high level)\
\
Inside `DCMTKLoader/Sources/DCMTKLoader` you currently have something like:\
\
```text\
DCMTKLoader/\
    Sources/DCMTKLoader/\
        DCMTKLoader/               # Swift-facing API (likely minimal for now)\
        Bridging/                  # ObjC++ wrapper / bridge\
            DicomBridge.h\
            DicomBridge.mm\
        Loader/\
            DICOMLoader.swift\
        Models/\
            DICOMStudy.swift\
        Utils/\
            DICOMConversionHelpers.swift\
```\
\
> Note: exact folder names may vary slightly (e.g. you might have named the ObjC bridge folder `Bridging/` or similar), but the concept is the same.\
\
### 5.2 Package.swift\
\
The `Package.swift` for `DCMTKLoader`:\
\
- Defines a library product: `DCMTKLoader`.  \
- Sets (conceptually):\
\
  ```swift\
  publicHeadersPath: "Bridging"\
  cxxSettings: [\
      .headerSearchPath("Bridging"),\
      .define("DCMTK_LOADER", to: "1")\
  ]\
  ```\
\
This tells SwiftPM where the bridging headers live and configures C++ compilation flags.\
\
### 5.3 Status\
\
- \uc0\u9989  Package structure is present.  \
- \uc0\u9989  Bridging files (`DicomBridge.h` / `.mm`) exist.  \
- \uc0\u10060  DICOM parsing / loading is **not implemented** yet.  \
- \uc0\u10060  No real Swift API surface (`DICOMStudy`, `DICOMSeries`, etc.) yet.\
\
**Future plan**\
\
- Use DCMTK to:\
  - Read DICOM files/studies/series.  \
  - Extract pixel data + basic metadata.  \
- Expose a clean Swift API that outputs something like:\
\
  ```swift\
  struct DICOMVolumeExport \{\
      let volume: CIImageVolume\
      let metadata: DICOMMetadata\
  \}\
  ```\
\
- ChromaImagingKit should **not** know anything about DICOM internals\'97just `CIImageVolume`.\
\
---\
\
## 6. Design Philosophy\
\
The guiding principles for this codebase:\
\
1. **Push modern Apple hardware**\
\
   - Use **Metal 4**, **Accelerate/vDSP**, and **MPS** aggressively.  \
   - Choose:\
     - CPU + Accelerate for low-latency, simple per-slice transforms (WW/WL).  \
     - GPU for heavy volume operations (slice extraction, 3D filters, resampling).  \
     - NPU / Core ML later for AI tasks.  \
\
2. **Use native tools instead of fighting legacy**\
\
   - Prefer Swift, SwiftPM, SwiftUI, Combine, Metal, Accelerate.  \
   - Use DCMTK only at the periphery (for DICOM parsing), wrapped behind a clean Swift API.  \
   - Avoid trying to port full ITK/VTK C++ stacks; instead, **rethink** the essential features using Apple-native patterns.\
\
3. **Hybrid CPU + GPU pipeline**\
\
   - WW/WL: CPU (Accelerate) \uc0\u8594  instant feedback for sliders.  \
   - Slice extraction and volume transforms: GPU (Metal).  \
   - Later: AI overlays (NPU) and composite pipelines.  \
\
4. **Scaffold now, fill in as needed**\
\
   - Many files are present but empty to outline the future domain:\
     - Filters, Volume, IO, Utils, Protocols.  \
   - When you implement a feature, you **fill in the stub** in the right place rather than creating random new files.\
\
5. **Clinical-grade UX is the target**\
\
   - Viewer should feel like professional PACS:\
     - Smooth scrolling.  \
     - Instant WW/WL.  \
     - Clear AX/COR/SAG orientation.  \
   - The engine architecture is built to support that level of responsiveness and clarity.\
\
---\
\
## 7. Where Work Stopped & Suggested Next Steps\
\
At the current snapshot:\
\
- \uc0\u9989  Core imaging engine pieces are in place:\
  - Volume model.  \
  - Slice model.  \
  - GPU slice extraction (AX/COR/SAG).  \
  - CPU (Accelerate) WW/WL.  \
  - GPU WW/WL.  \
  - Metal context.  \
\
- \uc0\u55357 \u57313  Many files exist as **scaffolding**, but are still empty.\
\
- \uc0\u10060  NeuroMetrica viewer is **not yet** fully wired to:\
  - Load a volume.  \
  - Use `SliceExtractGPU`.  \
  - Apply `WindowLevelCPU`.  \
  - Display the result as a SwiftUI `Image`.  \
\
### Good next tasks for **any developer picking this up**:\
\
1. **Display pipeline**\
\
   - Implement a conversion: `CIImage2D` \uc0\u8594  `CGImage` \u8594  SwiftUI `Image`.  \
   - Wire `ViewerViewModel` to:\
     - Hold current volume.  \
     - Hold `SliceOrientation`, slice index, WW/WL.  \
     - Use `SliceExtractGPU` + `WindowLevelCPU` to produce a display-ready slice.  \
\
2. **High-level Slice Pipeline (optional, but clean)**\
\
   - Implement a small type (e.g., `SlicePipeline`) that:\
     - Input: `CIImageVolume` + orientation + index + WW/WL.  \
     - Output: `CIImage2D` (processed slice).  \
   - Internally combines:\
     - `SliceExtractGPU`.  \
     - `WindowLevelCPU`.  \
\
3. **Start filling IO/Volume stubs**\
\
   - Choose one format to implement first (likely NIfTI).  \
   - Implement `NIfTILoader` to produce a `CIImageVolume`.  \
\
4. **Optimize GPU usage later**\
\
   - Add a GPU-resident volume handle to avoid re-uploading data per slice.  \
   - Make GPU calls async instead of blocking.  \
\
---\
\
If you\'92re reading this as a future-you or another developer:  \
the core idea is **not** just \'93make it work\'94, but **build a modern, hardware-pushed, Apple-native imaging engine**, with a clean separation between:\
\
- **App/UI** (NeuroMetrica)  \
- **Imaging engine** (ChromaImagingKit)  \
- **DICOM world** (DCMTKLoader)  \
\
The files exist to support that long-term design, even if many are still empty.\
\
---\
\
## 8. TL;DR for Future Me\
\
NeuroMetrica = app (SwiftUI, MVVM).  \
ChromaImagingKit = Apple-native imaging engine (ITK-lite) using Metal + Accelerate.  \
DCMTKLoader = thin DICOM bridge using DCMTK (C++ / ObjC++), returns CIImageVolume.\
\
**What works now (engine side):**\
- Models for volume + slices (`CIImageVolume`, `CIImage2D`, `SliceOrientation`).\
- Metal context (`ChromaContext`).\
- GPU slice extraction (axial/coronal/sagittal) via `SliceExtractGPU` + `SliceExtractKernel.metal`.\
- CPU WW/WL using Accelerate (`WindowLevelCPU`).\
- GPU WW/WL (`WindowLevelGPU` + `WindowLevelKernel.metal`).\
\
**What\'92s still missing for a demo:**\
- Loading a real volume (e.g. NIfTI) into `CIImageVolume`.\
- Turning `CIImage2D` into a SwiftUI `Image` and showing it in `ViewerView`.\
- Wiring the slider controls (slice index + WW/WL) to the pipeline.\
\
---\
\
## 9. Mental Model: End-to-End Data Flow\
\
### 9.1 Final Intended Pipeline\
\
1. **Input (filesystem / PACS)**\
   - DICOM: use `DCMTKLoader` (DCMTK C++ under the hood).\
   - Other formats (NIfTI, NRRD, MHD, RAW): use `ChromaImagingKit.IO.*Loader`.\
\
2. **Decoding \uc0\u8594  Volume**\
   - All loaders (including DCMTKLoader) produce a `CIImageVolume`:\
     - Float32 voxels.\
     - Known width/height/depth.\
     - Spacing (mm).\
\
3. **Volume \uc0\u8594  Slice**\
   - `SliceExtractGPU` (Metal) takes `CIImageVolume` + orientation + index.\
   - Outputs `CIImage2D` with `SliceOrientation` set correctly.\
\
4. **Slice \uc0\u8594  Display Space**\
   - `WindowLevelCPU` (Accelerate) applies WW/WL to `CIImage2D` \uc0\u8594  normalized [0, 1].\
   - Separate small utility will map `[0, 1]` \uc0\u8594  `CGImage` (8-bit) \u8594  SwiftUI `Image`.\
\
5. **UI (NeuroMetrica)**\
   - `ViewerViewModel` holds:\
     - Current `CIImageVolume`.\
     - Orientation (AX/COR/SAG).\
     - Slice index.\
     - WW/WL.\
   - On change:\
     - Re-run slice extraction + WW/WL.\
     - Publish updated `Image` for `ViewerView` to display.\
\
**Key constraint:**  \
\
ChromaImagingKit doesn\'92t know about SwiftUI. It stops at `CIImage2D` / `CGImage`.  \
NeuroMetrica is responsible for UI and user interaction.\
\
---\
\
\
`ChromaEngine` is the **high-level API** that NeuroMetrica should talk to, instead of calling low-level pieces (`SliceExtractGPU`, `WindowLevelCPU`, loaders, etc.) directly.\
\
**Intent / role**\
\
- Lives in **ChromaImagingKit** (recommended path: `Sources/ChromaImagingKit/Core/ChromaEngine.swift`).  \
- Provides a small, app-friendly surface area for:\
  - Loading volumes (starting with NIfTI, later NRRD/MetaImage/RAW).\
  - Producing display-ready slices for the viewer.\
  - Choosing CPU vs GPU processing strategies internally.\
- Hides:\
  - Metal details (`ChromaContext`, command buffers, kernels).\
  - IO details (individual loader types).\
  - Future complexity (GPU residency, async pipelines, NPU/AI paths).\
\
**Example shape (conceptual only)**\
\
The exact API can evolve, but the idea is something like:\
\
```swift\
public enum WLMode \{\
    case cpu\
    case gpu\
\}\
\
public struct ChromaEngine \{\
    public func loadNIfTI(from url: URL) throws -> CIImageVolume\
\
    public func makeSlice(\
        from volume: CIImageVolume,\
        orientation: SliceOrientation,\
        index: Int,\
        window: Float,\
        level: Float,\
        wlMode: WLMode = .cpu\
    ) throws -> CIImage2D\
\}\
```\
\
**Current implementation status (2025-11)**  \
A first\uc0\u8209 pass `ChromaEngine` has been implemented with `loadNIfTI(at:)` and `makeSlice(from:orientation:index:window:level:)`. Internally it uses `NIfTILoader` for IO, `SliceExtractGPU` for slice extraction, and `WindowLevelCPU` for WW/WL. This is now wired all the way through to NeuroMetrica via `ChromaEngineBridge` and `ViewerViewModel`:\
- Axial slices load, window/level, and render in the SwiftUI viewer for real NIfTI volumes.\
- Coronal/sagittal kernels exist in `SliceExtractKernel.metal`, but their Swift/engine wiring still needs a proper implementation and verification (correct plane sizes and strides). For now, AX is treated as the primary orientation, and COR/SAG support is marked as a TODO.\
\
**Why this matters**\
\
- **NeuroMetrica stays simple**:\
  - `ViewerViewModel` only needs to know about:\
    - `CIImageVolume`\
    - `CIImage2D`\
    - `SliceOrientation`\
    - `ChromaEngine` methods\
  - It doesn\'92t care whether WW/WL is CPU or GPU, or which loader was used.\
- **Engine can evolve internally**:\
  - You can change how volumes are stored (GPU textures vs buffers).\
  - You can switch defaults to GPU WW/WL later.\
  - You can add caching, prefetching, or AI hooks without changing the app.\
\
**Important reminder for future you**\
\
- In V1.0\'96V1.2, it is totally fine if `ChromaEngine.makeSlice` uses:\
  - `SliceExtractGPU` + `WindowLevelCPU` under the hood.\
- Later, when GPU WW/WL is solid, you can:\
  - Flip the default `wlMode` to `.gpu`.\
  - Keep `.cpu` around as a debug or fallback path.\
- Whenever you add or change `ChromaEngine` APIs, update:\
  - Section **9.2** (this description).\
  - Section **19** (wiring TODO) to reflect new features that should be exposed in the app.\
\
---\
\
## 10. Hardware and OS Support Policy\
\
This project is intentionally **future-leaning**, not legacy-friendly.\
\
- **Minimum OS targets**\
  - iOS 17+\
  - macOS 14+  \
  (matching the SwiftPM `platforms` declarations in the packages)\
\
- **Hardware assumptions**\
  - Expect real users to be on **A17+** iPhones and **M-series** Macs.\
  - It is acceptable if performance is mediocre on older A-series.\
  - We will aggressively use:\
    - Metal 3/4 features.\
    - Accelerate/vDSP.\
    - MPS where appropriate.\
    - Later: Core ML / NPU for AI features.\
\
- **Consequence**\
  - We do **not** waste time optimizing for very old devices.\
  - We are allowed to design algorithms assuming a reasonably fast GPU + NPU.\
\
---\
\
## 11. Non-Obvious Decisions\
\
### 11.1 Why not just use ITK/VTK?\
\
- Full ITK/VTK are powerful but:\
  - Heavy C++ stacks.\
  - Less aligned with Apple's modern APIs.\
  - Harder to integrate cleanly with SwiftUI and Metal pipelines.\
- Instead, we:\
  - Re-implement a **subset** of ITK-like functionality using:\
    - Metal (for volume ops and slicing).\
    - Accelerate/vDSP (for per-slice math like WW/WL).\
    - MPS (for standard filters like Gaussian/Sobel/Canny later).\
  - Keep design focused on **neuro imaging** and mobile/desktop Apple hardware.\
\
### 11.2 Why DCMTKLoader is a separate package\
\
- DICOM parsing is messy and C++-heavy.\
- Keeping DCMTK in `DCMTKLoader`:\
  - Avoids ObjC++ ending up in the app target.\
  - Lets `ChromaImagingKit` and `NeuroMetrica` stay pure Swift.\
  - Makes it easier to swap DICOM backends later if needed.\
\
### 11.3 Why both CPU and GPU WW/WL\
\
- **CPU (Accelerate)** WW/WL:\
  - Great for tiny per-slice updates as user moves sliders.\
  - Low-latency and simple for UI feedback.\
\
- **GPU** WW/WL:\
  - Useful in pipelines where data is already on GPU.\
  - Allows chaining with other GPU filters without CPU round-trips.\
\
We intentionally support both because WW/WL is central to CT/MRI viewing, and different paths are optimal in different scenarios.\
\
---\
\
## 12. Parking Lot (Ideas, Not Commitments)\
\
These are ideas we like but have not committed to implementing yet.  \
If you come back after a long break, this list is a good starting point to re-evaluate.\
\
- **Registration**\
  - Rigid and deformable registration for multi-modal studies (CT/MRI fusion).\
  - Likely GPU-accelerated using Metal + MPS.\
\
- **3D Rendering**\
  - MIP/MPR-style views using `VolumeMapper` and `VolumeSlicer`.\
  - Volume rendering pipeline for quick 3D previews.\
\
- **Advanced Filters**\
  - Anisotropic diffusion.\
  - Non-local means denoising.\
  - Vesselness filters (for vascular work).\
\
- **AI Integration**\
  - Core ML models that:\
    - Segment tumors or critical structures.\
    - Suggest key slices or views.\
  - UX goal: overlays that feel instantaneous and intuitive.\
\
- **Workflow Features**\
  - Simple report snapshots: store WW/WL + slice index + annotations.\
\
\
## 13. ITK Feature Mapping and File Responsibilities\
\
This section maps classic **ITK concepts** (IO, filters, registration, etc.) to the **Swift files you created** in ChromaImagingKit and DCMTKLoader. It also gives a one-line description of what each file is supposed to do so future work is not guesswork.\
\
> Note: \'93Status\'94 is based on the intent when we scaffolded these files. Some are implemented, others are stubs or partially filled in.\
\
### 13.1 Core (Infrastructure / ITK Core Analogy)\
\
- **ChromaContext.swift**  \
  - ITK analogy: _global image processing context / factory_.  \
  - Responsibility: Own the Metal device, command queue, and default library; helper methods to create command buffers and buffers.  \
  - Status: **Implemented** and used by GPU code.\
\
- **ChromaDevice.swift**  \
  - ITK analogy: _not a direct ITK concept; more like hardware abstraction_.  \
  - Responsibility: Describe or query the active GPU/CPU device capabilities (limits, supported features) and choose paths accordingly.  \
  - Status: **Scaffold** (intended for future hardware-aware decisions).\
\
- **ChromaError.swift**  \
  - ITK analogy: _ITK exception types_.  \
  - Responsibility: Central error enum for ChromaImagingKit (IO errors, Metal errors, invalid dimensions, etc.).  \
  - Status: **Scaffold/partial**.\
\
- **ChromaLogger.swift**  \
  - ITK analogy: _logging / debug output_.  \
  - Responsibility: Unified logging for timing, warnings, and debug traces across CPU and GPU paths.  \
  - Status: **Scaffold/partial**.\
\
### 13.2 Models (ITK Image / Metadata)\
\
- **CIImage2D.swift**  \
  - ITK analogy: `itk::Image<float, 2>`.  \
  - Responsibility: 2D float slice with width/height, pixel buffer, and optional `SliceOrientation`.  \
  - Status: **Implemented**.\
\
- **CIImageVolume.swift**  \
  - ITK analogy: `itk::Image<float, 3>`.  \
  - Responsibility: 3D float volume (width/height/depth, spacing, voxels).  \
  - Status: **Implemented**.\
\
- **SliceOrientation.swift**  \
  - ITK analogy: ITK\'92s use of image directions/orientation, here simplified to AX/COR/SAG.  \
  - Responsibility: Enum describing anatomical plane for slices.  \
  - Status: **Implemented**.\
\
- **CISlice.swift**  \
  - ITK analogy: a view or extraction of a 2D slice from a 3D image.  \
  - Responsibility: Higher-level wrapper combining `CIImage2D` with index/orientation and perhaps metadata (intended to organize slice info cleanly).  \
  - Status: **Scaffold/partial**.\
\
- **CIMetadata.swift**  \
  - ITK analogy: image metadata dictionaries (origin, direction cosines, patient info).  \
  - Responsibility: Store non-pixel information (patient space, acquisition parameters, window presets, etc.).  \
  - Status: **Scaffold**.\
\
- **ChromaPixelFormat.swift**  \
  - ITK analogy: pixel component types / scalar vs vector images.  \
  - Responsibility: Enumerate internal pixel layouts (scalar float, RGBA, etc.) for conversion and IO.  \
  - Status: **Scaffold**.\
\
- **ChromaSpacing.swift**  \
  - ITK analogy: `SpacingType` in ITK (voxel size in mm).  \
  - Responsibility: Small type to represent voxel spacing, reused by `CIImageVolume` and loaders.  \
  - Status: **Scaffold/partial**.\
\
### 13.3 IO (ITK ImageFileReader & Friends)\
\
All IO files are the **ITK ImageIO stack replacement**.\
\
- **ImageLoaderProtocol.swift**  \
  - ITK analogy: base `ImageIOBase` / reader interface.  \
  - Responsibility: Protocol all loaders conform to (common API to produce `CIImageVolume` + `CIMetadata`).  \
  - Status: **Scaffold**.\
\
- **NIfTILoader.swift**  \
  - ITK analogy: `itkNiftiImageIO`.  \
  - Responsibility: Read NIfTI files from disk, parse header + image data, return `CIImageVolume` + `CIMetadata`.  \
  - Status: **Implemented (first pass)** \'97 backed by the CNifti C target and `NiftiBridge` described in Sections 2.1 and 3.8; supports loading `.nii` and `.nii.gz` float volumes into `CIImageVolume`.\
\
- **NRRDLoader.swift**  \
  - ITK analogy: `itkNrrdImageIO`.  \
  - Responsibility: Load NRRD volumes into `CIImageVolume`.  \
  - Status: **Scaffold**.\
\
- **MetaImageLoader.swift**  \
  - ITK analogy: `itkMetaImageIO` (`.mhd`/`.mha`).  \
  - Responsibility: Parse MetaImage header + raw data and build `CIImageVolume`.  \
  - Status: **Scaffold**.\
\
- **RAWVolumeLoader.swift**  \
  - ITK analogy: `itkRawImageIO`.  \
  - Responsibility: Load raw binary volume (when you already know dimensions/spacing from somewhere else).  \
  - Status: **Scaffold**.\
\
- **PNGLoader.swift**  \
  - ITK analogy: 2D PNG reader (stacking slices).  \
  - Responsibility: Load 2D PNGs into `CIImage2D` or stack them into a volume for certain research use cases.  \
  - Status: **Scaffold**.\
\
### 13.4 Processing / CPU (ITK Filters on CPU)\
\
These are the **CPU-based filters**, meant to lean on Accelerate where it makes sense.\
\
- **WindowLevelCPU.swift**  \
  - ITK analogy: intensity windowing filter.  \
  - Responsibility: Apply WW/WL on a slice using vDSP (slope/intercept + clamp to [0, 1]).  \
  - Status: **Implemented**.\
\
- **NormalizeCPU.swift**  \
  - ITK analogy: normalization filters (rescale intensity, NormalizeImageFilter).  \
  - Responsibility: Normalize intensities (min\'96max to [0,1], z-score, etc.).  \
  - Status: **Scaffold**.\
\
- **HistogramCPU.swift**  \
  - ITK analogy: HistogramImageFilter / statistics filters.  \
  - Responsibility: Compute histograms and simple stats; later used for auto-window or contrast enhancement.  \
  - Status: **Scaffold**.\
\
- **ThresholdCPU.swift**  \
  - ITK analogy: BinaryThresholdImageFilter.  \
  - Responsibility: Apply scalar thresholds (binary mask or clamp outside range).  \
  - Status: **Scaffold**.\
\
- **ResizeCPU.swift**  \
  - ITK analogy: ResampleImageFilter (2D).  \
  - Responsibility: Resize 2D slices (e.g. nearest/linear interpolation) on CPU.  \
  - Status: **Scaffold**.\
\
- **ConvertCPU.swift**  \
  - ITK analogy: CastImageFilter / pixel type conversion.  \
  - Responsibility: Convert between pixel formats and ranges (float \uc0\u8596  8-bit, etc.).  \
  - Status: **Scaffold**.\
\
### 13.5 Processing / GPU (ITK Filters on GPU / MPS)\
\
These correspond to ITK\'92s heavier 3D processing and some registration, but pushed onto Metal / MPS.\
\
- **SliceExtractGPU.swift** + **SliceExtractKernel.metal**  \
  - ITK analogy: ExtractImageFilter for 3D \uc0\u8594  2D.  \
  - Responsibility: Extract axial/coronal/sagittal slices from a volume entirely on GPU.  \
  - Status: **Implemented**.\
\
- **WindowLevelGPU.swift** + **WindowLevelKernel.metal**  \
  - ITK analogy: intensity windowing, but GPU-accelerated.  \
  - Responsibility: WW/WL when data is already on GPU, and for chained GPU pipelines.  \
  - Status: **Implemented**.\
\
- **VolumeResampleGPU.swift**  \
  - ITK analogy: 3D ResampleImageFilter.  \
  - Responsibility: Change volume resolution/spacing using GPU interpolation (intended for isotropic resampling).  \
  - Status: **Scaffold**.\
\
- **VolumeConvolutionGPU.swift**  \
  - ITK analogy: ConvolutionImageFilter / 3D Gaussian/Laplacian filters.  \
  - Responsibility: Run generic 3D convolutions on volumes (kernels implemented via `.metal` files or MPS).  \
  - Status: **Scaffold**.\
\
- **MPSGaussian.swift**, **MPSLaplacian.swift**, **MPSSobel.swift**  \
  - ITK analogy: Gaussian, Laplacian, and Sobel filters.  \
  - Responsibility: Thin wrappers around Metal Performance Shaders (MPS) to apply these filters efficiently on GPU.  \
  - Status: **Scaffold/partial** (intended to call into MPS once wired).\
\
- **RegistrationGPU.swift**  \
  - ITK analogy: ITK registration framework (rigid/affine/deformable).  \
  - Responsibility: Host GPU-accelerated registration routines (similar spirit to ITK but focused on neurosurgical use cases and modern hardware).  \
  - Status: **Scaffold** (reserved for future advanced work).\
\
### 13.6 Filters (Named ITK Filters)\
\
These are more \'93semantic\'94 filters that sit on top of the generic CPU/GPU processing.\
\
- **Filters/CPU/MedianCPU.swift**  \
  - ITK analogy: MedianImageFilter.  \
  - Responsibility: Apply median filtering for denoising on CPU.  \
  - Status: **Scaffold**.\
\
- **Filters/CPU/SharpenCPU.swift**  \
  - ITK analogy: unsharp mask / edge-enhancing filters.  \
  - Responsibility: CPU-based sharpening filter for certain views.  \
  - Status: **Scaffold**.\
\
- **Filters/CPU/SmoothCPU.swift**  \
  - ITK analogy: SmoothingRecursiveGaussianImageFilter or similar.  \
  - Responsibility: General-purpose smoothing (possibly calling into Normalize/Resize/etc.).  \
  - Status: **Scaffold**.\
\
- **Filters/GPU/Gaussian3D.metal**  \
  - ITK analogy: 3D Gaussian blur.  \
  - Responsibility: Metal compute kernel for 3D Gaussian smoothing on volumes.  \
  - Status: **Scaffold** (kernel template).\
\
- **Filters/GPU/Laplacian3D.metal**  \
  - ITK analogy: LaplacianImageFilter in 3D.  \
  - Responsibility: Metal kernel to compute Laplacian response in 3D.  \
  - Status: **Scaffold**.\
\
- **Filters/GPU/Sobel3D.metal**  \
  - ITK analogy: 3D Sobel edge detection.  \
  - Responsibility: Metal kernel for 3D gradient magnitude / edges.  \
  - Status: **Scaffold**.\
\
### 13.7 Volume Operations\
\
These are the building blocks for MIP/MPR and more advanced 3D tools.\
\
- **VolumeSlicer.swift**  \
  - ITK analogy: ExtractImageFilter + slice management.  \
  - Responsibility: High-level slicing logic (decide indices, ranges, and call `SliceExtractGPU`).  \
  - Status: **Scaffold**.\
\
- **VolumeInterpolator.swift**  \
  - ITK analogy: interpolators used by ResampleImageFilter.  \
  - Responsibility: Define interpolation strategies (nearest/linear) for volumes, for use by both CPU and GPU resampling.  \
  - Status: **Scaffold**.\
\
- **VolumeMapper.swift**  \
  - ITK analogy: MIP / projection filters.  \
  - Responsibility: Map 3D volumes to 2D images (e.g., MIP, minIP, average projections) for quick 3D overviews.  \
  - Status: **Scaffold**.\
\
- **VolumeReducer.swift**  \
  - ITK analogy: reducers/accumulators (e.g., compute min/max, mean, projections).  \
  - Responsibility: Aggregate volume data along dimensions or compute summary stats.  \
  - Status: **Scaffold**.\
\
- **VolumeOrientation.swift**  \
  - ITK analogy: direction cosines / orientation matrices.  \
  - Responsibility: Represent how the volume sits in patient space (layout vs. anatomical axes) and cooperate with `SliceOrientation`.  \
  - Status: **Scaffold**.\
\
### 13.8 Utils (Support for All of the Above)\
\
- **BufferUtils.swift**  \
  - Responsibility: Helper functions to allocate/convert between Swift arrays, Data, and Metal buffers.  \
  - Status: **Scaffold/partial**.\
\
- **MathUtils.swift**  \
  - Responsibility: Small math helpers (clamp, lerp, etc.) shared across modules.  \
  - Status: **Scaffold**.\
\
- **MetalUtils.swift**  \
  - Responsibility: Reusable Metal boilerplate (pipeline creation, threadgroup size helpers, error checks).  \
  - Status: **Scaffold/partial**.\
\
- **TimingUtils.swift**  \
  - Responsibility: Measure elapsed time for CPU/GPU operations (profiling, logging).  \
  - Status: **Scaffold**.\
\
- **vImageUtils.swift**  \
  - Responsibility: Convenience around vImage APIs (for things like format conversion or more advanced CPU filters).  \
  - Status: **Scaffold/partial**.\
\
### 13.9 Protocols (Abstractions / ITK-like Pipelines)\
\
- **ImageLoader.swift**  \
  - Responsibility: High-level abstraction for things that take a URL/path and return `CIImageVolume`.  \
  - Status: **Scaffold**.\
\
- **ImageProcessor.swift**  \
  - Responsibility: Protocol for types that take a `CIImage2D` or `CIImageVolume` and return a processed version.  \
  - Status: **Scaffold**.\
\
- **SliceProcessor.swift**  \
  - Responsibility: Specialization for operations that work only on one slice (e.g., WW/WL, 2D filters).  \
  - Status: **Scaffold**.\
\
- **VolumeProcessor.swift**  \
  - Responsibility: Specialization for 3D volume processors (resampling, convolution, registration).  \
  - Status: **Scaffold**.\
\
### 13.10 DCMTKLoader Mapping\
\
For **DCMTKLoader**, the mapping to DICOM and ITK-style roles is:\
\
- **Bridging/DicomBridge.h / DicomBridge.mm**  \
  - ITK analogy: low-level bridge to DICOM IO (like `itkGDCMImageIO`/`itkDCMTKImageIO`).  \
  - Responsibility: Expose a C/ObjC++ API that calls into DCMTK for reading DICOM files/studies and returns raw pixel data + basic tags.\
\
- **Loader/DICOMLoader.swift**  \
  - Responsibility: Swift layer that calls `DicomBridge` and converts the results into `CIImageVolume` + `CIMetadata`.  \
  - Status: **Scaffold**.\
\
- **Models/DICOMStudy.swift**  \
  - Responsibility: Swift model for a collection of DICOM series/instances (study-level representation).  \
  - Status: **Scaffold**.\
\
- **Utils/DICOMConversionHelpers.swift**  \
  - Responsibility: Helper functions to convert DCMTK C++ structures (pixel data, tags) into Swift types and ChromaImagingKit models.  \
  - Status: **Scaffold**.\
\
Together, these form the DICOM equivalent of ITK\'92s DICOM IO stack, but wrapped as a clean Swift API that outputs `CIImageVolume` into ChromaImagingKit instead of ITK images.\
\
\
\
---\
\
## 14. NPU / AI Integration Strategy (Core ML / Metal / \'93Pushing Hardware\'94)\
\
Long-term, this project is not just about classic image processing. It is explicitly meant to **ride current and future Apple hardware**: GPU + NPU together.\
\
This section is a reminder of how AI should fit into the architecture.\
\
### 14.1 Where AI Fits in the Pipeline\
\
AI should operate on **well-defined stages**, not be sprinkled everywhere:\
\
1. **Volume-level AI**\
   - Input: `CIImageVolume` (possibly normalized / resampled).\
   - Output examples:\
     - Segmentation masks (tumor, vessel, edema, etc.).\
     - Per-voxel risk maps.\
     - Derived scalar volumes (e.g., perfusion parameters).\
\
2. **Slice-level AI**\
   - Input: `CIImage2D` (single slice) or small stack.\
   - Output examples:\
     - 2D segmentation mask / overlay.\
     - Key-slice ranking (which slices are important to show first).\
     - Quality estimates (motion, noise).\
\
3. **Study-level AI**\
   - Input: combinations of volumes + metadata (future).\
   - Output examples:\
     - Suggestions for window presets or layouts.\
     - Smart presets per study type (trauma, tumor, vascular).\
\
The **key rule**: AI outputs should flow back into the existing models:\
- Use `CIImage2D`, `CIImageVolume`, and new \'93mask\'94/\'93overlay\'94 models.\
- Don\'92t bypass ChromaImagingKit; extend it.\
\
### 14.2 Core ML and the NPU\
\
When adding AI:\
\
- Use **Core ML** for model execution:\
  - Prefer models that can run on the **Apple Neural Engine (NPU)** when available.\
  - Fall back to GPU/CPU if needed, but aim NPU-first.\
\
- Keep Core ML in its own layer:\
  - Example: `AIModule/` or `AI/` folder within ChromaImagingKit or a separate package.\
  - Provide clear APIs like:\
\
    ```swift\
    protocol VolumeSegmentationModel \{\
        func predict(volume: CIImageVolume) async throws -> SegmentationResult\
    \}\
    ```\
\
- Avoid mixing:\
  - Don\'92t put Core ML calls inside UI code.\
  - Don\'92t put raw `MLModel` usage into random Utils; keep it organized.\
\
### 14.3 Coordination with Metal\
\
AI and Metal should **cooperate**, not conflict:\
\
- Use Metal for:\
  - Slice extraction.\
  - WW/WL.\
  - Filters (Gaussian, Sobel, Laplacian, etc.).\
  - Resampling.\
\
- Use Core ML for:\
  - Pattern recognition and high-level tasks (segmentation, classification, ranking).\
\
When possible:\
\
- Keep data on GPU where it makes sense.\
- Consider future use of **Metal Performance Shaders Graph (MPSGraph)** or other advanced Metal features when they help build differentiable or custom pipelines.\
\
### 14.4 Performance and UX Constraints\
\
- AI should **not block interaction**:\
  - Viewer scrolling and WW/WL must stay smooth even while AI is running.\
  - Use async/await and background queues.\
\
- AI results can arrive \'93eventually\'94:\
  - It\'92s okay if overlays pop in after a short delay.\
  - Prioritize a responsive viewer over synchronous AI.\
\
- Memory awareness:\
  - CT/MR volumes are large; be careful not to duplicate volume data unnecessarily.\
  - Prefer streaming or tiling for large studies, especially for AI.\
\
---\
\
## 15. Notes for Future AI Collaborator (ChatGPT, etc.)\
\
This section is a set of instructions for any future AI assistant helping with this codebase.\
\
### 15.1 How to Reorient Yourself Quickly\
\
1. **Read this file first**  \
   - Understand the roles of:\
     - NeuroMetrica (app)\
     - ChromaImagingKit (engine)\
     - DCMTKLoader (DICOM)\
   - Skim sections 2, 3, 5, 7\'969, and 13 to rebuild context.\
\
2. **Ask the user for current file lists if structure changed**  \
   - If the user says they added or removed many files, ask them to run:\
     - `find Sources/ChromaImagingKit -type f | sort`\
     - `find Sources/DCMTKLoader -type f | sort`\
   - Use that to avoid guessing at file locations or names.\
\
3. **Do not delete scaffolding files lightly**  \
   - Many files are empty on purpose (they represent planned ITK-like features).\
   - Prefer **filling in** existing stubs rather than renaming or deleting them, unless the user explicitly wants a cleanup.\
\
### 15.2 Architectural Guardrails\
\
When generating or modifying code:\
\
- **Respect the separation of concerns**\
  - App/UI (SwiftUI, MVVM) lives in **NeuroMetrica**.\
  - Imaging engine (Metal, Accelerate, IO) lives in **ChromaImagingKit**.\
  - DICOM parsing (C++/DCMTK, ObjC++) lives in **DCMTKLoader**.\
\
- **Keep ObjC++ confined**\
  - Do not leak ObjC++ into app targets or ChromaImagingKit.\
  - All bridge code must stay in `DCMTKLoader/Bridging`.\
\
- **Prefer Apple-native APIs**\
  - When choosing between a portable but generic option vs an Apple-specific one, it is acceptable (and often preferred) to choose the Apple-specific API (Metal, Accelerate, MPS, Core ML).\
\
### 15.3 Coding Style and Evolution\
\
- **Use modern Swift** (async/await, structured concurrency, Sendable where it makes sense).\
- **Avoid premature micro-optimizations**:\
  - Focus first on clean pipeline design (volume \uc0\u8594  slice \u8594  process \u8594  display).\
  - Optimize hot paths (e.g., WW/WL, slice extraction) using Metal/Accelerate when they are actually in use.\
\
- **Document key decisions in this file**:\
  - If a big architectural decision is made (e.g., changing how volumes are stored, replacing DCMTK, adding a new AI layer), add a short note to Sections 7, 11, or 13 instead of letting the context live only in the chat.\
\
### 15.4 What \'93Pushing Technology\'94 Means Here\
\
- It does **not** just mean using fancy APIs for their own sake.\
- It means:\
  - Taking advantage of **NPU (Core ML)** where it provides real clinical or UX value.\
  - Using **Metal** for truly parallel tasks (3D convolutions, resampling, volume slicing).\
  - Using **Accelerate/vDSP/vImage** for fast, vectorized CPU paths.\
  - Building an engine that feels **ahead of typical PACS** in responsiveness and UX.\
\
Whenever you (future AI) propose an approach, ask:\
\
> \'93Does this leverage Apple hardware in a way that makes the neurosurgeon\'92s experience meaningfully better?\'94\
\
If not, consider a simpler or more hardware-aware alternative.\
\
\
---\
\
## 16. MASTER MAP: ITK \uc0\u8594  Apple Frameworks\
\
This section summarizes, in one place, how classic **ITK domains** map onto **Apple-native frameworks** and the files we\'92ve scaffolded. It\'92s the \'93big picture\'94 so you don\'92t have to reconstruct it from scattered notes.\
\
### 16.1 IO (ITK ImageIO stack)\
\
- **ITK concept**\
  - `ImageFileReader`, `ImageIOBase`, `itkNiftiImageIO`, `itkNrrdImageIO`, `itkMetaImageIO`, `itkRawImageIO`, DICOM IO.\
- **Apple frameworks**\
  - Foundation (`FileHandle`, `Data`), low-level binary parsing in Swift.\
  - No heavy framework required beyond Swift and C/C++ interop.\
- **Our mapping**\
  - **Non-DICOM (ChromaImagingKit.IO)**\
    - `ImageLoaderProtocol.swift`\
    - `NIfTILoader.swift`\
    - `NRRDLoader.swift`\
    - `MetaImageLoader.swift`\
    - `RAWVolumeLoader.swift`\
    - `PNGLoader.swift`\
  - **DICOM (DCMTKLoader)**\
    - `Bridging/DicomBridge.h` / `.mm` (DCMTK C++ interop)\
    - `Loader/DICOMLoader.swift`\
    - `Models/DICOMStudy.swift`\
    - `Utils/DICOMConversionHelpers.swift`\
\
Result: all ITK-style IO is replaced by **Swift loaders** + **DCMTK** for DICOM.\
\
---\
\
### 16.2 Core Image Types and Metadata\
\
- **ITK concept**\
  - `itk::Image<float,2>`, `itk::Image<float,3>`, `Spacing`, `Direction`, metadata dictionaries.\
- **Apple frameworks**\
  - Pure Swift models (no direct framework needed), with optional future use of simd types.\
- **Our mapping**\
  - `CIImage2D.swift`  \uc0\u8594  ITK 2D image\
  - `CIImageVolume.swift` \uc0\u8594  ITK 3D image\
  - `ChromaSpacing.swift` \uc0\u8594  voxel spacing\
  - `SliceOrientation.swift` / `VolumeOrientation.swift` \uc0\u8594  direction/orientation concepts\
  - `CIMetadata.swift` \uc0\u8594  combined metadata structure\
\
Result: ITK\'92s core image/metadata layer becomes **plain Swift structs/classes**, designed to work cleanly with Metal buffers and Core ML later.\
\
---\
\
### 16.3 CPU Filters and Math\
\
- **ITK concept**\
  - Many scalar filters: RescaleIntensity, NormalizeImageFilter, BinaryThresholdImageFilter, statistics, histogram filters, etc.\
- **Apple frameworks**\
  - **Accelerate/vDSP** and **vImage** for vectorized math and image ops.\
- **Our mapping**\
  - `Processing/CPU/WindowLevelCPU.swift`  \
    - Uses **Accelerate/vDSP** for WW/WL (already implemented).\
  - Planned to use Accelerate/vDSP/vImage in:\
    - `NormalizeCPU.swift`\
    - `HistogramCPU.swift`\
    - `ThresholdCPU.swift`\
    - `ResizeCPU.swift`\
    - `ConvertCPU.swift`\
    - `Utils/vImageUtils.swift`\
\
Result: ITK-style CPU filters become **Accelerate/vDSP-driven** operations; WW/WL is the first finished example.\
\
---\
\
### 16.4 GPU Filters and Volume Ops\
\
- **ITK concept**\
  - Convolution filters, gradient filters (Sobel, Laplacian), Gaussian smoothing, resampling, slice extraction, MIP/MPR-style operations.\
- **Apple frameworks**\
  - **Metal** (compute kernels).\
  - **Metal Performance Shaders (MPS)** for standard filters (Gaussian, Sobel, etc.).\
- **Our mapping**\
  - **Metal-based**\
    - `SliceExtractGPU.swift` + `SliceExtractKernel.metal`\
    - `WindowLevelGPU.swift` + `WindowLevelKernel.metal`\
    - `VolumeConvolutionGPU.swift`\
    - `VolumeResampleGPU.swift`\
    - GPU-side kernels in `Filters/GPU/*.metal`\
  - **MPS-based (planned)**\
    - `MPSGaussian.swift`\
    - `MPSLaplacian.swift`\
    - `MPSSobel.swift`\
\
Result: ITK\'92s volume and filter operations are recast as **Metal/MPS pipelines**, tailored to Apple GPUs.\
\
----\
\
#### 16.4.1 Metal Usage Notes (Future)\
\
- Prefer keeping volumes **resident on the GPU** (single upload, many slice operations) instead of re-uploading for every interaction.\
- Consider **3D textures or tightly packed buffers** for volume storage when it simplifies kernels or improves cache behavior.\
- As hot paths become clear (e.g., slice extraction, WW/WL, common filters), consider using **MTLHeap or simple buffer pooling** to reduce allocation overhead.\
- Treat **Metal 4\'96era GPUs (A17+, M\uc0\u8209 series)** as the primary optimization target; it is acceptable if older devices don\'92t get the same level of performance, as long as they remain functionally correct.\
\
\
### 16.5 Higher-Level Filters (Named ITK Filters)\
\
- **ITK concept**\
  - Median filter, smoothing, sharpening, anisotropic diffusion, etc.\
- **Apple frameworks**\
  - Implemented on top of:\
    - Accelerate (CPU).\
    - Metal/MPS (GPU).\
- **Our mapping**\
  - CPU side:\
    - `Filters/CPU/MedianCPU.swift`\
    - `Filters/CPU/SmoothCPU.swift`\
    - `Filters/CPU/SharpenCPU.swift`\
  - GPU side:\
    - `Filters/GPU/Gaussian3D.metal`\
    - `Filters/GPU/Laplacian3D.metal`\
    - `Filters/GPU/Sobel3D.metal`\
\
These are the \'93semantic\'94 filters that correspond to named ITK filters, built on top of our generic CPU/GPU primitives.\
\
---\
\
### 16.6 Registration (Planned, Not Implemented Yet)\
\
- **ITK concept**\
  - Full registration framework:\
    - Rigid/affine/deformable.\
    - Similarity metrics.\
    - Optimizers.\
    - Multi-resolution strategies.\
- **Apple frameworks**\
  - **Metal/MPS** for low-level cost functions and transforms.\
  - Optional **Core ML** for learned registration or initialization (volume-level AI).\
- **Our mapping (planned)**\
  - `Processing/GPU/RegistrationGPU.swift`\
    - Container for GPU-based registration routines.\
  - Potential future components:\
    - Cost function kernels (SSD, NCC, MI) implemented in Metal.\
    - Transformation application kernels (rigid/affine).\
    - Optional Core ML models for:\
      - Initial alignment guesses.\
      - Deformation field estimation.\
\
For now, registration is explicitly in the **Parking Lot**, but we reserved:\
- The file (`RegistrationGPU.swift`)  \
- The architectural place (GPU-heavy, possibly AI-assisted)\
\
so it can be added later without redesigning the engine.\
\
---\
\
### 16.7 AI / Learned Components\
\
- **ITK concept**\
  - ITK itself is mostly classical; AI/deep learning is usually external.\
- **Apple frameworks**\
  - **Core ML** running on the **Apple Neural Engine (NPU)** when available.\
  - Optional integration with Metal for pre/post-processing.\
- **Our mapping**\
  - Section 14 describes:\
    - Volume-level AI \uc0\u8594  `CIImageVolume`.\
    - Slice-level AI \uc0\u8594  `CIImage2D`.\
    - Study-level AI \uc0\u8594  higher-level aggregations.\
  - Future modules (not yet created) will likely live in:\
    - `AI/` or `AIModule/` (separate package or part of ChromaImagingKit).\
    - Interfaces such as:\
\
      ```swift\
      protocol VolumeSegmentationModel \{\
          func predict(volume: CIImageVolume) async throws -> SegmentationResult\
      \}\
      ```\
\
The philosophy: **classic ITK roles (IO, filters, registration)** are mapped to **Metal/Accelerate/MPS**, while \'93new-school\'94 tasks (segmentation, ranking, classification) live in **Core ML** on the NPU.\
\
---\
\
This MASTER MAP is where you look if you ever catch yourself thinking:\
\
> \'93In ITK, I would use X \'97 what is the Apple-native + ChromaImagingKit equivalent here?\'94\
\
It\'92s all summarized above instead of being scattered across multiple sections.\
\
\
---\
\
## 17. Feature Summary (Engine + App)\
\
This section is a high-level index of capabilities. For detailed responsibilities, ITK mappings, and file-by-file intent, see:\
\
- Sections 2\'964, 13 \'97 ChromaImagingKit layout, implemented pieces, and file responsibilities.  \
- Sections 5, 10\'9611, 16 \'97 DCMTKLoader and ITK \uc0\u8594  Apple framework mapping.  \
- Section 18 \'97 Versioned roadmap (V1.0\'96V1.4).  \
- Section 19 \'97 Engine \uc0\u8594  App wiring checklist.\
\
The goal here is to avoid repeating all details and instead give you a quick overview of \'93what this project does\'94 at a glance.\
\
### 17.1 Engine (ChromaImagingKit) \'97 High-Level Capabilities\
\
Current and planned capabilities of the imaging engine:\
\
- **Core models & infrastructure**\
  - `CIImageVolume`, `CIImage2D`, `SliceOrientation`, `CIMetadata`, `ChromaSpacing`, `ChromaPixelFormat`.\
  - `ChromaContext` for Metal device/queue/library management.\
  - `ChromaError`, `ChromaLogger`, `ChromaDevice` for error handling, logging, and hardware awareness.\
\
- **IO (non-DICOM)**\
  - `ImageLoaderProtocol` / `ImageLoader` as a common interface.\
  - `NIfTILoader` (first real format to implement).\
  - `NRRDLoader`, `MetaImageLoader`, `RAWVolumeLoader`, `PNGLoader` as additional formats.\
  - All of these produce `CIImageVolume` + `CIMetadata`.\
\
- **CPU processing (Accelerate/vDSP/vImage)**\
  - `WindowLevelCPU` \'97 WW/WL via vDSP (implemented).\
  - Planned: `NormalizeCPU`, `HistogramCPU`, `ThresholdCPU`, `ResizeCPU`, `ConvertCPU`.\
  - `vImageUtils` / `MathUtils` to support higher-level CPU ops.\
\
- **GPU processing (Metal + MPS)**\
  - `SliceExtractGPU` + `SliceExtractKernel.metal` \'97 axial/coronal/sagittal slice extraction (implemented).\
  - `WindowLevelGPU` + `WindowLevelKernel.metal` \'97 GPU WW/WL (implemented, to be wired via `ChromaEngine`).\
  - `VolumeResampleGPU`, `VolumeConvolutionGPU` for 3D resampling and convolution (planned).\
  - `MPSGaussian`, `MPSLaplacian`, `MPSSobel` for standard GPU filters using Metal Performance Shaders.\
  - `RegistrationGPU` as the future home for GPU-based registration.\
\
- **Filters (named operations)**\
  - CPU filters: `MedianCPU`, `SmoothCPU`, `SharpenCPU`.\
  - GPU kernels: `Gaussian3D.metal`, `Laplacian3D.metal`, `Sobel3D.metal`.\
\
- **Volume operations**\
  - `VolumeSlicer` \'97 high-level slicing built on `SliceExtractGPU`.\
  - `VolumeMapper` \'97 MIP / projection mapping from 3D to 2D.\
  - `VolumeReducer` \'97 reducers/statistics along axes.\
  - `VolumeInterpolator` and `VolumeOrientation` \'97 interpolation strategies and patient-space orientation.\
\
- **Utilities & AI hooks**\
  - `BufferUtils`, `MetalUtils`, `TimingUtils` for buffer management, Metal boilerplate, and profiling.\
  - Future Core ML / NPU modules operating on `CIImageVolume` and `CIImage2D` (see Section 14).\
\
### 17.2 NeuroMetrica App (Viewer) \'97 High-Level Capabilities\
\
What the app is aiming to provide on top of the engine:\
\
- **Core viewing**\
  - Open volumes from disk (NIfTI first, later NRRD/MetaImage/RAW).\
  - Single-viewport 2D viewer that can show:\
    - Axial, coronal, and sagittal slices.\
    - Slice scrolling via slider/gestures.\
    - Orientation indication (AX/COR/SAG).\
\
- **Window/Level & display**\
  - Manual WW/WL controls (sliders or numeric input).\
  - Auto-window using histogram/percentile logic (via `HistogramCPU`).\
  - Presets for common CT brain windows (brain, blood, bone) as a future layer.\
  - Conversion of `CIImage2D` to `CGImage` and SwiftUI `Image`.\
\
- **Navigation & tools**\
  - Slice index readout (\'93Slice X / N\'94).\
  - Zoom and pan support.\
  - Future basic tools: distance measurement (using spacing), simple ROIs, basic stats readouts.\
\
- **Advanced views & overlays (future)**\
  - MIP/MPR-like projections using `VolumeMapper` and `VolumeSlicer`.\
  - Registration visualization once `RegistrationGPU` exists.\
  - AI-assisted overlays and segmentation masks powered by Core ML models (Section 14).\
\
### 17.3 DICOM (DCMTKLoader) \'97 High-Level Role\
\
Even though DICOM is intentionally delayed until after the non-DICOM vertical slices (Section 18), its role is:\
\
- Thin Swift package that wraps DCMTK via ObjC++:\
  - `DicomBridge.h` / `.mm` perform the C++ calls.\
  - `DICOMLoader.swift` turns DCMTK data into `CIImageVolume` + `CIMetadata`.\
  - `DICOMStudy.swift` and helpers organize series/studies.\
\
- Integrates with ChromaImagingKit by:\
  - Producing the same `CIImageVolume` and metadata types used by other loaders.\
  - Allowing NeuroMetrica to use a unified display pipeline regardless of whether data came from DICOM or NIfTI/NRRD/etc.\
\
All the low-level details for these components live in earlier sections; this feature summary is meant as the quick \'93what does this project actually do?\'94 overview without repeating every bullet from those sections.\
## 18. Feature Roadmap & Status (V1.0\'96V1.4, Non\uc0\u8209 DICOM)\
\
This section consolidates the **high-level feature list** (Section 17) with a **versioned roadmap** and **implementation status**.  \
\
- `[x]` = implemented in code (at least first pass).  \
- `[ ]` = not implemented yet / only scaffolding exists.\
\
The focus here is on **non\uc0\u8209 DICOM vertical slices**. `DCMTKLoader` and DICOM support remain intentionally for later.\
\
---\
\
### 18.1 V1.0 \'97 First Walking Skeleton Viewer\
\
**Goal:** Load one test volume (NIfTI), view and scroll axial slices with WW/WL.\
\
#### Engine (ChromaImagingKit)\
\
- Core models & infrastructure  \
  - [x] `CIImageVolume`, `CIImage2D`, `SliceOrientation`.  \
  - [x] `ChromaContext` (Metal device/queue/library).  \
\
- Slice extraction & WW/WL  \
  - [x] GPU slice extraction for AX/COR/SAG (`SliceExtractGPU` + `SliceExtractKernel.metal`).  \
  - [x] CPU WW/WL using Accelerate (`WindowLevelCPU`).  \
  - [x] GPU WW/WL path (`WindowLevelGPU` + `WindowLevelKernel.metal`) \'97 **implemented, but not yet used by the app pipeline**.\
\
- IO & display helpers  \
  - [x] Minimal but real `NIfTILoader` that returns `CIImageVolume` + basic spacing metadata (backed by CNifti and tested with `TestVolume.nii.gz`).  \
  - [ ] Helper to convert `CIImage2D` \uc0\u8594  `CGImage` \u8594  SwiftUI `Image`.\
\
#### App (NeuroMetrica)\
\
- ViewerViewModel  \
  - [x] Wire in the now-working `ChromaEngine.loadNIfTI(at:)` + `NIfTILoader` path so that the viewer can open real `.nii/.nii.gz` files instead of fake/demo volumes (via `ChromaEngineBridge.loadNIfTI(from:)` and `ViewerViewModel.loadNIfTIVolume(from:)`).\
  - [x] Hold a `CIImageVolume` loaded via `NIfTILoader` (stored in `ViewerState` and set via `setVolume(_)`).\
  - [x] Track: `SliceOrientation` (currently focused on axial), `currentSliceIndex`, `window`, and `level`.\
  - [x] Call into `ChromaEngine` (through `ChromaEngineBridge.makeSlice`) to produce a display\uc0\u8209 ready `CIImage2D` for axial slices.\
\
- ViewerView  \
  - [x] Display the slice as a SwiftUI `Image` using the shared `CIImage2D \uc0\u8594  CGImage \u8594  Image` helpers; currently verified for axial slices.\
  - [x] Provide a slider for axial slice index (basic scrolling through the Z\uc0\u8209 dimension).\
  - [x] Provide sliders for `window` and `level` that drive `WindowLevelCPU` in the engine (may need tuning, but the end\uc0\u8209 to\u8209 end path is live).\
\
**Success criteria:** You can run the app, open one volume, and smoothly scroll axial slices with WW/WL changes.\
\
At this point, V1.0 is effectively \'93axial\uc0\u8209 only\'94: the vertical slice from NIfTI \u8594  volume \u8594  axial slice \u8594  WW/WL \u8594  SwiftUI image works; COR/SAG support is explicitly deferred to V1.1.\
\
---\
\
### 18.2 V1.1 \'97 Multi\uc0\u8209 Orientation & Smarter WW/WL\
\
**Goal:** Support AX/COR/SAG + basic auto-windowing.\
\
#### Engine (ChromaImagingKit)\
\
- Slice extraction (orientation completeness)  \
  - [x] Axial / coronal / sagittal kernels implemented in `SliceExtractKernel.metal`.  \
- Histogram & normalization  \
  - [ ] `HistogramCPU` to compute basic histogram/min/max for slices or volumes.  \
  - [ ] `NormalizeCPU` groundwork for future contrast tools.\
\
#### App (NeuroMetrica)\
\
- ViewerViewModel  \
  - [ ] Adds `orientation: SliceOrientation` and uses correct slice counts.  \
  - [ ] Uses `HistogramCPU` to implement a simple \'93Auto-window\'94 button (e.g., percentile-based).\
\
- ViewerView  \
  - [ ] Orientation segmented control (AX / COR / SAG).  \
  - [ ] Slice slider adapts to orientation.  \
  - [ ] \'93Auto window\'94 button that calls the histogram-based logic.\
\
**Success criteria:** You can switch orientations, scroll each, and get a reasonable auto-window without hand-tweaking WW/WL.\
\
---\
\
### 18.3 V1.2 \'97 IO Expansion & Viewer UX Polish\
\
**Goal:** Support more file formats and improve UX/interaction.\
\
#### Engine (ChromaImagingKit)\
\
- IO  \
  - [ ] Implement a second volume loader:\
    - `NRRDLoader` **or** `MetaImageLoader`.  \
  - [ ] Expand `RAWVolumeLoader` for dev/debug raw volumes if needed.\
\
- CPU utilities  \
  - [ ] `ResizeCPU` for downsampled previews.  \
  - [ ] `ConvertCPU` for robust float\uc0\u8596 8-bit handling.  \
  - [ ] Refine `BufferUtils` / `MetalUtils` based on real usage.\
\
#### App (NeuroMetrica)\
\
- File handling  \
  - [ ] Basic file picker that can open NIfTI and the second chosen format.  \
\
- Viewer UX  \
  - [ ] Zoom and pan support (gestures/trackpad).  \
  - [ ] Slice index readout (\'93Slice X / N\'94).  \
\
- Error handling  \
  - [ ] Clean error messages for unsupported/failed loads.\
\
**Success criteria:** You can open at least two volume formats and the viewer feels like a usable tool (zoom, pan, slice index, better error behavior).\
\
---\
\
### 18.4 V1.3 \'97 Volume Ops & Projections (MIP/MPR Lite)\
\
**Goal:** Start using the 3D nature of the data, not just single slices.\
\
#### Engine (ChromaImagingKit)\
\
- Volume operations  \
  - [ ] `VolumeMapper` \'97 simple MIP along a chosen axis.  \
  - [ ] `VolumeReducer` \'97 basic reducers (min/max/mean along axes).  \
  - [ ] `VolumeSlicer` \'97 higher-level slicing interface over `SliceExtractGPU`.  \
  - [ ] (Optional) First use of `VolumeResampleGPU` for isotropic resampling if it simplifies projections.\
\
#### App (NeuroMetrica)\
\
- Viewer  \
  - [ ] Mode toggle between \'93Slice\'94 and \'93MIP\'94 views per orientation.  \
  - [ ] Display MIP projection when in MIP mode.\
\
- Performance  \
  - [ ] If needed, keep volume data resident on GPU to avoid re-uploading for MIP.\
\
**Success criteria:** You can flip into a MIP mode and see meaningful 3D projections, with interaction still smooth.\
\
---\
\
### 18.5 V1.4 \'97 Advanced Processing & AI Hooks (No Models Yet)\
\
**Goal:** Add nicer processing tools and define clear AI extension points (without shipping a real model yet).\
\
#### Engine (ChromaImagingKit)\
\
- CPU filters  \
  - [ ] `MedianCPU` implemented for denoising.  \
  - [ ] `SmoothCPU` and `SharpenCPU` implemented for basic slice-level enhancement.\
\
- GPU filters & volume smoothing  \
  - [ ] `Gaussian3D.metal` wired via `VolumeConvolutionGPU` (3D smoothing).  \
  - [ ] Optional Laplacian/Sobel volume filters via `Laplacian3D.metal` / `Sobel3D.metal`.\
\
- WW/WL strategy (CPU vs GPU)  \
  - [x] Maintain `WindowLevelCPU` as the baseline implementation.  \
  - [x] GPU WW/WL (`WindowLevelGPU`) available as an alternative.  \
  - [ ] Add a mode switch in `ChromaEngine.makeSlice` (or equivalent) to choose CPU vs GPU WW/WL.  \
  - [ ] Long-term: make GPU WW/WL the **default** on real devices, with CPU kept as a debug/fallback path.\
\
- Utilities & profiling  \
  - [ ] Flesh out `TimingUtils` to profile hot paths (slice extraction, WW/WL, MIP).  \
  - [ ] Expand `ChromaLogger` for structured debug logs.\
\
- AI hooks  \
  - [ ] Define Core ML\'96style protocols and data types (e.g. `SegmentationResult`, `VolumeSegmentationModel`).  \
  - [ ] Ensure they operate on `CIImageVolume` / `CIImage2D` so they integrate cleanly with the engine.\
\
#### App (NeuroMetrica)\
\
- Viewer tools  \
  - [ ] Dev/debug panel with toggles for:\
    - Median/smooth/sharpen on the current slice.  \
    - CPU vs GPU WW/WL mode (once the switch exists in `ChromaEngine`).  \
\
- Debug overlay  \
  - [ ] Show timing information for key operations (slice, WW/WL, MIP) using `TimingUtils`.  \
\
- AI UI hooks  \
  - [ ] Placeholder \'93Run AI segmentation\'94 button wired to the protocol stubs (no real model yet).  \
  - [ ] Overlay toggle for showing/hiding segmentation masks once they exist.\
\
**Success criteria:** You have a more powerful engine with basic filters, profiling tools, and clearly defined AI extension points, while the app remains responsive and usable.\
\
---\
\
As you implement features, update this section by flipping `[ ]` to `[x]`.  \
Use this roadmap together with **Section 19 (Wiring TODO)** to ensure that engine capabilities and app UI stay aligned.\
\
\
\
## 19. Wiring TODO (Engine \uc0\u8594  App)\
\
This is the checklist to make sure every important engine feature eventually has a corresponding UI control or behavior in NeuroMetrica.  \
Whenever you implement a new feature in ChromaImagingKit, add a line here.  \
When it\'92s wired to the app and used in the viewer, change `[ ]` \uc0\u8594  `[x]`.\
\
### 19.1 Core Display Pipeline\
\
- [x] NIfTILoader \uc0\u8594  \'93Open Volume\'85\'94 in app (SwiftUI `.fileImporter` wired to `ChromaEngineBridge.loadNIfTI(from:)`, including security\u8209 scoped URL access).\
- [x] CIImageVolume + SliceExtractGPU (axial) \uc0\u8594  slice slider in ViewerView (Z\u8209 axis scrolling works; COR/SAG wiring still pending).\
- [x] WindowLevelCPU \uc0\u8594  WW/WL sliders in ViewerView (sliders drive CPU WW/WL for the current axial slice).\
- [x] Utility: CIImage2D \uc0\u8594  CGImage \u8594  SwiftUI Image (implemented via CIImage2D+CGImage.swift in ChromaImagingKit and CIImage2D+Image.swift in the app).\
\
### 19.2 Multi-Orientation & Auto-Window\
\
- [ ] `SliceExtractGPU` (coronal) \uc0\u8594  orientation segmented control (COR).\
- [ ] `SliceExtractGPU` (sagittal) \uc0\u8594  orientation segmented control (SAG).\
- [ ] `HistogramCPU` \uc0\u8594  \'93Auto-window\'94 button.\
- [ ] `NormalizeCPU` (when implemented) \uc0\u8594  optional \'93Normalize\'94 toggle in a dev/debug panel.\
\
### 19.3 IO Expansion (Non-DICOM)\
\
- [ ] `NRRDLoader` \uc0\u8594  allow opening NRRD volumes from the same \'93Open Volume\'85\'94 flow.\
- [ ] `MetaImageLoader` \uc0\u8594  allow opening `.mhd` / `.mha` volumes.\
- [ ] `RAWVolumeLoader` \uc0\u8594  dev-only UI to open RAW volumes with manually entered dimensions/spacing.\
- [ ] `PNGLoader` \uc0\u8594  optional debug/utility path to open 2D PNG or PNG stacks.\
\
### 19.4 Volume Ops & MIP/MPR\
\
- [ ] `VolumeSlicer` (once implemented) \uc0\u8594  used by ViewerViewModel instead of calling `SliceExtractGPU` directly.\
- [ ] `VolumeMapper` (MIP) \uc0\u8594  \'93MIP mode\'94 toggle in the viewer for the current orientation.\
- [ ] `VolumeReducer` \uc0\u8594  any UI that needs quick per-volume stats (e.g., \'93Show volume min/max/mean\'94 in a debug overlay).\
\
### 19.5 Filters & Image Tools\
\
- [ ] `MedianCPU` \uc0\u8594  \'93Median filter\'94 toggle or button in the viewer (dev/debug section).\
- [ ] `SmoothCPU` \uc0\u8594  \'93Smooth\'94 toggle/button.\
- [ ] `SharpenCPU` \uc0\u8594  \'93Sharpen\'94 toggle/button.\
- [ ] `Gaussian3D.metal` via `VolumeConvolutionGPU` \uc0\u8594  optional \'933D Smooth (GPU)\'94 toggle for MIP or 3D previews.\
- [ ] `MPSGaussian` / `MPSLaplacian` / `MPSSobel` (when wired) \uc0\u8594  dev/test UI for comparing MPS vs custom kernels.\
\
### 19.6 Performance & Debug\
\
- [ ] `TimingUtils` \uc0\u8594  simple on-screen debug overlay (e.g., \'93Slice: X ms, WW/WL: Y ms, MIP: Z ms\'94).\
- [ ] `ChromaLogger` \uc0\u8594  optional in-app console/log view for dev builds.\
\
### 19.7 AI / NPU Hooks (Future)\
\
These are *future* wiring tasks once AI components exist:\
\
- [ ] `VolumeSegmentationModel` (or similar protocol) \uc0\u8594  \'93Run AI segmentation\'94 button in the viewer.\
- [ ] Segmentation result volume/mask \uc0\u8594  overlay toggle in ViewerView.\
- [ ] Any study-level AI (e.g., auto-layout, suggested key slices) \uc0\u8594  separate \'93AI suggestions\'94 panel in the app.\
\
> Rule of thumb:  \
\
---\
\
## 20. End-of-Document Recap \'97 Where We Left Off\
\
This is a quick \'93end-of-file bookmark\'94 so you don\'92t have to hunt through the document to remember the state of the project.\
\
### 20.1 Current State (Last Time We Worked on This)\
\
- **Workspace and packages** are set up:\
  - `NeuroMetrica` app project (SwiftUI, MVVM).\
  - `ChromaImagingKit` Swift package (engine).\
  - `DCMTKLoader` Swift package (DICOM bridge, to be tackled later).\
- **Engine core pieces implemented**:\
  - `CIImageVolume`, `CIImage2D`, `SliceOrientation` models.\
  - `ChromaContext` (Metal device/queue/library).\
  - GPU slice extraction for AX/COR/SAG:\
    - `SliceExtractGPU` + `SliceExtractKernel.metal`.\
  - CPU WW/WL using Accelerate:\
    - `WindowLevelCPU`.\
  - GPU WW/WL path:\
    - `WindowLevelGPU` + `WindowLevelKernel.metal` (implemented, not yet wired in the main pipeline).\
  - NIfTI IO via CNifti:\
    - CNifti C target (NIfTI-2 + znzlib) is integrated into ChromaImagingKit.\
    - `NIfTILoader` is implemented and converts `NM_NiftiVolume` into `CIImageVolume`.\
    - A SwiftPM unit test (`testNIfTILoadsVolumeMetadata`) verifies that a real `TestVolume.nii.gz` loads and has sensible dimensions.\
- Many additional files in `ChromaImagingKit` and `DCMTKLoader` exist as **scaffolding**:\
  - IO loaders (NIfTI, NRRD, MetaImage, RAW, PNG).\
  - Volume ops (MIP/MPR, resampling).\
  - Filters (CPU + GPU).\
  - Utils, protocols, and DICOM Swift models.\
\
### 20.2 What We Intend to Build Next\
\
If you are resuming after a break, the next concrete steps are:\
\
1. Finish multi\uc0\u8209 orientation support for NIfTI volumes (V1.1): implement and verify true coronal/sagittal slice extraction in `SliceExtractGPU`/`ChromaEngine` and wire COR/SAG through `ViewerViewModel` and `ViewerView` (orientation control + correct slice counts).\
2. Clean up SwiftUI update warnings (\'93Publishing changes from within view updates is not allowed\'94) by tightening where and how `ViewerViewModel` mutates its state (e.g., using explicit `Task`/MainActor boundaries or onChange handlers).\
3. Once axial + COR/SAG are solid and SwiftUI warnings are under control, move to the V1.1/V1.2 roadmap items: auto\uc0\u8209 window via histogram logic, an additional IO format (NRRD or MetaImage), and further viewer UX polish (zoom/pan, clearer slice/spacing readouts).\
\
### 20.3 How to Use This Recap\
\
- When you come back after days or months:\
  - Read **this section** first to remember where things stand.\
  - Then jump to:\
    - Section **18** for the versioned plan (V1.0\'96V1.4).\
    - Section **19** for the wiring checklist between engine and app.\
- After you complete a vertical slice (e.g., finish V1.0 or V1.1), update:\
  - Section **18** (mark what\'92s done).\
  - Section **19** (flip the `[ ]` checkboxes you wired).\
  - Optionally add a short note here about what you just finished, so future-you has a clear anchor.\
\
## 21. NeuroMetrica App Architecture & File Layout (Strict MVVM)\
\
This section describes the **app-side** structure for NeuroMetrica itself, separate from the engine packages (`ChromaImagingKit`, `DCMTKLoader`). The app follows a **strict MVVM + feature modularization**:\
\
- **App layer** \'96 entry points, root container, global navigation.\
- **Core layer** \'96 cross-cutting models/services/utilities used by multiple features.\
- **Features layer** \'96 each user-facing feature (Viewer, Import, Settings, DevTools) has its own Models / ViewModels / Views.\
\
All of this lives under:\
\
```text\
NeuroMetricaWorkspace/\
    NeuroMetrica/\
        NeuroMetrica/       # This folder is the main app target\
            App/\
            Core/\
            Features/\
```\
\
Within that `NeuroMetrica/NeuroMetrica` folder, the current **app file layout** is:\
\
```text\
NeuroMetrica/NeuroMetrica/\
    App/\
        NeuroMetricaApp.swift\
        AppContainer.swift\
\
    Core/\
        Models/\
            AppSettings.swift\
            AppError.swift\
\
        Services/\
            Imaging/\
                ChromaEngineBridge.swift\
            FileSystem/\
                RecentFilesStore.swift\
                FilePickerService.swift\
            Logging/\
                AppLogger.swift\
\
        Utils/\
            Extensions/\
                View+NeuroMetrica.swift\
                Color+NeuroMetrica.swift\
            Helpers/\
                MainThreadExecutor.swift\
\
    Features/\
        Viewer/\
            Models/\
                ViewerState.swift\
            ViewModels/\
                ViewerViewModel.swift\
            Views/\
                ViewerView.swift\
                OrientationControlView.swift\
                SliceNavigationView.swift\
                WWLControlsView.swift\
\
        Import/\
            Models/\
                ImportSource.swift\
            ViewModels/\
                ImportViewModel.swift\
            Views/\
                ImportView.swift\
\
        Settings/\
            ViewModels/\
                SettingsViewModel.swift\
            Views/\
                SettingsView.swift\
\
        DevTools/\
            ViewModels/\
                DebugOverlayViewModel.swift\
            Views/\
                DebugOverlayView.swift\
```\
\
The following subsections describe **what each group of files is for** and how they connect to the imaging engine packages.\
\
### 21.1 App Layer (`App/`)\
\
**Files**\
\
- `NeuroMetricaApp.swift`\
- `AppContainer.swift`\
\
**Responsibilities**\
\
- `NeuroMetricaApp.swift`\
  - The `@main` entry point for the app.\
  - Sets up the root SwiftUI scene.\
  - Creates the top-level `AppContainer` view.\
- `AppContainer.swift`\
  - The **composition root** for the app.\
  - Responsible for building:\
    - Core services (e.g., `ChromaEngineBridge`, `AppLogger`, `RecentFilesStore`).\
    - Initial `ViewerViewModel`, `ImportViewModel`, `SettingsViewModel`, and `DebugOverlayViewModel`.\
  - Injects dependencies into feature view models instead of letting UI code create them ad hoc.\
\
This follows the \'93strict MVVM with composition root\'94 pattern: view models should not talk directly to global singletons; the app layer wires everything up in one place.\
\
### 21.2 Core Layer (`Core/`)\
\
The **Core** layer holds things that are shared between multiple features.\
\
#### 21.2.1 Core Models\
\
- `AppSettings.swift`\
  - Global, app-wide settings (e.g., default window/level presets, preferred orientation, theme, dev toggles).\
  - Intended to be a simple model that can later be persisted (UserDefaults, JSON, etc.).\
- `AppError.swift`\
  - Central error type for app-level failures (file load errors, invalid volume, engine failures).\
  - Viewer, Import, and other features can wrap their specific errors into `AppError` for consistent handling.\
\
#### 21.2.2 Core Services\
\
- `Core/Services/Imaging/ChromaEngineBridge.swift`\
  - Thin service that connects the **app** to **ChromaImagingKit**.\
  - Responsibilities:\
    - Wrap `ChromaEngine` and image loaders (e.g., `NIfTILoader`) into a simple Swift API usable by view models.\
    - Hide low-level details like Metal, buffers, and loader specifics from the app.\
    - Expose methods like:\
      - `loadVolume(from url: URL) -> CIImageVolume`\
      - `makeSlice(volume, orientation, index, window, level) -> CIImage2D`\
    - Later, provide CPU vs GPU WW/WL mode selection (see Sections 9.2 and 18.5).\
\
- `Core/Services/FileSystem/RecentFilesStore.swift`\
  - Tracks recently opened volumes (URLs + metadata).\
  - Intended behavior:\
    - Store a small MRU list.\
    - Later, persist to disk so the app can show \'93Recent studies\'94 on startup.\
\
- `Core/Services/FileSystem/FilePickerService.swift`\
  - Abstracts the platform-specific file picking (DocumentPicker / NSOpenPanel).\
  - View models call this service instead of talking to UIKit/AppKit directly.\
  - Returns selected URLs to the Import feature.\
\
- `Core/Services/Logging/AppLogger.swift`\
  - Central logging facility for the app.\
  - Responsibilities:\
    - Log user actions (open volume, change WW/WL, orientation changes).\
    - Log errors and engine-level issues.\
    - Optionally forward timing info from `TimingUtils` (in ChromaImagingKit) into the DevTools overlay.\
\
#### 21.2.3 Core Utils\
\
- `Core/Utils/Extensions/View+NeuroMetrica.swift`\
  - SwiftUI `View` extensions specific to NeuroMetrica (e.g., common modifiers, debug overlays, standard paddings).\
- `Core/Utils/Extensions/Color+NeuroMetrica.swift`\
  - Color helpers for a consistent UI palette (e.g., brain-theme colors, background/overlay colors).\
- `Core/Utils/Extensions/CIImage2D+Image.swift`\
  - Responsibility: Convert `CIImage2D` (from ChromaImagingKit) into a SwiftUI `Image` using the shared `CIImage2D+CGImage` helper.\
- `Core/Utils/Helpers/MainThreadExecutor.swift`\
  - Helper to ensure UI updates are dispatched on the main thread.\
  - Useful when async engine operations complete on background queues.\
\
Together, these **Core** utilities support all feature modules without making them dependent on each other.\
\
### 21.3 Features Layer (`Features/`)\
\
Each feature has a clear MVVM structure: **Models**, **ViewModels**, and **Views**.\
\
#### 21.3.1 Viewer Feature (`Features/Viewer/`)\
\
**Files**\
\
- `Models/ViewerState.swift`\
- `ViewModels/ViewerViewModel.swift`\
- `Views/ViewerView.swift`\
- `Views/OrientationControlView.swift`\
- `Views/SliceNavigationView.swift`\
- `Views/WWLControlsView.swift`\
\
**Responsibilities**\
\
- `ViewerState.swift`\
  - Holds the current viewer state:\
    - Loaded volume (or `nil` if none).\
    - Current `SliceOrientation` (AX/COR/SAG).\
    - Current slice index and slice count.\
    - Current window and level values.\
    - Optional flags for MIP mode, filter toggles, overlays, etc.\
  - Designed as a plain, immutable-ish model that `ViewerViewModel` owns and publishes.\
\
- `ViewerViewModel.swift`\
  - The brain of the viewer.\
  - Responsibilities:\
    - Own an instance of `ViewerState`.\
    - Talk to `ChromaEngineBridge` to:\
      - Load volumes (non-DICOM first: NIfTI, then others).\
      - Extract slices via `SliceExtractGPU`.\
      - Apply WW/WL via `WindowLevelCPU` (and later GPU).\
    - Produce a display-ready image:\
      - Convert `CIImage2D` \uc0\u8594  `CGImage` \u8594  SwiftUI `Image`.\
    - Handle user actions:\
      - Change orientation.\
      - Move slice slider.\
      - Adjust WW/WL sliders.\
      - Trigger auto-window once histogram logic exists.\
\
- `ViewerView.swift`\
  - Primary SwiftUI view for the imaging viewer.\
  - Responsibilities:\
    - Display the main image.\
    - Embed controls from:\
      - `OrientationControlView`\
      - `SliceNavigationView`\
      - `WWLControlsView`\
    - Bind directly to `ViewerViewModel`\'92s published properties.\
\
- `OrientationControlView.swift`\
  - UI control for selecting orientation (AX / COR / SAG).\
  - Binds to enum in `ViewerViewModel`.\
\
- `SliceNavigationView.swift`\
  - Slice slider and index readout.\
  - Shows \'93Slice X / N\'94.\
  - Binds to slice index and drives re-render through the view model.\
\
- `WWLControlsView.swift`\
  - WW/WL sliders and numeric readouts.\
  - Sends changes to the view model, which in turn runs WW/WL.\
\
This feature is where **NeuroMetrica** meets **ChromaImagingKit** for primary imaging functionality.\
\
#### 21.3.2 Import Feature (`Features/Import/`)\
\
**Files**\
\
- `Models/ImportSource.swift`\
- `ViewModels/ImportViewModel.swift`\
- `Views/ImportView.swift`\
\
**Responsibilities**\
\
- `ImportSource.swift`\
  - Enum or struct describing where data is coming from:\
    - Local file system (NIfTI, NRRD, etc.).\
    - Later: PACS/DICOM sources via `DCMTKLoader`.\
  - Helps the Import flow decide which loader/service to call.\
\
- `ImportViewModel.swift`\
  - Coordinates volume import:\
    - Calls `FilePickerService` to let the user choose a file.\
    - Based on file extension, calls appropriate loader via `ChromaEngineBridge`.\
    - On success, passes the loaded `CIImageVolume` to `ViewerViewModel` (via a shared app state or callback).\
    - On failure, produces `AppError` for the UI.\
\
- `ImportView.swift`\
  - Simple UI for:\
    - \'93Open volume\'85\'94 button.\
    - Listing recent files from `RecentFilesStore`.\
    - Showing status / errors.\
\
In early versions, `ImportView` might be simple or even embedded inside the viewer, but the separate feature module keeps responsibilities clean.\
\
#### 21.3.3 Settings Feature (`Features/Settings/`)\
\
**Files**\
\
- `ViewModels/SettingsViewModel.swift`\
- `Views/SettingsView.swift`\
\
**Responsibilities**\
\
- `SettingsViewModel.swift`\
  - Owns `AppSettings`.\
  - Persists changes via a persistence mechanism (to be implemented).\
  - Exposes toggles and options such as:\
    - Default orientation on load.\
    - Default WW/WL preset.\
    - Whether to use CPU or GPU WW/WL by default (once that option is exposed by `ChromaEngine`).\
    - Developer options (show debug overlay, enable experimental filters).\
\
- `SettingsView.swift`\
  - SwiftUI view for editing settings.\
  - Binds to `SettingsViewModel` and writes back changes.\
\
#### 21.3.4 DevTools Feature (`Features/DevTools/`)\
\
**Files**\
\
- `ViewModels/DebugOverlayViewModel.swift`\
- `Views/DebugOverlayView.swift`\
\
**Responsibilities**\
\
- `DebugOverlayViewModel.swift`\
  - Collects and exposes runtime diagnostics:\
    - Timing data (slice extraction times, WW/WL times, etc.) from `TimingUtils` in ChromaImagingKit.\
    - Recent log messages from `AppLogger`.\
  - Intended mainly for development builds.\
\
- `DebugOverlayView.swift`\
  - SwiftUI overlay view that can be toggled on/off.\
  - Shows:\
    - Operation timings.\
    - Current volume info (dimensions, spacing, etc.).\
    - Recent logs or important warnings.\
\
The DevTools feature is meant to help tune performance and debug complex imaging flows without cluttering the main viewer UI.\
\
### 21.4 How the App Ties to the Engine\
\
At a high level, the flow is:\
\
- **ChromaImagingKit** handles:\
  - Volume models and slices (`CIImageVolume`, `CIImage2D`, `SliceOrientation`).\
  - GPU slice extraction (`SliceExtractGPU`).\
  - CPU and GPU WW/WL (`WindowLevelCPU`, `WindowLevelGPU`).\
  - IO loaders (NIfTI, NRRD, etc., once implemented).\
\
- **NeuroMetrica Core Services** wrap that engine:\
  - `ChromaEngineBridge` exposes a small, app-friendly API for loading volumes and producing processed slices.\
\
- **NeuroMetrica Features** consume those services:\
  - `ImportViewModel` uses file services + `ChromaEngineBridge` to load volumes.\
  - `ViewerViewModel` uses `ChromaEngineBridge` to extract slices and apply WW/WL.\
  - `SettingsViewModel` and `DebugOverlayViewModel` expose configuration and diagnostics that influence how the engine is used.\
\
This keeps the app **UI-focused and testable**, while ChromaImagingKit stays focused on performant imaging code and DCMTKLoader focuses on DICOM-specific IO.\
\
\
\
\
}