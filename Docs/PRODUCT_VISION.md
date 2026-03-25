# Neurometrica – Product Vision

_Last updated: 2025-11-15_

---

## Mission

Neurometrica is a neurosurgery-focused imaging and planning workspace that grows into a platform for AI-driven workflows.  
It’s designed for neurosurgeons, neuroradiologists, and trainees who are used to professional PACS, but want a fast, modern experience on Mac and iPad. Neurometrica bridges clinical DICOM and research formats in one consistent workspace, and is built natively for Apple silicon so advanced imaging, planning, and AI run on-device with clean, minimal UI and behavior that still feels familiar to clinicians.

---

## Target Users

**Primary**

- Neurosurgeons and neurosurgery fellows  
- Neuroradiologists who regularly read brain and spine imaging  
- Neurosurgery / neuroradiology residents and trainees who want a **personal imaging workstation** away from hospital PACS (on their own Mac or iPad)

**Secondary**

- Imaging researchers who work with research volume formats on Mac (e.g., NIfTI and similar)  
- AI / ML researchers building and testing neuro-imaging models on Apple silicon devices  

---

## Core Pain / Motivation

Neurometrica exists because of a specific set of frustrations:

- **You can’t take PACS with you.** Hospital viewers are tied to fixed workstations, VPNs, or clunky remote desktops. There’s no clean, modern **personal neuro imaging workspace** that lives on a clinician’s own Mac or iPad and still feels like a “real” PACS.

- **Clinical and research tools are split.** Clinicians live in DICOM; researchers live in formats like NIfTI and related research volumes. Most tools force people to bounce between multiple apps and UIs instead of working in **one workspace**.

- **Most imaging tools don’t really target Apple silicon.** Many imaging apps on Mac are ports, web front-ends, or legacy UIs. Very few are designed from day one around **Apple silicon**, with imaging and future AI built on top of modern system-level acceleration.

- **Planning and AI are usually bolted on.** Surgery planning, measurements, and AI overlays are often extra modules or separate tools. Neurometrica treats **planning and AI** as core parts of the workspace, not optional add-ons.

---

## Format Support

Neurometrica is designed to handle both **clinical** and **research** imaging formats in one workspace. The long-term goal is to move between PACS studies and research volumes without switching apps.

### Clinical formats (PACS world)

**V1**

- **DICOM**
  - Standard CT/MR brain and spine series
  - Single-series volumetric studies are the initial focus
  - Studies are treated like “personal PACS cases” on a local Mac or iPad

### Research formats

**V1**

- **NIfTI** (`.nii`, `.nii.gz`)
  - Single-volume neuroimaging data (with multi-volume support planned)
  - Intended for common structural/fMRI-style workflows that already export to NIfTI

**Planned post-V1**

- **NRRD**
- **MetaImage (MHD/MHA)**
- **Raw volume data** (when dimensions/spacing are known)
- **PNG slice stacks** for special or legacy workflows

**Philosophy**

- **V1 is explicitly limited to DICOM and NIfTI**, so the first release can be stable and clinically useful.
- Additional research formats will be added incrementally **without changing the core workspace**, so clinicians and researchers can stay in one consistent environment as format support grows.

---

## V1 Focus

For the first releases, Neurometrica focuses on being a **fast, neurosurgery-focused imaging workspace** that clinicians and researchers can both trust.

V1 aims to:

- Open **DICOM brain/spine studies** and **NIfTI volumes** on Apple silicon Macs (and later iPad).
- Provide smooth **axial, coronal, and sagittal** navigation for supported volumes, with clear orientation labels and slice position.
- Offer responsive, clinically familiar **window/level controls** with simple numeric feedback.
- Present essential information (orientation, slice, basic metadata) in a way that feels familiar to people who use professional PACS, while maintaining a **clean, minimal UI** that feels like a native Mac/iPad app rather than a legacy port.

Advanced features—additional formats, multi-volume registration, AI overlays, and richer planning tools—are intentionally scoped for post-V1 releases, so the core experience of “my personal neuro imaging workstation” is strong and reliable first.

---

## V2 Focus (High-Level)

After V1 establishes Neurometrica as a fast, trustworthy imaging workspace, V2 focuses on making it feel like a complete 2D workstation clinicians can plan with.

V2 aims to add three major capability areas on top of V1:

- More professional interaction tools (zoom, pan, fit/reset, drag-based window/level, presets)
- Accurate distance measurements in millimeters
- Clean snapshot export for teaching, notes, and research

Detailed feature breakdowns and checklists for V2 live in a separate release/vertical-slices document.

---