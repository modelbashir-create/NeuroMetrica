NeuroMetrica is a solo-developed, neurosurgery focused imaging and planning workspace built for Apple silicon (iPad, Mac, and iPhone). The long-term goal is to give clinicians powerful on device AI tools by integrating strong, pre-trained neuroimaging models into a mobile software viewer.
The core design goal is to build a federated learning platform for medical imaging rather than a cloud only model server.
Federated learning:

NeuroMetrica acts as a federated learning client:
* A user loads a CT/MR volume and draws a tumor mask, region of interest, or other segmentation.
* The device slices the volume into tiles and runs raining steps locally on device using those labels.
* The local student model updates its weights, and periodically sends only weight updates (no scans, or PHIs) to a central server runing Nvidia Flare.
* The server aggregates updates from many users into a new global student model and ships updated weights back down via in-app model updates.
https://developer.nvidia.com/blog/effortless-federated-learning-on-mobile-with-nvidia-flare-and-meta-executorch/
Why this approach

1. Distributed training – Training is spread across users’ devices; the server’s main job is aggregation, not heavy compute.
2. Privacy by design** – Raw volumes, DICOMs, and patient identifiers stay on the device. Only ML weight updates are transmitted, which greatly reduces data-sharing risk.
3. Every case helps the next – Each labeled case makes the global model a little better. Users are not just solving their own case; they are continuously improving the tools they will use on their next patient.

Planned teacher models (server-side)

On the server, NeuroMetrica will use a small group of teachers of pre-trained models. A single on-device student model (I call the model Red Eyes) is distilled from these teachers and then updated via federated learning.
Brain MRI
* SynthSeg (https://github.com/BBillot/SynthSeg)
    * Robust brain structure segmentation across scanners, resolutions, and MRI contrasts.
    * Used to supervise:
        * A brain mask head (brain vs non-brain, derived from SynthSeg labels).
        * A brain structures head (multi-class parcellation: GM/WM/CSF + subcortical regions).
* BraTS nnU-Net (pre-trained on BraTS glioma) (https://github.com/mobarakol/nnUNet_BraTS)
    * Brain tumor segmentation (enhancing tumor / tumor core / edema) on multi-sequence MRI.
    * Used to supervise:
        * A dedicated tumor head in the student model.
* VoxelMorph (brain registration) (https://github.com/voxelmorph/voxelmorph)
    * Learned deformable registration between brain volumes (e.g., patient→atlas or pre-op→post-op).
    * Used to supervise:
        * A registration head that predicts deformation fields.
Spine
* Spinal Cord Toolbox (SCT deepseg_sc / deepseg_gm) (https://github.com/sct-pipeline/deepseg-training)
    * Pre-trained deep learning models for spinal cord (and optionally gray matter) segmentation on spine MRI.
    * Used to supervise:
        * A spinal cord head for cervical/thoracic MRIs.
* TotalSegmentator (CT, nnU-Net-based) (https://github.com/wasserth/TotalSegmentator)
    * Multi-organ CT segmentation model that includes vertebrae, ribs, and other bony structures.
    * Used to supervise:
        * A vertebrae head (per-vertebra labels on CT).
        * Optional additional spine/CT heads (e.g., spinal canal, ribs) if needed.
The long-term idea is:
Server: run these heavier teacher models on NVIDIA GPUs, train and refine a single multi-head student. Device: run the compressed student model on iPad/Mac (ExecuTorch + Core ML), keep federated learning always on, and optionally offer cloud “teacher mode” as an opt-in for users who want the strongest possible server-side based results.

Why I’m building this

I’m using NeuroMetrica as a sandbox to experiment, push modern Apple hardware (find a use case for those neural engines), and teach myself more about medical imaging.

DEV JOURNAL/COMMENTS 

Project Update notes:

Update: I: decided on my UI work flow. sketch UI on my Ipad after researching designs and other software, Figma for a quick mockup, then back to swift UI to dial things in before wiring. UI docs will be coming and I will add license information at V2 stage.

Update 2: Calibration per device will be a big challlenge and I dont have the expertise or resources to do that. Eventually I will write a calibration alogrithem that works with colorimeters. Calibration tool will be finished after V2 but before V3 at that point I will buy a cheap calorimeter from amazon to start with, run some tests and see how close to DICOM GSDF calibration can I get on my ipad pro.

Update 3: decided on federated learning flow NVIDIA MONAI for initial traning and flare + flower for deployment of red eyes. Server stuff is not that hard already so many examples. figuring out CoreML backend with exotorch is very new and i need to do some research of flare deployment on ios.

Update 4: I will try to integrate one full feature tumor detection with exotorch core ML backend and Flare server as proof of concept before moving on to V3.

Update 5: Finished designing the iOS app logo and have Icon Composer ready. The icon is inspired by my internal codenames: RedEye for the on-device student model and Brightmind for the server-side teacher model + FLARE pipeline. I’m excited to start the server and model-training work, but I know the app itself needs to mature first—especially the frontend. UI is the hardest part for me: I love Illustrator and Figma, but going from sketch → mockup → SwiftUI implementation → wiring everything together is a grind. To stay sane, I’m taking a systematic approach: finish the UI mockups, then implement them while I work in parallel on Brightmind.

Update 6: I started reasearching old PACS from 90s-2000s to get inspiration. I want things to look and feel modern but also respect the history. I want the application to feel modern yet familiar. I want to see a radiologist or surgeon feel some nostalgia looking at my application. I want them to be reminded of Agfa IMPAX or siemens MagicView from the 90s or the Fuji Synapse PACS from the early 2000s. I pay homage to this heritage through color selection, layout design, translating old toolbar icons to modern animated SF icons. I will channel my inner Jony Ive.

UPDATE 7: I orginally planned on using DCMTK and Nifti library for dicom and nifti support. I have since gone back on that, I scrapped building DCMTK lib for project and instead decided to build ITK for IOS. It required not only custom scripts for each platform IOS, IOS sim, Vision OS, Vision OS sim and Macos but sperate edited source files. Once I add documentation I will add it to a seprate github project or a fork of ITK for apple devices. 

Update 8:  Successfully built a multi-slice ITK.xcframework for macOS/iOS/visionOS (device + simulators) and integrated it to ChromaImagingCore package. I want to limit the use of ITK to IO and simple image operations.In terms of speed well optomized c++ code is as fast if not faster then native swift code with vDSP. I dont think i can do better then ITK in image processing but I will limit my use when it comes to rendering 3D objects or AI tasks that are much better handled by metal and CoreML. Where possible I will aim to use ITK logic and write swift code if something is simple enough. if its not simple But better handled by metal or coreMl I will write native code.


V1 – Core Viewer (DICOM + NIfTI). 
Goal: To read studies.

V1.1 – File & Format Support
*  Open DICOM series (CT/MR brain and spine)
*  Open NIfTI volumes (.nii, .nii.gz)
*  Basic file open flow from the Mac app for NIfTI volumes (e.g., file menu / open button)
*  Clear error message when a file cannot be opened or is unsupported

V1.2 – Viewing & Navigation
*  Single main viewport
*  Ability to choose orientation: axial / coronal / sagittal (one at a time)
*  Scroll wheel / trackpad over the image moves through slices
*  Arrow keys move through slices
*  Slice index display (e.g. 32 / 188)

V1.3 – Image Appearance (WW/WL)
*  Window slider
*  Level slider
*  Image updates in real time when WW/WL changes
*  Numeric WW/WL readout visible (e.g. W: 80 L: 40)
*  Grayscale rendering appropriate to modality (no inverted CT by accident)

V1.4 – Overlays & Metadata
*  Orientation labels on screen (AX / COR / SAG, and later L/R markers)
*  Slice position visible somewhere (index and/or physical position)
*  Basic study/series info visible (modality, study/series description)
*  Basic voxel spacing available in a small info panel or overlay

V1.5 – Reliability & UX Basics
*  Reasonable performance for typical CT/MR brain volumes on Apple silicon Macs
*  Dark viewer UI that doesn’t distract from the image
*  Clear, non-confusing empty state when no study is loaded
*  If loading fails, the user sees an explanatory message (not just a black screen)

V2 – Complete 2D Workstation
Goal: To allow users to plan cases with App. Mid 2026

V2.1 – Pro Interaction Tools
*  Zoom in/out on the image (trackpad gesture or scroll + modifier)
*  Pan the image when zoomed (click–drag)
*  Fit to window action
*  Reset view (zoom + pan back to default)

V2.2 – WW/WL Behavior Upgrades
*  Drag-based WW/WL (e.g. modifier + drag over the image)
*  WW/WL sliders and drag interaction stay in sync
*  Simple WW/WL presets (e.g. Brain / Bone / Soft Tissue where appropriate)
*  Presets show their numeric values somewhere (not “magic”)

V2.3 – Measurements & Planning
*  Distance ruler tool:
    *  Click–drag to place a measurement line
    *  Distance displayed in millimeters, using voxel spacing
    *  Works in axial, coronal, and sagittal views
*  Easy way to delete/clear measurements
*  Measurements are clearly visible but not visually overwhelming
(Angle tool and more advanced planning can be V2.x or V3.)

V2.4 – Export & Sharing
*  Export current view as PNG or JPEG
    *  Includes current WW/WL
    *  Includes current zoom/pan
*  Option to export with overlays (orientation, slice, measurements)
*  Option to export without overlays (clean image)
*  Copy image to clipboard for quick paste into slides/emails

V2.5 – Study Info Panel
*  Toggle-able Study Info panel with:
    *  Modality
    *  Study and series description
    *  Patient ID/name (or anonymized display, depending on mode)
    *  Study date
    *  Image matrix size and voxel spacing
*  Info panel layout does not interfere with reading (can be hidden quickly)

V3 – 3D MIP & VR Foundation 

Goal: first 3D-capable release. Introduce fast GPU-based MIP and a basic VR viewer that feels familiar but implemented with modern Apple-silicon acceleration.



V3.1 – 3D Modes & Viewer
*  Add a dedicated 3D viewer mode / workspace (enterable from the 2D viewer)
*  Support modes: Slice, MIP, and Basic VR (volume rendering prototype)
*  Clear UI toggle between 2D viewer and 3D viewer

V3.2 – 3D Navigation & Camera
*  Rotate the volume in 3D (click–drag / trackpad gesture)
*  Zoom/pan within the 3D viewer
*  Camera presets for standard orientations (Axial / Coronal / Sagittal)
*  Simple orientation widget (e.g. a cube or compass) that reflects camera orientation

V3.3 – MIP Implementation (GPU)
*  Implement a GPU-based MIP pipeline using VolumeMapper / Metal compute
*  Support MIP along AX / COR / SAG axes
*  Integrate WW/WL with MIP rendering so presets and sliders affect 3D as expected

V3.4 – Basic Volume Rendering (VR Prototype)
*  Implement a first-pass VR renderer (ray casting or similar) on GPU
*  Use a simple transfer function (grayscale + single opacity curve)
*  Add a basic quality vs performance control (e.g. resolution / sampling slider)
*  Ensure VR works interactively on modern Apple silicon Macs

V3.5 – Cropping & Performance
*  Add a non-destructive 3D cropping box (limit the rendered region)
*  Keep volume data resident on GPU for 3D modes to reduce upload overhead
*  Establish baseline performance targets for typical CT/MR volumes in 3D

V4 – Advanced 3D Exploration & Editing. 

Goal: make the 3D environment clinically useful by adding sculpting, “bone removal,” richer transfer functions, 4D time navigation, and simple fusion.

V4.1 – Sculpting & Masks
*  Add 3D sculpting tools (e.g. scissors/brush) that operate on masks, not raw voxel data
*  Support operations like: hide region, keep only region, undo/revert
*  Implement preset-based “bone removal” using HU ranges (for CT) via masks
*  Ensure sculpting is non-destructive and can be toggled on/off

V4.2 – Transfer Functions & 3D Presets
*  Add a transfer function editor (color + opacity) with a histogram view
*  Support saving/loading 3D rendering presets (VR/MIP settings, transfer function, shading)
*  Group presets by modality / anatomy (e.g. Brain, CTA, Spine)
*  Show presets as thumbnails generated from the current volume pose

V4.3 – 4D Time & Simple Fusion
*  Support 4D volumes (time dimension) in the 3D/MIP viewer
*  Add a time slider and simple cine playback controls for dynamic series
*  Implement basic two-volume fusion (e.g. structural + functional) with alpha blending
*  Allow toggling fusion overlays on/off quickly

V4.4 – 3D Export & Sharing
*  Export short 3D rotations or time sequences as movies (e.g. MP4)
*  Export still 3D snapshots at current camera pose and transfer function
*  Ensure exported media respect current WW/WL, zoom, and overlay settings

V5 – AI, Registration & Smart Workflows. Mid 2028
Goal: layer intelligence on top of the mature 2D/3D viewer. Allowing users to load their own models and create a reference models for users to learn from.

V5.1 – AI Segmentation & Overlays
*  Integrate Core ML–based segmentation models for key neuro use cases (e.g. tumor, vessels, structures)
*  Run segmentation on-device using Apple silicon (CPU/GPU/NPU)
*  Display segmentation results as overlays in 2D and 3D viewers
*  Provide clear controls to toggle overlays and adjust opacity

V5.2 – Registration & Fusion
*  Implement rigid/affine volume registration between studies (same patient)
*  Allow viewing registered volumes in fused 2D and 3D modes
*  Save and re-use registration transforms when possible
*  Provide basic tools to inspect registration quality (e.g. checkerboard, edge overlay)

V5.3 – Automation & Smart Suggestions
*  AI-driven WW/WL and preset recommendations based on modality/anatomy
*  Automatic key-slice / key-timepoint suggestions (e.g. “best axial tumor slice”)
*  Optional smart layout suggestions (e.g. tri-planar layout when appropriate)

V5.4 – Advanced Export & Sharing
*  Export multi-view cine loops (e.g. tri-planar cine for tumor follow-up)
*  Export annotated images/series with measurements and overlays baked in
*  Consider modern 3D export formats (e.g. USDZ) for sharing 3D scenes outside the app
