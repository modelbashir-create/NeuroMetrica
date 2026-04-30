# Neurometrica – Vertical Slices / Release Plan

_Last updated: 2026-04-20_

This document breaks V1 and V2 into concrete, shippable “slices” so it’s clear what needs to be implemented and wired.

---

## Backend Tags

Use these tags to indicate implementation strategy for a feature:

- `[ITK]` = ITK / reference backend only for now
- `[Native]` = Apple-native backend only
- `[ITK -> Native]` = implement in ITK / reference path first, then build the native path later only if it is justified by performance, UX, or product goals

These tags are planning markers. They do not imply that both paths are user-facing at the same time.

Status key: `✅` done, `◐` partially implemented / in progress, `☐` not done yet.

---

## V1 – Core Viewer (DICOM + NIfTI)

Goal: a fast, trustworthy personal neuro imaging workspace that can actually be used to read studies.

### V1.1 – File & Format Support

- ✅ `[ITK]` Open **DICOM** series (CT/MR brain and spine)
- ✅ `[ITK]` Open **NIfTI** volumes (`.nii`, `.nii.gz`)
- ✅ `[ITK]` Basic file open flow from the Mac app for NIfTI volumes (e.g., file menu / open button)
- ✅ `[ITK]` Clear error message when a file cannot be opened or is unsupported

### V1.2 – Viewing & Navigation

- ✅ `[Native]` Single main viewport
- ✅ `[ITK -> Native]` Ability to choose **orientation**: axial / coronal / sagittal (one at a time)
- ✅ `[Native]` **Scroll wheel / trackpad over the image** moves through slices
- ✅ `[Native]` **Arrow keys** move through slices
- ✅ `[Native]` **Slice index display** (e.g. `32 / 188`)

### V1.3 – Image Appearance (WW/WL)

- ✅ `[Native]` **Window** slider
- ✅ `[Native]` **Level** slider
- ✅ `[ITK -> Native]` Image updates in real time when WW/WL changes
- ✅ `[Native]` Numeric **WW/WL readout** visible (e.g. `W: 80  L: 40`)
- ✅ `[ITK -> Native]` Grayscale rendering appropriate to modality (no inverted CT by accident)

### V1.4 – Overlays & Metadata

- ✅ `[Native]` **Orientation labels** on screen (AX / COR / SAG, and later L/R markers)
- ✅ `[ITK]` **Slice position** visible somewhere (index and/or physical position)
- ✅ `[ITK]` Basic **study/series info** visible (modality, study/series description)
- ◐ `[ITK]` Basic **voxel spacing** available in a small info panel or overlay

### V1.5 – Reliability & UX Basics

- ☐ `[Native]` Reasonable performance for typical CT/MR brain volumes on Apple silicon Macs
- ✅ `[Native]` Dark viewer UI that doesn’t distract from the image
- ✅ `[Native]` Clear, non-confusing empty state when no study is loaded
- ✅ `[Native]` If loading fails, the user sees an explanatory message (not just a black screen)

---

## V2 – Complete 2D Workstation (Planning-Ready)

Goal: feels like a serious 2D workstation clinicians can actually plan with, not just scroll.

### V2.1 – Pro Interaction Tools

- ✅ `[Native]` **Zoom** in/out on the image (trackpad gesture or scroll + modifier)
- ✅ `[Native]` **Pan** the image when zoomed (click–drag)
- ✅ `[Native]` **Fit to window** action
- ✅ `[Native]` **Reset view** (zoom + pan back to default)
- ☐ `[ITK -> Native]` **Sync Images** across linked 2D viewports / series when layouts and workflows require it

### V2.2 – WW/WL Behavior Upgrades

- ✅ `[Native]` **Drag-based WW/WL** (e.g. modifier + drag over the image)
- ✅ `[Native]` WW/WL **sliders** and drag interaction stay in sync
- ✅ `[Native]` Simple **WW/WL presets** (e.g. Brain / Bone / Soft Tissue where appropriate)
- ✅ `[Native]` Presets show their numeric values somewhere (not “magic”)

### V2.3 – Measurements & Planning

- ☐ `[ITK -> Native]` **Distance ruler** tool:
  - ☐ `[Native]` Click–drag to place a measurement line
  - ☐ `[ITK]` Distance displayed in **millimeters**, using voxel spacing
  - ☐ `[ITK -> Native]` Works in axial, coronal, and sagittal views
- ☐ `[Native]` **Point** ROI tool
- ☐ `[ITK -> Native]` **Angle** ROI tool
- ☐ `[ITK -> Native]` **Area** ROI tool
- ☐ `[ITK -> Native]` **Closed Path** ROI tool
- ☐ `[Native]` **Curved Line** ROI tool
- ☐ `[Native]` **Text** annotation tool
- ☐ `[Native]` **Arrow** annotation tool
- ☐ `[Native]` **Scribble** annotation tool
- ☐ `[Native]` Easy way to delete/clear measurements
- ☐ `[Native]` Measurements are clearly visible but not visually overwhelming

*(Angle tool and more advanced planning can be V2.x or V3.)*

### V2.4 – Export & Sharing

- ◐ `[Native]` **Export current view** as PNG or JPEG
  - ☐ `[Native]` Includes current WW/WL
  - ☐ `[Native]` Includes current zoom/pan
- ☐ `[Native]` Option to export **with overlays** (orientation, slice, measurements)
- ☐ `[Native]` Option to export **without overlays** (clean image)
- ☐ `[Native]` **Copy image to clipboard** for quick paste into slides/emails

### V2.5 – Study Info Panel

- ◐ `[Native]` Toggle-able **Study Info** panel with:
  - ✅ `[ITK]` Modality
  - ✅ `[ITK]` Study and series description
  - ✅ `[ITK]` Patient ID/name (or anonymized display, depending on mode)
  - ✅ `[ITK]` Study date
  - ◐ `[ITK]` Image matrix size and voxel spacing
- ✅ `[Native]` Info panel layout does not interfere with reading (can be hidden quickly)

### V2.6 – Re-slicing & Projection Tools

- ☐ `[ITK -> Native]` **Post-processing / re-slicing** tool surface for 2D workflows
- ☐ `[ITK -> Native]` Projection controls for **MIP / Mean / MinIP** in slab-style 2D viewing where appropriate
- ☐ `[ITK -> Native]` Adjustable **thick slab** controls for non-curved 2D/MPR viewing

### V2.7 – AI Review & Correction Foundation

Goal: make the viewer capable of hosting the first real local-model and federated-learning workflow before broader AI automation work begins.

- ☐ `[Native]` Display **model output overlays** in 2D and basic MPR workflows
- ☐ `[Native]` Provide a basic **correction / edit workflow** for the first FL task family
- ☐ `[Native]` Save corrected outputs locally in a reusable format
- ☐ `[Native]` Log correction metadata needed for FL ingestion:
  - ☐ `[Native]` case / study identifier
  - ☐ `[Native]` model version
  - ☐ `[Native]` prediction timestamp
  - ☐ `[Native]` correction timestamp
  - ☐ `[Native]` correction type / status

---

## V3A – Advanced MPR & Projection Foundation

Goal: extend the mature 2D workstation into a serious advanced viewing environment with stronger MPR, projection, and slab tools before the full 3D workspace takes over.

### V3A.1 – MPR Maturation

- ◐ `[ITK -> Native]` Mature **3D MPR view** as a first-class viewing mode, not just a transitional scaffold

### V3A.2 – Projection & Slab Modes

- ☐ `[ITK -> Native]` Implement a GPU-capable **MIP** pipeline using `VolumeMapper` / Metal compute where native acceleration is justified
- ☐ `[ITK -> Native]` Support MIP along AX / COR / SAG axes
- ☐ `[ITK -> Native]` Support additional projection modes: **Mean** and **MinIP**
- ☐ `[ITK -> Native]` Integrate WW/WL with projection rendering so presets and sliders affect advanced views as expected
- ☐ `[ITK -> Native]` Support adjustable **thick slab** controls for projection-based views

---

## V3B – 3D Workspace Foundation

Goal: first true 3D-capable release. Introduce a dedicated 3D workspace with familiar OsiriX-style navigation and a basic VR viewer implemented for Apple-silicon acceleration.

### V3B.1 – 3D Modes & Viewer

- ☐ `[Native]` Add a dedicated 3D viewer mode / workspace (enterable from the 2D viewer)
- ☐ `[Native]` Support modes: **Slice**, **MIP**, and **Basic VR** (volume rendering prototype)
- ◐ `[Native]` Clear UI toggle between 2D viewer and 3D viewer

### V3B.2 – 3D Navigation & Camera

- ☐ `[Native]` Rotate the volume in 3D (click–drag / trackpad gesture)
- ☐ `[Native]` Zoom/pan within the 3D viewer
- ☐ `[Native]` Camera presets for standard orientations (Axial / Coronal / Sagittal)
- ☐ `[Native]` Simple orientation widget (e.g. a cube or compass) that reflects camera orientation

### V3B.3 – Basic Volume Rendering (VR Prototype)

- ☐ `[Native]` Implement a first-pass VR renderer (ray casting or similar) on GPU
- ☐ `[Native]` Use a simple transfer function (grayscale + single opacity curve)
- ☐ `[Native]` Add a basic quality vs performance control (e.g. resolution / sampling slider)
- ☐ `[Native]` Ensure VR works interactively on modern Apple silicon Macs

### V3B.4 – Cropping & Performance

- ☐ `[Native]` Add a non-destructive 3D cropping box (limit the rendered region)
- ☐ `[Native]` Keep volume data resident on GPU for 3D modes to reduce upload overhead
- ☐ `[Native]` Establish baseline performance targets for typical CT/MR volumes in 3D

---

## V3C – Curved / Centerline MPR

Goal: build the dedicated curved/centerline workflow and exports that support a centerline-specific publication track and later visionOS expansion.

### V3C.1 – Curved / Centerline Reformatting

- ☐ `[ITK -> Native]` Implement **Curved 3D MPR** / curved planar reformat workflow
- ☐ `[ITK -> Native]` Support **curved path navigation** along a user-defined or model-generated centerline
- ☐ `[ITK -> Native]` Support cross-sectional / transverse slice generation along the curved path
- ☐ `[Native]` Export the **curved planar view** and all associated **transverse slices**

---

## V4 – Advanced 3D Exploration & Editing

Goal: make the 3D environment clinically useful by adding sculpting, “bone removal,” richer transfer functions, 4D time navigation, and simple fusion.

### V4.1 – Sculpting & Masks

- ☐ `[Native]` Add 3D sculpting tools (e.g. scissors/brush) that operate on **masks**, not raw voxel data
- ☐ `[Native]` Add direct **brush** tools for interactive 3D masking / cleanup
- ☐ `[Native]` Support operations like: hide region, keep only region, undo/revert
- ☐ `[ITK -> Native]` Implement preset-based “bone removal” using HU ranges (for CT) via masks
- ☐ `[Native]` Add simple **auto-removal** tools for common cleanup workflows (e.g. bone / table / support structures)
- ☐ `[Native]` Ensure sculpting is non-destructive and can be toggled on/off

### V4.2 – Transfer Functions & 3D Presets

- ☐ `[Native]` Add a **transfer function / CLUT editor** (color + opacity) with a histogram view
- ☐ `[Native]` Support saving/loading 3D rendering presets (VR/MIP settings, transfer function, shading)
- ☐ `[Native]` Group presets by modality / anatomy (e.g. Brain, CTA, Spine)
- ☐ `[Native]` Show presets as thumbnails generated from the current volume pose

### V4.3 – 4D Time & Simple Fusion

- ☐ `[ITK -> Native]` Support 4D volumes (time dimension) in the 3D/MIP viewer
- ☐ `[Native]` Add a time slider and simple cine playback controls for dynamic series
- ☐ `[ITK -> Native]` Implement basic two-volume fusion (e.g. structural + functional) with alpha blending
- ☐ `[Native]` Allow toggling fusion overlays on/off quickly

### V4.4 – 3D Export & Sharing

- ☐ `[Native]` Export short 3D rotations or time sequences as movies (e.g. MP4)
- ☐ `[Native]` Export still 3D snapshots at current camera pose and transfer function
- ☐ `[Native]` Ensure exported media respect current WW/WL, zoom, and overlay settings

---

## V5 – AI, Registration & Smart Workflows

Goal: layer intelligence on top of the mature 2D/3D viewer so Neurometrica competes with high-end workstations through AI, smart presets, and registration-driven fusion.

### V5.1 – AI Segmentation & Overlays

- ☐ `[Native]` Integrate Core ML–based segmentation models for key neuro use cases (e.g. tumor, vessels, structures)
- ☐ `[Native]` Run segmentation on-device using Apple silicon (CPU/GPU/NPU)
- ☐ `[Native]` Display segmentation results as overlays in 2D and 3D viewers
- ☐ `[Native]` Provide clear controls to toggle overlays and adjust opacity

### V5.2 – Registration & Fusion

- ☐ `[ITK -> Native]` Implement rigid/affine volume registration between studies (same patient)
- ☐ `[ITK -> Native]` Allow viewing registered volumes in fused 2D and 3D modes
- ☐ `[ITK -> Native]` Save and re-use registration transforms when possible
- ☐ `[ITK -> Native]` Provide basic tools to inspect registration quality (e.g. checkerboard, edge overlay)

### V5.3 – Automation & Smart Suggestions

- ☐ `[Native]` AI-driven WW/WL and preset recommendations based on modality/anatomy
- ☐ `[Native]` Automatic key-slice / key-timepoint suggestions (e.g. “best axial tumor slice”)
- ☐ `[Native]` Optional smart layout suggestions (e.g. tri-planar layout when appropriate)

### V5.4 – Advanced Export & Sharing

- ☐ `[Native]` Export multi-view cine loops (e.g. tri-planar cine for tumor follow-up)
- ☐ `[Native]` Export annotated images/series with measurements and overlays baked in
- ☐ `[Native]` Consider modern 3D export formats (e.g. USDZ) for sharing 3D scenes outside the app

### V5.5 – Specialty ROI / Clinical Measurements

- ☐ `[ITK -> Native]` **Cobb Angle** measurement tool
- ☐ `[ITK -> Native]` **CTR** measurement tool
- ☐ `[ITK -> Native]` Additional specialty ROI templates as concrete clinical use cases justify them

---

## Parking Lot – Ideas Not Yet Assigned to a Version

These are intentionally **not** assigned to V1–V5 yet, but are part of the longer-term vision if Neurometrica grows and users ask for them.

- Worklists, hanging protocols, reporting, and case management features
- Hospital/network integration (PACS query/retrieve, DICOM routing) if demand justifies it
- Any additional research formats or specialized tools that don’t clearly fit into the existing version buckets yet

---


## Backend Strategy – ITK (with DCMTK) vs Native Engine

Neurometrica uses two complementary “backsides” for all imaging work:

- **ITK + DCMTK (via ChromaImagingCore)** – Portable, CPU-only, reference backend
  - ITK is built as a C++ framework and exposed to Swift via an `ITKBridge`.
  - ITK is compiled **with DCMTK enabled**, so ITK is responsible for **all IO**:
    - DICOM (CT/MR brain and spine, other series) via DCMTK.
    - Research formats such as **NIfTI**, **NRRD**, **MetaImage**, and **RAW** volumes through ITK’s IO stack.
  - All file formats flow through this path; the app and higher-level engine never read medical image files directly.
  - ITK runs on the **CPU** only in this setup – it does not target Metal or the Apple Neural Engine.

- **Native Apple engine (ChromaImagingKit + RedEngine)** – Fast, Apple-optimized backend
  - Written in Swift and Metal, using Accelerate/vDSP, MPS, and Core ML.
  - Operates on neutral volume/slice models produced by the ITK IO layer (e.g. `CIImageVolume` / `CIImage2D`).
  - Responsible for:
    - Real-time WW/WL, slice scrolling, zoom/pan, and 2D rendering.
    - 3D features (MIP, VR, cropping boxes).
    - Filters and advanced volume operations implemented in Metal/MPS.
    - AI/ML features (segmentation, smart suggestions) using Core ML / RedEngine.

**Key rule:**  
- **All IO for all file formats goes through ITK + DCMTK (ChromaImagingCore).**  
- **All interactive viewing, 2D/3D rendering, and AI run through the native Apple engine.**

From a version-planning perspective:

- V1/V2 (2D viewer) always load volumes via ITK IO (DICOM + NIfTI + other formats), then hand the result to the native engine for WW/WL and rendering.
- V3/V4 (3D MIP/VR and advanced tools) assume volumes are already in native engine memory; they depend on the same IO pipeline but do not talk to ITK directly.
- V5 (AI, registration, smart workflows) can mix:
  - ITK as a **reference CPU backend** for registration and some classic filters.
  - Native engine + Core ML as the **fast path** for interactive and AI-heavy features.

## Packages – Implementation Status

### ChromaImagingKit (Engine Swift Package)

#### V1 – Engine foundation for core viewer

- ✅ Core models & data types: `CIImageVolume`, `CIImage2D`, `SliceOrientation`, and basic spacing/pixel format types.
- ✅ GPU / Metal context: shared `ChromaContext` with Metal device, command queue, and libraries.
- ✅ NIfTI support: embedded C NIfTI2 + `znzlib` via `CNifti`, C bridge `NiftiBridge`, `NIfTILoader` for `.nii` / `.nii.gz`, and basic metadata extraction (dimensions, voxel spacing, ndim, timepoints).
- ✅ Slice extraction: GPU-based implementation (`SliceExtractGPU` + Metal kernels) for AX/COR/SAG.
- ✅ Window/level (CPU path): `WindowLevelCPU` using Accelerate.
- ✅ Image conversion helpers: `CIImage2D` → `CGImage` (`CIImage2D+CGImage`) and `CIImage2D` → SwiftUI `Image` (app helper used by the viewer).

#### V2 – Better contrast, normalization, and previews

- ☐ Histogram utilities (e.g. `HistogramCPU`) for auto-window and contrast tools.
- ☐ Normalization utilities (e.g. `NormalizeCPU`) for future contrast/normalization paths.
- ☐ Resize/convert helpers (e.g. `ResizeCPU`, `ConvertCPU`) for previews and 8-bit conversion.

#### V3 – 3D/MIP-ready volume operations and instrumentation

- ✅ GPU window/level implementation (`WindowLevelGPU`) and kernels (present in code, to be tuned/used for 3D/MIP).
- ☐ Volume reduction/mapping (e.g. `VolumeReducer`, `VolumeMapper` for MIP).
- ☐ Higher-level `VolumeSlicer` facade built on top of `SliceExtractGPU`.
- ☐ Second volume format loader (e.g. `NRRDLoader` or `MetaImageLoader`).
- ☐ Optional raw volume loader for dev/debug purposes.
- ☐ Timing utilities (`TimingUtils`) for measuring slice extraction, WW/WL, MIP, etc.
- ☐ Engine-level logging helpers that can be surfaced to the app in a dev/debug overlay.

#### V4 – 3D filters and advanced volume processing

- ☐ 3D convolution helpers (e.g. `VolumeConvolutionGPU` + Gaussian/Laplacian/Sobel kernels).

#### V5 – AI integration

- ☐ Simple protocol types for AI models (e.g. `VolumeSegmentationModel`, `SegmentationResult`).
- ☐ Clear entry points for feeding `CIImageVolume` / `CIImage2D` through Core ML models without leaking engine internals into the app.

### ChromaImagingCore (ITK + DCMTK IO Swift Package)

This package is the **ITK/IO bridge** and the single entry point for reading medical image files into the Neurometrica stack.

#### V1 – Unified IO via ITK + DCMTK

- ✅ Integrate ITK as a C++ framework, exposed to Swift via `ITKBridge.h` / `ITKBridge.mm`.
- ✅ Build ITK **with DCMTK enabled**, so DICOM support is available inside ITK.
- ✅ Provide Swift-facing IO helpers that:
  - Accept a URL or file path.
  - Use ITK (and DCMTK for DICOM) to read the series/volume.
  - Convert the result into neutral engine types (e.g. `CImageVolume` / `CIImageVolume` + metadata).
- ✅ Ensure that **all file formats** go through this package for IO:
  - DICOM (via DCMTK inside ITK).
  - NIfTI (`.nii`, `.nii.gz`).
  - NRRD.
  - MetaImage (`.mhd` / `.mha`).
  - RAW volumes (with external dimension/spacing info).
- ☐ Map ITK/DCMTK metadata (spacing, orientation, study/series info, patient/study date) into shared engine metadata models.
- ☐ Provide clear error types and messages when IO fails (unsupported format, corrupt series, etc.).
- ☐ Add basic tests using small DICOM/NIfTI/NRRD/MetaImage fixtures to confirm that dimensions and spacing round-trip correctly.

#### V2+ – Optional ITK-based processing

Although the primary role of ChromaImagingCore is IO, ITK can also serve as a **reference CPU backend** for some processing tasks:

- ☐ Optional ITK-based filters (e.g. normalization, basic smoothing) exposed behind a strategy layer so they can be compared against native Metal/Accelerate implementations.
- ☐ Optional ITK-based registration routines (rigid/affine) that can be used for correctness and debugging, while the native engine evolves GPU-accelerated registration for real-time use.

In all cases, ITK remains **CPU-only** in this architecture. Any GPU/ANE-accelerated behavior is implemented in the native engine (`ChromaImagingKit` and `RedEngine`) after IO is complete.

## App Layer – V1

Goal: Minimal single-window app that can open a volume (starting with NIfTI) into the viewer and support basic slice navigation and WW/WL.

- ✅ Overall feature module structure exists under `NeuroMetrica/Features` (Import, Settings, Viewer, DevTools).
- ✅ Viewer module folders exist:
  - ✅ `Features/Viewer/Views/`
  - ✅ `Features/Viewer/ViewModels/`
  - ✅ `Features/Viewer/Models/`
- ✅ Core app shell:
  - ✅ `NeuroMetricaApp.swift` launches into the Neurometrica workspace.
  - ✅ `AppContainer.swift` owns shared services (settings, logging, engine bridge).
- ✅ Imaging bridge:
  - ✅ `ChromaEngineBridge.swift` connects the app layer to `ChromaImagingKit` (engine) for volume loading and slice generation.
- ✅ Basic NIfTI open flow:
  - ✅ A file-open mechanism (e.g. SwiftUI `.fileImporter` or equivalent) that accepts `.nii` / `.nii.gz`.
  - ✅ Selected file URLs are passed into a single entry point on `ViewerViewModel` (e.g. `load(url:)`).
- ✅ Viewer state model:
  - ✅ `ViewerState.swift` (or equivalent) exists to hold current volume, slice index, orientation, and WW/WL state.
- ✅ Viewer view model:
  - ✅ `ViewerViewModel.swift` owns the viewer-facing state (current image, slice index, WW/WL, loading state).
  - ✅ Calls into `ChromaEngineBridge` / engine APIs to load NIfTI and generate 2D slices.
  - ✅ Exposes methods like `nextSlice()`, `previousSlice()`, and WW/WL setters.
  - ✅ Uses `MainThreadExecutor` (or equivalent) to ensure UI updates happen on the main thread.
- ✅ Viewer view:
  - ✅ `ViewerView.swift` displays the current slice as a SwiftUI `Image` bound to `ViewerViewModel`.
  - ✅ Shows WW/WL controls (`WWLControlsView`) bound to the view model.
  - ✅ Shows slice index (e.g. `32 / 188`).
  - ☐ Hook up scroll/gesture so changing slices flows through `ViewerViewModel` (trackpad/scroll-wheel over the viewport).
- ✅ Viewer subviews:
  - ✅ `SliceNavigationView.swift` exists and is wired to show and change the current slice index.
  - ✅ `OrientationControlView.swift` exists (orientation may be limited or stubbed in V1 but the control is present).
- ✅ Core utilities:
  - ✅ `MainThreadExecutor.swift` exists and is used where needed to avoid "Publishing changes from within view updates" warnings.
  - ✅ `CIImage2D+Image.swift` converts engine slices into SwiftUI `Image` for display.
- ☐ UX basics:
  - ☐ A clear empty state when no volume is loaded (instead of a confusing black screen).
  - ☐ A simple, visible error path when loading fails (e.g. banner/logged message, not silent failure).

---

## App Layer – V2

Goal: Turn the viewer into a planning-ready 2D workstation with pro interactions, measurements, export, and a study info panel.

- ☐ Zoom & pan behavior:
  - ☐ `ViewerViewModel`: add zoom/pan state and actions (e.g. `zoomIn()`, `zoomOut()`, `resetView()`).
  - ☐ `ViewerView`: add gestures or scroll+modifier to control zoom, and drag to pan.
  - ☐ Ensure "Fit to window" and "Reset view" actions are exposed in the UI.
- ☐ WW/WL drag interaction:
  - ☐ `ViewerView`: support modifier+drag over the image to adjust WW/WL.
  - ☐ `ViewerViewModel`: keep drag-based WW/WL and slider-based WW/WL in sync.
- ☐ WW/WL presets:
  - ☐ Add a small preset model (e.g. enum or struct) for "Brain", "Bone", "Soft Tissue" where appropriate.
  - ☐ UI affordance in the viewer to pick a preset.
  - ☐ Show numeric WW/WL values for each preset so they are not "magic".
- ☐ Measurements:
  - ☐ Create a simple measurement model under `Features/Viewer/Models` (e.g. `Measurement.swift` for distance lines).
  - ☐ `ViewerViewModel`: store active measurements and compute mm using voxel spacing from the engine.
  - ☐ `ViewerView`: add a distance ruler mode (click–drag to place a line with a length label).
  - ☐ Provide a way to clear/delete measurements.
- ☐ Study Info Panel:
  - ☐ Add a new view under `Features/Viewer/Views` (e.g. `StudyInfoPanelView.swift`).
  - ☐ Bind it to metadata from the engine (modality, study/series description, voxel spacing, matrix size, study date).
  - ☐ Provide a toggle in the viewer UI to show/hide the panel.
- ☐ Export & sharing:
  - ☐ Add a small export helper (e.g. `ViewerExportHelper` or similar) responsible for snapshotting the current view.
  - ☐ `ViewerView`: add an "Export…" action to save current view as PNG/JPEG.
  - ☐ Support export **with overlays** (orientation, slice, measurements) and **without overlays**.
  - ☐ Optionally support "Copy image" to clipboard for quick sharing.
- ☐ Settings & defaults:
  - ☐ Use `SettingsView` / `SettingsViewModel` (or extend them) for simple viewer defaults (e.g. default orientation, default WW/WL preset).
- ☐ Dev tools & logging:
  - ☐ Ensure `DebugOverlayView` / `DebugOverlayViewModel` can surface engine debug info (timings, slice indices, errors) when needed in dev builds.

---
