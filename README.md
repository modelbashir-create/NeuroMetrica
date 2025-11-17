# NeuroMetrica

NeuroMetrica is solo developed neurosurgery focused imaging and planning workspace built for Apple silicon. Eventually I want to provide users with AI tools and allow them to use their own models on device. I am using chatgbt for documentation, UI wiring, scaffolding, debugging, everything I can safely dump on it. 


#### my reasons for attempting this project is to experiment, push modern Apple hardware (find a use case for those NPUs), and teach myself more about medical imaging science. 


In the not so super distant future I envision AI can enable imaging applications to: 

- Compare suggestions and planning stage against what surgeons actually did and what happened to the patient.
- Track patterns where its guidance was helpful, neutral, or wrong, and adjust its internal confidence.
- Use large, de-identified cohorts of real cases and outcomes to recalibrate itself, not just once during training but continuously in realtime. 


Update: I decided on my UI work flow. sketch UI on my Ipad after researching designs and other software, Figma for a quick mockup go, then back to swift UI to dial things in before wiring. UI docs will be coming and I will add license information at V2 stage. 

Update 2: Calibration per device will be a big challlenge and I dont have the expertise or resources to do that. Eventually I will write a calibration alogrithem that works with calorimeters. Calibration tool will be finished after V2 but before V3 at that point I will buy a cheap calorimeter from amazon to start with, run some tests and see how close to DICOM GSDF calibration can I get on my ipad pro. 


## V1 – Core Viewer (DICOM + NIfTI).  ---- End 2025 

Goal: To read studies.

### V1.1 – File & Format Support

- [ ] Open **DICOM** series (CT/MR brain and spine)
- [x] Open **NIfTI** volumes (`.nii`, `.nii.gz`)
- [x] Basic file open flow from the Mac app for NIfTI volumes (e.g., file menu / open button)
- [ ] Clear error message when a file cannot be opened or is unsupported

### V1.2 – Viewing & Navigation

- [x] Single main viewport
- [ ] Ability to choose **orientation**: axial / coronal / sagittal (one at a time)
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
- [x] **Slice position** visible somewhere (index and/or physical position)
- [ ] Basic **study/series info** visible (modality, study/series description)
- [ ] Basic **voxel spacing** available in a small info panel or overlay

### V1.5 – Reliability & UX Basics

- [ ] Reasonable performance for typical CT/MR brain volumes on Apple silicon Macs
- [x] Dark viewer UI that doesn’t distract from the image
- [ ] Clear, non-confusing empty state when no study is loaded
- [ ] If loading fails, the user sees an explanatory message (not just a black screen)

---

## V2 – Complete 2D Workstation 

Goal: To allow users to plan cases with App.  Mid 2026 

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

## V3 – 3D MIP & VR Foundation  end of 2026 

Goal: first 3D-capable release. Introduce fast GPU-based MIP and a basic VR viewer that feels familiar but implemented with modern Apple-silicon acceleration.

### V3.1 – 3D Modes & Viewer

- [ ] Add a dedicated 3D viewer mode / workspace (enterable from the 2D viewer)
- [ ] Support modes: **Slice**, **MIP**, and **Basic VR** (volume rendering prototype)
- [ ] Clear UI toggle between 2D viewer and 3D viewer

### V3.2 – 3D Navigation & Camera

- [ ] Rotate the volume in 3D (click–drag / trackpad gesture)
- [ ] Zoom/pan within the 3D viewer
- [ ] Camera presets for standard orientations (Axial / Coronal / Sagittal)
- [ ] Simple orientation widget (e.g. a cube or compass) that reflects camera orientation

### V3.3 – MIP Implementation (GPU)

- [ ] Implement a GPU-based **MIP** pipeline using `VolumeMapper` / Metal compute
- [ ] Support MIP along AX / COR / SAG axes
- [ ] Integrate WW/WL with MIP rendering so presets and sliders affect 3D as expected

### V3.4 – Basic Volume Rendering (VR Prototype)

- [ ] Implement a first-pass VR renderer (ray casting or similar) on GPU
- [ ] Use a simple transfer function (grayscale + single opacity curve)
- [ ] Add a basic quality vs performance control (e.g. resolution / sampling slider)
- [ ] Ensure VR works interactively on modern Apple silicon Macs

### V3.5 – Cropping & Performance

- [ ] Add a non-destructive 3D cropping box (limit the rendered region)
- [ ] Keep volume data resident on GPU for 3D modes to reduce upload overhead
- [ ] Establish baseline performance targets for typical CT/MR volumes in 3D

---

## V4 – Advanced 3D Exploration & Editing. End 2027/ Q1 2028  

Goal: make the 3D environment clinically useful by adding sculpting, “bone removal,” richer transfer functions, 4D time navigation, and simple fusion.

### V4.1 – Sculpting & Masks

- [ ] Add 3D sculpting tools (e.g. scissors/brush) that operate on **masks**, not raw voxel data
- [ ] Support operations like: hide region, keep only region, undo/revert
- [ ] Implement preset-based “bone removal” using HU ranges (for CT) via masks
- [ ] Ensure sculpting is non-destructive and can be toggled on/off

### V4.2 – Transfer Functions & 3D Presets

- [ ] Add a **transfer function editor** (color + opacity) with a histogram view
- [ ] Support saving/loading 3D rendering presets (VR/MIP settings, transfer function, shading)
- [ ] Group presets by modality / anatomy (e.g. Brain, CTA, Spine)
- [ ] Show presets as thumbnails generated from the current volume pose

### V4.3 – 4D Time & Simple Fusion

- [ ] Support 4D volumes (time dimension) in the 3D/MIP viewer
- [ ] Add a time slider and simple cine playback controls for dynamic series
- [ ] Implement basic two-volume fusion (e.g. structural + functional) with alpha blending
- [ ] Allow toggling fusion overlays on/off quickly

### V4.4 – 3D Export & Sharing

- [ ] Export short 3D rotations or time sequences as movies (e.g. MP4)
- [ ] Export still 3D snapshots at current camera pose and transfer function
- [ ] Ensure exported media respect current WW/WL, zoom, and overlay settings

---

## V5 – AI, Registration & Smart Workflows.  End 2028 

Goal: layer intelligence on top of the mature 2D/3D viewer. Allowing users to load their own models and create a reference models for users to learn from. 

### V5.1 – AI Segmentation & Overlays

- [ ] Integrate Core ML–based segmentation models for key neuro use cases (e.g. tumor, vessels, structures)
- [ ] Run segmentation on-device using Apple silicon (CPU/GPU/NPU)
- [ ] Display segmentation results as overlays in 2D and 3D viewers
- [ ] Provide clear controls to toggle overlays and adjust opacity

### V5.2 – Registration & Fusion

- [ ] Implement rigid/affine volume registration between studies (same patient)
- [ ] Allow viewing registered volumes in fused 2D and 3D modes
- [ ] Save and re-use registration transforms when possible
- [ ] Provide basic tools to inspect registration quality (e.g. checkerboard, edge overlay)

### V5.3 – Automation & Smart Suggestions

- [ ] AI-driven WW/WL and preset recommendations based on modality/anatomy
- [ ] Automatic key-slice / key-timepoint suggestions (e.g. “best axial tumor slice”)
- [ ] Optional smart layout suggestions (e.g. tri-planar layout when appropriate)

### V5.4 – Advanced Export & Sharing

- [ ] Export multi-view cine loops (e.g. tri-planar cine for tumor follow-up)
- [ ] Export annotated images/series with measurements and overlays baked in
- [ ] Consider modern 3D export formats (e.g. USDZ) for sharing 3D scenes outside the app

