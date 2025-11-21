
## NeuroMetrica

NeuroMetrica is a solo-developed, neurosurgery focused imaging and planning workspace built for Apple silicon (iPad, Mac, and  iPhone). The long-term goal is to give clinicians powerful on device AI tools by integrating strong, pre-trained neuroimaging models into a mobile software viewer. 


The core design goal is to build a **federated learning platform** for medical imaging rather than a cloud only model server.

### Federated learning: 

NeuroMetrica acts as a federated learning client:

- A user loads a CT/MR volume and draws a tumor mask, region of interest, or other segmentation.
- The device slices the volume into tiles and runs raining steps locally on device using those labels.
- The local student model updates its weights, and periodically sends only weight updates (no scans, or PHIs) to a central server runing Nvidia Flare. 
- The server aggregates updates from many users into a new global student model and ships updated weights back down via in-app model updates.

https://developer.nvidia.com/blog/effortless-federated-learning-on-mobile-with-nvidia-flare-and-meta-executorch/

### Why this approach

1. Distributed training – Training is spread across users’ devices; the server’s main job is aggregation, not heavy compute.  
2. Privacy by design** – Raw volumes, DICOMs, and patient identifiers stay on the device. Only ML weight updates are transmitted, which greatly reduces data-sharing risk.  
3. Every case helps the next – Each labeled case makes the global model a little better. Users are not just solving their own case; they are continuously improving the tools they will use on their next patient.

---

### Planned teacher models (server-side)

On the server, NeuroMetrica will use a small group of teachers of pre-trained models. A single on-device student model (I call the model Red Eyes) is distilled from these teachers and then updated via federated learning.

**Brain MRI**

- **SynthSeg**  (https://github.com/BBillot/SynthSeg)
  - Robust brain structure segmentation across scanners, resolutions, and MRI contrasts.  
  - Used to supervise:
    - A **brain mask head** (brain vs non-brain, derived from SynthSeg labels).  
    - A **brain structures head** (multi-class parcellation: GM/WM/CSF + subcortical regions).

- **BraTS nnU-Net (pre-trained on BraTS glioma)** (https://github.com/mobarakol/nnUNet_BraTS)
  - Brain tumor segmentation (enhancing tumor / tumor core / edema) on multi-sequence MRI.  
  - Used to supervise:
    - A dedicated **tumor head** in the student model.

- **VoxelMorph (brain registration)**  (https://github.com/voxelmorph/voxelmorph)
  - Learned deformable registration between brain volumes (e.g., patient→atlas or pre-op→post-op).  
  - Used to supervise:
    - A **registration head** that predicts deformation fields.

**Spine**

- **Spinal Cord Toolbox (SCT deepseg_sc / deepseg_gm)**  (https://github.com/sct-pipeline/deepseg-training)
  - Pre-trained deep learning models for spinal cord (and optionally gray matter) segmentation on spine MRI.  
  - Used to supervise:
    - A **spinal cord head** for cervical/thoracic MRIs.

- **TotalSegmentator (CT, nnU-Net-based)**  (https://github.com/wasserth/TotalSegmentator) 
  - Multi-organ CT segmentation model that includes vertebrae, ribs, and other bony structures.  
  - Used to supervise:
    - A **vertebrae head** (per-vertebra labels on CT).  
    - Optional **additional spine/CT heads** (e.g., spinal canal, ribs) if needed.

The long-term idea is:

> **Server:** run these heavier teacher models on NVIDIA GPUs, train and refine a single multi-head student.  
> **Device:** run the compressed student model on iPad/Mac (ExecuTorch + Core ML), keep federated learning always on, and optionally offer cloud “teacher mode” as an opt-in for users who want the strongest possible server-side based results. 

---

#### Why I’m building this

I’m using NeuroMetrica as a sandbox to experiment, push modern Apple hardware (find a use case for those neural engines), and teach myself more about medical imaging. 


Update: I decided on my UI work flow. sketch UI on my Ipad after researching designs and other software, Figma for a quick mockup, then back to swift UI to dial things in before wiring. UI docs will be coming and I will add license information at V2 stage. 

Update 2: Calibration per device will be a big challlenge and I dont have the expertise or resources to do that. Eventually I will write a calibration alogrithem that works with colorimeters. Calibration tool will be finished after V2 but before V3 at that point I will buy a cheap calorimeter from amazon to start with, run some tests and see how close to DICOM GSDF calibration can I get on my ipad pro. 

Update 3: decided on federated learning flow NVIDIA MONAI for initial traning and flare + flower for deployment of red eyes. Server stuff is not that hard already so many examples. figuring out CoreML backend with exotorch is very new and i need to do some research of flare deployment on ios. 

Update 4: I will try to integrate one full feature tumor detection with exotorch core ML backend and Flare server as proof of concept before moving on to V3. 

Update 5: Finished designing the iOS app logo and have Icon Composer ready. The icon is inspired by my internal codenames: RedEye for the on-device student model and Brightmind for the server-side teacher model + FLARE pipeline. I’m excited to start the server and model-training work, but I know the app itself needs to mature first—especially the frontend. UI is the hardest part for me: I love Illustrator and Figma, but going from sketch → mockup → SwiftUI implementation → wiring everything together is a grind. To stay sane, I’m taking a systematic approach: finish the UI mockups, then implement them while I work in parallel on Brightmind.

Update 6: I started reasearching old PACS from 90s-2000s to get inspiration. I want things to look and feel modern but also respect the history. I want the application to feel modern yet familiar. I want to see a radiologist or surgeon feel some nostalgia looking at my application. I want them to be reminded of Agfa IMPAX or siemens MagicView from the 90s or the Fuji Synapse PACS from the early 2000s. I pay homage to this heritage through color selection, layout design, translating old toolbar icons to modern SF icons. I will channel my inner Jony Ive. 




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

## V5 – AI, Registration & Smart Workflows. Mid 2028 

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




![Neurometica ICON PREPROCESSED](https://github.com/user-attachments/assets/3ae5622c-139b-43d1-9027-1ac8cb02724c)<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1025.06 1025.06">
  <defs>
    <style>
      .cls-1 {
        fill: #4f4f4f;
        mix-blend-mode: difference;
      }

      .cls-2 {
        fill: #606060;
      }

      .cls-3 {
        isolation: isolate;
      }

      .cls-4 {
        fill: #009aff;
      }

      .cls-5 {
        fill: #fff;
      }

      .cls-6 {
        fill: #ffd85a;
      }

      .cls-7 {
        fill: #ff2d55;
      }
    </style>
  </defs>
  <g class="cls-3">
    <g id="Background">
      <rect class="cls-4" x=".53" y=".53" width="1024" height="1024"/>
    </g>
    <g id="_1_Layer" data-name="1 – Layer">
      <path class="cls-5" d="M148.23,387.06c6.47-9.31,9.86-18.05,9.32-29.86-3.21-69.88,42.61-137.23,118.14-145.49,8.46-.93,13.1-5.16,17.23-12.4,17.61-30.85,41.84-54.52,76.15-66.31,20.45-7.03,41.55-8.3,62.99-6.71,37.47,2.78,61.88,28.34,62,65.73.13,39.29-.12,78.57-.09,117.86.01,15.02,5.49,21.5,17.66,21.58,12.17.08,17.96-6.52,17.99-21.26.06-40.23.6-80.48-.31-120.7-.92-40.96,30.02-59.79,58.32-62.83,63.52-6.82,112.48,16.9,143.84,73.67,3.55,6.42,8.16,10.23,15.25,10.93,79.71,7.86,123.45,81.07,119.66,147.24-.74,12.99,3.63,22.13,10.2,32.35,42,65.3,49.05,132.41,8.2,201.19-3.8,6.39-4.95,12.5-4.48,19.99,3.56,57.42-11.28,107.92-58.68,144.39-13.45,10.35-23.8,21.95-31.89,36.86-15.74,29.03-38.51,52.59-69.09,64.91-44.03,17.74-89.23,21.68-135.01,2.82-30.34-12.5-50.68-32.35-54.42-65.4-2.17-19.18-.3-38.78-1.37-58.12-.05-.96-.05-1.83-.02-2.66h-36.2c-.39,17.42.1,34.86-.17,52.29-.39,25.35-11.78,45.03-31.18,60.94-16.3,13.37-36.28,16.75-56.72,22.59-36.82,7.2-71.29.33-103.68-12.99-33.85-13.91-58.15-40.08-74.11-73.18-4.69-9.72-11.14-16.95-19.77-23.26-36.95-27.03-59.75-62.72-62.91-109.11-2.06-30.2.7-61.27-20.82-86.71-.86-1.02-1.13-2.58-1.53-3.94-17.98-62-11.84-120.6,25.49-174.4Z"/>
    </g>
    <g id="App_Icon_Shape" data-name="App Icon Shape">
      <path class="cls-2" d="M.53.53v1024h1024V.53H.53ZM1024.53,651.53c0,14.24,0,28.48-.08,42.73-.07,12-.21,23.99-.53,35.98-.71,26.13-2.25,52.49-6.89,78.34-4.71,26.22-12.4,50.62-24.53,74.44-11.92,23.41-27.49,44.84-46.07,63.41s-40,34.15-63.41,46.07c-23.82,12.12-48.22,19.82-74.44,24.53-25.84,4.65-52.2,6.18-78.34,6.89-11.99.33-23.99.46-35.98.53-14.24.09-28.48.08-42.73.08h-278c-14.24,0-28.48,0-42.73-.08-12-.07-23.99-.21-35.98-.53-26.13-.71-52.49-2.25-78.34-6.89-26.22-4.71-50.62-12.4-74.44-24.53-23.41-11.92-44.84-27.49-63.41-46.07s-34.15-40-46.07-63.41c-12.12-23.82-19.82-48.22-24.53-74.44-4.65-25.84-6.18-52.2-6.89-78.34-.33-11.99-.46-23.99-.53-35.98-.09-14.24-.08-28.48-.08-42.73v-278c0-14.24,0-28.48.08-42.73.07-12,.21-23.99.53-35.98.71-26.13,2.25-52.49,6.89-78.34,4.71-26.22,12.4-50.62,24.53-74.44,11.92-23.41,27.49-44.84,46.07-63.41s40-34.15,63.41-46.07c23.82-12.12,48.22-19.82,74.44-24.53,25.84-4.65,52.2-6.18,78.34-6.89,11.99-.33,23.99-.46,35.98-.53,14.24-.09,28.48-.08,42.73-.08h278c14.24,0,28.48,0,42.73.08,12,.07,23.99.21,35.98.53,26.13.71,52.49,2.25,78.34,6.89,26.22,4.71,50.62,12.4,74.44,24.53,23.41,11.92,44.84,27.49,63.41,46.07s34.15,40,46.07,63.41c12.12,23.82,19.82,48.22,24.53,74.44,4.65,25.84,6.18,52.2,6.89,78.34.33,11.99.46,23.99.53,35.98.09,14.24.08,28.48.08,42.73v278Z"/>
    </g>
    <g id="_2_Layer" data-name="2 – Layer">
      <g>
        <path class="cls-1" d="M576.06,291.23c21.27-23.29,46.87-39.03,78.92-46.16,16.97-2.74,32.81-4.54,48.85-1.52,6.45,1.21,12.42,2.97,17.36,7.37,6.61,5.9,8.07,13.34,4.79,21.2-3.12,7.5-9.36,11.01-17.6,10.23-12.23-1.14-24.23-4.72-36.77-2.7-25.32,4.05-46.71,15.11-63.84,34.32-2.97,3.32-5.16,7.5-10.04,8.9-9.1,2.62-20.21,4.41-24.99-3.74-4.69-7.99-4.64-19.19,3.33-27.91Z"/>
        <path class="cls-1" d="M308.27,248.01c45.28-15.8,113.77,6.17,142.05,44.83,6.53,8.93,6.06,19.66,1.26,28.23-4.13,7.38-23.52,4.72-30.67-3.6-17.4-20.26-38.65-33.21-65.21-37.58-11.66-1.91-22.83.08-34.14,1.86-9.05,1.43-18.29,1.83-22.43-8.19-4.14-9.99-1.41-18.89,9.13-25.55Z"/>
        <path class="cls-1" d="M259.95,443.05c6.72-46.65,50.85-84.78,96.45-83.55,34.84.93,66.92,27.36,80.7,66.61,1.52,4.32,2.69,8.75,3.82,13.18,3.01,11.82-.69,21.07-11.82,26.14-10.77,4.91-23.43-.32-28.42-12.25-3.54-8.46-7.44-16.59-12.56-24.13-14.14-20.79-41.88-31.33-65.53-9.4-9.37,9.72-15.49,20.22-20.09,31.86-3.64,9.2-10.62,14.75-21.08,14.63-9.75-.12-16.56-4.83-20.07-13.82-1.13-2.85-1.83-6.29-1.4-9.26Z"/>
        <path class="cls-1" d="M706.75,610.85c-22.76,36.84-53.5,64.47-93.01,82.58-23.45,10.74-36.89,17.12-70.76,20.34-23.75,2.85-56.66.2-60.11,0-44.05-2.64-86.33-19.33-121.77-45.7-22.26-16.56-38.16-39.02-56.2-59.91-4.05,1.45-7.8,3.15-11.72,4.14-17.09,4.28-34.38,6.82-51.2-.39-9.3-3.98-14.48-11.97-11.91-22.24,2.33-9.32,9.42-15.54,19.25-14.26,27.24,3.55,50.28-3.13,69.15-23.84,4.88-5.36,12.03-9.12,19.88-5.22,7.37,3.67,12.49,9.81,13.14,18.15.73,9.17-7.65,13.82-12.02,20.26,25.64,40.91,71.08,71.89,121.54,84.06,79.63,19.19,169.84-15.56,208.7-81.91,8.59-14.65,21.63-17.51,33.71-9.52,11.94,7.91,12.84,18.07,3.33,33.45Z"/>
        <path class="cls-1" d="M576.06,291.23c21.27-23.29,46.87-39.03,78.92-46.16,16.97-2.74,32.81-4.54,48.85-1.52,6.45,1.21,12.42,2.97,17.36,7.37,6.61,5.9,8.07,13.34,4.79,21.2-3.12,7.5-9.36,11.01-17.6,10.23-12.23-1.14-24.23-4.72-36.77-2.7-25.32,4.05-46.71,15.11-63.84,34.32-2.97,3.32-5.16,7.5-10.04,8.9-9.1,2.62-20.21,4.41-24.99-3.74-4.69-7.99-4.64-19.19,3.33-27.91Z"/>
        <path class="cls-1" d="M308.27,248.01c45.28-15.8,113.77,6.17,142.05,44.83,6.53,8.93,6.06,19.66,1.26,28.23-4.13,7.38-23.52,4.72-30.67-3.6-17.4-20.26-38.65-33.21-65.21-37.58-11.66-1.91-22.83.08-34.14,1.86-9.05,1.43-18.29,1.83-22.43-8.19-4.14-9.99-1.41-18.89,9.13-25.55Z"/>
        <path class="cls-1" d="M259.95,443.05c6.72-46.65,50.85-84.78,96.45-83.55,34.84.93,66.92,27.36,80.7,66.61,1.52,4.32,2.69,8.75,3.82,13.18,3.01,11.82-.69,21.07-11.82,26.14-10.77,4.91-23.43-.32-28.42-12.25-3.54-8.46-7.44-16.59-12.56-24.13-14.14-20.79-41.88-31.33-65.53-9.4-9.37,9.72-15.49,20.22-20.09,31.86-3.64,9.2-10.62,14.75-21.08,14.63-9.75-.12-16.56-4.83-20.07-13.82-1.13-2.85-1.83-6.29-1.4-9.26Z"/>
        <path class="cls-1" d="M706.75,610.85c-22.76,36.84-53.5,64.47-93.01,82.58-23.45,10.74-36.89,17.12-70.76,20.34-23.75,2.85-56.66.2-60.11,0-44.05-2.64-86.33-19.33-121.77-45.7-22.26-16.56-38.16-39.02-56.2-59.91-4.05,1.45-7.8,3.15-11.72,4.14-17.09,4.28-34.38,6.82-51.2-.39-9.3-3.98-14.48-11.97-11.91-22.24,2.33-9.32,9.42-15.54,19.25-14.26,27.24,3.55,50.28-3.13,69.15-23.84,4.88-5.36,12.03-9.12,19.88-5.22,7.37,3.67,12.49,9.81,13.14,18.15.73,9.17-7.65,13.82-12.02,20.26,25.64,40.91,71.08,71.89,121.54,84.06,79.63,19.19,169.84-15.56,208.7-81.91,8.59-14.65,21.63-17.51,33.71-9.52,11.94,7.91,12.84,18.07,3.33,33.45Z"/>
      </g>
    </g>
    <g id="_3_Layer" data-name="3 – Layer">
      <path class="cls-6" d="M518.05,382.3c1.07,2.12.96,4.11.73,6.06-1.46,12.3-.61,24.52,1.39,36.74,1.43,8.73,3.58,17.2,8.42,25.08,5.53,9,14.26,15.69,22.68,22.6,12.18,9.98,24.96,19.47,35.81,30.54,6.3,6.44,12.04,13.22,16.11,20.95,4.71,8.94,6.61,18.08,5.6,27.92-1.27,12.42-7.69,22.55-17.94,30.97-8.89,7.3-19.35,12.87-30.57,17.37-14.12,5.66-28.76,10.14-43.72,13.9-3.25.82-6.35,2-9.76,2.49-8.26,1.18-14.72-2.49-16.87-9.57-1.62-5.36,2.64-11.47,9.64-13.54,13.1-3.89,26.42-7.25,39.3-11.65,10.24-3.5,20.02-7.78,28.55-13.77,14.14-9.92,16.9-23.16,7.74-37.15-4.9-7.48-11.53-13.81-18.48-19.93-9.76-8.58-20.23-16.55-30.35-24.82-13.57-11.08-25.21-23.4-30.32-39.16-2.28-7.03-3.62-14.25-5.05-21.46-1.53-7.72-1.36-15.47-1.61-23.15-.23-7.02-.99-14.31,1.5-21.2,1.83-5.06,7.72-8.25,13.38-8.18,6.14.07,11.59,3.53,13.83,8.98Z"/>
    </g>
    <g id="_4_Layer" data-name="4 – Layer">
      <path class="cls-7" d="M785.33,367.83c17.39,39.22,14.19,75.57-12.16,107.99-26.63,32.75-62.84,43.18-102.71,32.91-41.5-10.69-65.91-39.42-72.98-82.29-8.94-54.22,28.81-105.11,83.89-112.68,44.06-6.06,81.25,12.98,103.97,54.07Z"/>
    </g>
  </g>
</svg>




