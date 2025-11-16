# Neurometrica – Vertical Slices / Release Plan

_Last updated: 2025-11-15_

This document breaks V1 and V2 into concrete, shippable “slices” so it’s clear what needs to be implemented and wired.  
Checkboxes show what’s already working in the current code.

---

## V1 – Core Viewer (DICOM + NIfTI)

Goal: a fast, trustworthy personal neuro imaging workspace that can actually be used to read studies.

### V1.1 – File & Format Support

- [ ] Open **DICOM** series (CT/MR brain and spine)
- [x] Open **NIfTI** volumes (`.nii`, `.nii.gz`)
- [x] Basic file open flow from the Mac app for NIfTI volumes (e.g., file menu / open button)
- [ ] Clear error message when a file cannot be opened or is unsupported

### V1.2 – Viewing & Navigation

- [x] Single main viewport
- [ ] Ability to choose **orientation**: axial / coronal / sagittal (one at a time) with correct reformatting
- [ ] **Scroll wheel / trackpad over the image** moves through slices
- [x] **Arrow keys** move through slices
- [x] **Slice index display** (e.g. `32 / 188`)

### V1.3 – Image Appearance (WW/WL)

- [x] **Window** slider
- [x] **Level** slider
- [x] Image updates in real time when WW/WL changes
- [x] Numeric **WW/WL readout** visible (e.g. `W: 80  L: 40`)
- [x] Grayscale rendering appropriate to modality (no inverted CT by accident)

### V1.4 – Overlays & Metadata

- [ ] **Orientation labels** on screen (AX / COR / SAG, and later L/R markers)
- [x] **Slice position** visible somewhere (index and/or physical position, e.g., `32 / 188`)
- [ ] Basic **study/series info** visible (modality, study/series description)
- [ ] Basic **voxel spacing** available in a small info panel or overlay

### V1.5 – Reliability & UX Basics

- [ ] Reasonable performance checked for typical CT/MR brain volumes on Apple silicon Macs
- [x] Dark viewer UI that doesn’t distract from the image
- [ ] Clear, non-confusing empty state when no study is loaded
- [ ] If loading fails, the user sees an explanatory message (not just a black screen)

---

## V2 – Complete 2D Workstation (Planning-Ready)

Goal: feels like a serious 2D workstation clinicians can actually plan with, not just scroll.

### V2.1 – Pro Interaction Tools

- [ ] **Zoom** in/out on the image (trackpad gesture or scroll + modifier)
- [ ] **Pan** the image when zoomed (click–drag)
- [ ] **Fit to window** action
- [ ] **Reset view** (zoom + pan back to default)

### V2.2 – WW/WL Behavior Upgrades

- [ ] **Drag-based WW/WL** (e.g. modifier + drag over the image)
- [ ] WW/WL **sliders** and drag interaction stay in sync
- [ ] Simple **WW/WL presets** (e.g. Brain / Bone / Soft Tissue where appropriate)
- [ ] Presets show their numeric values somewhere (not “magic”)

### V2.3 – Measurements & Planning

- [ ] **Distance ruler** tool:
  - [ ] Click–drag to place a measurement line
  - [ ] Distance displayed in **millimeters**, using voxel spacing
  - [ ] Works in axial, coronal, and sagittal views
- [ ] Easy way to delete/clear measurements
- [ ] Measurements are clearly visible but not visually overwhelming

*(Angle tool and more advanced planning can be V2.x or V3.)*

### V2.4 – Export & Sharing

- [ ] **Export current view** as PNG or JPEG
  - [ ] Includes current WW/WL
  - [ ] Includes current zoom/pan
- [ ] Option to export **with overlays** (orientation, slice, measurements)
- [ ] Option to export **without overlays** (clean image)
- [ ] **Copy image to clipboard** for quick paste into slides/emails

### V2.5 – Study Info Panel

- [ ] Toggle-able **Study Info** panel with:
  - [ ] Modality
  - [ ] Study and series description
  - [ ] Patient ID/name (or anonymized display, depending on mode)
  - [ ] Study date
  - [ ] Image matrix size and voxel spacing
- [ ] Info panel layout does not interfere with reading (can be hidden quickly)

---

## Parking Lot – Post-V2 Ideas (Not in Scope Yet)

These are intentionally **out of scope** for V1 and V2 but are part of the long-term vision:

- Extra research formats (NRRD, MetaImage, raw volume, PNG stacks)
- Multi-panel / tri-planar layouts (AX/COR/SAG side-by-side with linked crosshair)
- Volume registration (rigid/affine, later deformable)
- AI-driven segmentation, detection, or smart layouts
- Worklists, hanging protocols, reporting, and case management features

---

## Packages – Implementation Status

### ChromaImagingKit (Engine Swift Package)

Core models & data types  
- [x] `CIImageVolume` and `CIImage2D` for 3D volumes and 2D slices  
- [x] `SliceOrientation` enum for axial / coronal / sagittal  
- [x] Basic spacing / pixel format types (e.g. spacing in mm, pixel type)

GPU / Metal context  
- [x] Shared `ChromaContext` that owns the Metal device, command queue, and libraries

NIfTI support  
- [x] Embedded C NIfTI2 + `znzlib` integration via a `CNifti` target  
- [x] C bridge (`NiftiBridge`) exposing a small Swift-friendly API  
- [x] `NIfTILoader` that uses the bridge to load `.nii` / `.nii.gz` into `CIImageVolume`  
- [x] Basic metadata extraction for NIfTI volumes (dimensions, voxel spacing, ndim, timepoints)

Slice extraction & window/level  
- [x] GPU slice extraction implementation (`SliceExtractGPU` + Metal kernels) for AX/COR/SAG  
- [x] CPU window/level implementation (`WindowLevelCPU`) using Accelerate  
- [x] GPU window/level implementation (`WindowLevelGPU`) and kernels (available but not yet the default path)

Image conversion helpers  
- [x] Helper to convert `CIImage2D` into `CGImage` (`CIImage2D+CGImage`)  
- [x] Helper to convert `CIImage2D` into SwiftUI `Image` on the app side (used by the viewer)

Utilities & scaffolding  
- [x] Basic buffer / Metal utility helpers are in place (for creating textures, buffers, etc.)  
- [ ] Histogram utilities (e.g. `HistogramCPU`) for auto-window and contrast tools  
- [ ] Normalization utilities (e.g. `NormalizeCPU`) for future contrast/normalization  
- [ ] Resize/convert helpers (e.g. `ResizeCPU`, `ConvertCPU`) for previews and 8-bit conversion

Additional formats & volume ops (needed for later V1.x / V2 work)  
- [ ] Second volume format loader (e.g. `NRRDLoader` or `MetaImageLoader`)  
- [ ] Optional raw volume loader for dev/debug purposes  
- [ ] Volume reduction/mapping (e.g. `VolumeReducer`, `VolumeMapper` for MIP)  
- [ ] Higher-level `VolumeSlicer` facade built on top of `SliceExtractGPU`  
- [ ] 3D convolution helpers (e.g. `VolumeConvolutionGPU` + Gaussian/Laplacian/Sobel kernels)

Performance & debug  
- [ ] Timing utilities (`TimingUtils`) for measuring slice extraction, WW/WL, MIP, etc.  
- [ ] Engine-level logging helpers that can be surfaced to the app in a dev/debug overlay

AI / NPU hooks  
- [ ] Simple protocol types for future AI models (e.g. `VolumeSegmentationModel`, `SegmentationResult`)  
- [ ] Clear entry points for feeding `CIImageVolume` / `CIImage2D` through Core ML models without leaking engine internals into the app

### DCMTKLoader (DICOM Swift Package)

Package scaffolding  
- [x] DCMTKLoader Swift package added to the workspace  
- [x] Basic bridging setup (`DicomBridge` header/implementation files) connecting Swift to DCMTK C++

DICOM volume loading (needed for V1 DICOM support)  
- [ ] High-level Swift API to load a DICOM series into `CIImageVolume` + metadata  
- [ ] Mapping DICOM metadata into shared engine types (spacing, orientation, study/series/study date)  
- [ ] Pixel data conversion from DCMTK (various pixel formats) into the engine’s volume representation

Error handling & robustness  
- [ ] Clear error types for common DICOM issues (missing slices, inconsistent series, unsupported transfer syntax)  
- [ ] Graceful handling of compressed DICOM where DCMTK is available/configured

Integration with ChromaImagingKit  
- [ ] A clean boundary where DCMTKLoader returns neutral volume + metadata types that ChromaImagingKit can consume  
- [ ] Simple wiring so that the app can choose between NIfTI and DICOM paths without knowing DCMTK internals

Testing  
- [ ] Minimal tests or sample-series checks to confirm DICOM series can be loaded into volumes with correct dimensions and spacing