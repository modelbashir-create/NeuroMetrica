//
//  ChromaEngineBridge.swift
//  NeuroMetrica
//
//  Created 2025-12-03
//
//  Core imaging service that sits between the NeuroMetrica app (ViewModels)
//  and the imaging engine packages (ChromaEngineKit / ChromaImagingCore).
//
//  Responsibilities:
//  - Provide a single, VM-friendly API for loading volumes (NIfTI, NRRD, DICOM).
//  - Hide ITK/DCMTK, Metal, and all low-level details.
//  - Provide slice extraction with WW/WL applied.
//  - Own an in-memory registry of loaded volumes, keyed by opaque handles.
//

import Foundation
import ChromaEngineKit       // ChromaEngine + CImageVolume + CIImage2D

// MARK: - Public Types Exposed to ViewModels

/// Logical format of a loaded volume, as seen by the app.
enum VolumeFormat: String {
    case nifti
    case nrrd
    case dicomDirectory   // A directory of DICOM files (typical study/series on disk)
    case dicomFile        // A single DICOM file (e.g., secondary capture)
    case rawStack         // Future: PNG/JPEG stack, etc.
    case unknown
}

/// High-level description of a loaded volume.
struct VolumeDescriptor {
    let handle: VolumeHandle
    let url: URL
    let format: VolumeFormat
    let metadata: CIMetadata
    
    let sizeX: Int
    let sizeY: Int
    let sizeZ: Int
    
    /// Spacing in mm (or whatever ITK/Core reports).
    let spacingX: Double
    let spacingY: Double
    let spacingZ: Double
}

/// Errors that the bridge can throw.
enum ChromaEngineBridgeError: Error, LocalizedError {
    case volumeNotFound
    case unsupportedFormat(URL)
    case notImplemented(String)
    case underlyingEngineError(String)
    
    var errorDescription: String? {
        switch self {
        case .volumeNotFound:
            return "The requested volume handle is no longer available."
        case .unsupportedFormat(let url):
            return "The file at \(url.lastPathComponent) is not a supported medical imaging format."
        case .notImplemented(let feature):
            return "\(feature) is not implemented yet."
        case .underlyingEngineError(let message):
            return message
        }
    }
}

// MARK: - Configuration

/// Controls how the bridge chooses backends for IO and processing.
struct ChromaEngineBridgeConfig {
    enum ProcessingBackend {
        case itkCPU          // ITK filters on CPU
        case nativeCPU       // Native CPU (Accelerate/vDSP)
        case nativeGPU       // Metal/MPS, when appropriate
    }

    var dicomBackend: DicomBackend
    var processingBackend: ProcessingBackend

    static let standard = ChromaEngineBridgeConfig(
        dicomBackend: .dcmtkPreferred,
        processingBackend: .nativeCPU
    )
}

// MARK: - Internal Volume Record

private struct VolumeRecord {
    let handle: VolumeHandle
    let url: URL
    let format: VolumeFormat
    let metadata: CIMetadata
    
    /// The actual engine volume object (from ChromaEngineKit).
    let engineVolume: CImageVolume
    
    /// Metadata pulled from the engine.
    let descriptor: VolumeDescriptor
}

// MARK: - Bridge Actor

/// Actor to serialize access to the underlying engine and volume registry.
actor ChromaEngineBridge {
    
    // MARK: - Properties
    
    private var config: ChromaEngineBridgeConfig
    private var engine: ChromaEngine
    
    private var volumes: [UUID: VolumeRecord] = [:]
    
    // MARK: - Init
    
    init(
        config: ChromaEngineBridgeConfig,
        engine: ChromaEngine = ChromaEngine()
    ) {
        self.config = config
        self.engine = engine
        self.engine.config = ChromaEngineConfig(dicomBackend: config.dicomBackend)
    }

    func updateDicomBackend(_ backend: DicomBackend) {
        config.dicomBackend = backend
        engine.config = ChromaEngineConfig(dicomBackend: backend)
    }

    func updateDicomBackendPreference(_ preference: DicomBackendPreference) {
        let backend: DicomBackend
        switch preference {
        case .dcmtk:
            backend = .dcmtkPreferred
        case .gdcm:
            backend = .gdcm
        }

        updateDicomBackend(backend)
    }
    
    // MARK: - Public API (used by ViewModels)
    
    /// Heuristic loader that infers format from the URL and dispatches to the right loader.
    ///
    /// ViewModels can call this when they only have a `URL` from the file picker.
    func loadVolume(from url: URL) async throws -> VolumeDescriptor {
        let format = inferFormat(from: url)
        
        switch format {
        case .nifti:
            return try await loadNiftiVolume(from: url)
        case .nrrd:
            return try await loadNRRDVolume(from: url)
        case .dicomDirectory, .dicomFile:
            return try await loadDicom(from: url, format: format)
        case .rawStack, .unknown:
            throw ChromaEngineBridgeError.unsupportedFormat(url)
        }
    }
    
    /// Explicit NIfTI loader.
    func loadNiftiVolume(from url: URL) async throws -> VolumeDescriptor {
        do {
            // For now, this uses the ChromaEngine API.
            // Behind the scenes, ChromaImagingCore can use ITK or native IO.
            let engineDescriptor = try await engine.loadNiftiVolume(from: url)
            return registerVolume(
                engineDescriptor,
                url: url,
                format: VolumeFormat.nifti
            )
        } catch {
            throw ChromaEngineBridgeError.underlyingEngineError(error.localizedDescription)
        }
    }
    
    /// Explicit NRRD loader.
    func loadNRRDVolume(from url: URL) async throws -> VolumeDescriptor {
        do {
            let engineDescriptor = try await engine.loadNRRDVolume(from: url)
            return registerVolume(
                engineDescriptor,
                url: url,
                format: VolumeFormat.nrrd
            )
        } catch {
            throw ChromaEngineBridgeError.underlyingEngineError(error.localizedDescription)
        }
    }
    
    func loadDicom(from url: URL, format: VolumeFormat? = nil) async throws -> VolumeDescriptor {
        let dicomFormat: VolumeFormat
        if let explicit = format {
            dicomFormat = explicit
        } else {
            dicomFormat = inferDicomFormat(from: url)
        }

        do {
            let engineDescriptor: EngineVolumeDescriptor
            switch dicomFormat {
            case .dicomDirectory:
                engineDescriptor = try await engine.loadDicomSeries(from: url)
            case .dicomFile:
                engineDescriptor = try await engine.loadDicomFile(from: url)
            default:
                throw ChromaEngineBridgeError.unsupportedFormat(url)
            }

            return registerVolume(
                engineDescriptor,
                url: url,
                format: dicomFormat
            )
        } catch {
            throw ChromaEngineBridgeError.underlyingEngineError(error.localizedDescription)
        }
    }
    
    /// Returns a CIImage2D slice for the given volume with WW/WL applied.
    ///
    /// ViewModels call this, then convert CIImage2D → CGImage → SwiftUI.Image via `CIImage2D+Image`.
    func makeSlice(
        from handle: VolumeHandle,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) async throws -> CIImage2D {
        guard let record = volumes[handle.id] else {
            throw ChromaEngineBridgeError.volumeNotFound
        }
        
        do {
            // In the future, this method can switch between:
            // - ITK CPU WW/WL + reslice
            // - Native CPU WW/WL (WindowLevelCPU)
            // - Native GPU path (Metal/MPS)
            let slice = try await engine.makeSlice(
                from: record.engineVolume,
                orientation: orientation,
                index: index,
                window: window,
                level: level
            )
            return slice
        } catch {
            throw ChromaEngineBridgeError.underlyingEngineError(error.localizedDescription)
        }
    }
    
    /// Clean up a volume when a ViewModel is done with it.
    func unloadVolume(_ handle: VolumeHandle) {
        volumes.removeValue(forKey: handle.id)
    }
    
    /// Optionally return the descriptor for an existing handle (for inspector/overlays).
    func descriptor(for handle: VolumeHandle) -> VolumeDescriptor? {
        volumes[handle.id]?.descriptor
    }
    
    // MARK: - Private Helpers
    
    /// Registers a newly loaded volume in the internal registry and returns its descriptor.
    private func registerVolume(
        _ engineDescriptor: EngineVolumeDescriptor,
        url: URL,
        format: VolumeFormat
    ) -> VolumeDescriptor {
        let handle = VolumeHandle()

        let engineVolume = engineDescriptor.volume
        
        // Extract basic metadata from the engine volume.
        // Adjust these property names to whatever `CImageVolume` exposes.
        let sizeX = engineVolume.sizeX
        let sizeY = engineVolume.sizeY
        let sizeZ = engineVolume.sizeZ
        
        let spacingX = engineVolume.spacingX
        let spacingY = engineVolume.spacingY
        let spacingZ = engineVolume.spacingZ
        
        let descriptor = VolumeDescriptor(
            handle: handle,
            url: url,
            format: format,
            metadata: engineDescriptor.metadata,
            sizeX: sizeX,
            sizeY: sizeY,
            sizeZ: sizeZ,
            spacingX: spacingX,
            spacingY: spacingY,
            spacingZ: spacingZ
        )
        
        let record = VolumeRecord(
            handle: handle,
            url: url,
            format: format,
            metadata: engineDescriptor.metadata,
            engineVolume: engineVolume,
            descriptor: descriptor
        )
        
        volumes[handle.id] = record
        return descriptor
    }
    
    /// Very simple format inference from file extension.
    /// The goal is to be predictable and transparent, not magical.
    private func inferFormat(from url: URL) -> VolumeFormat {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        
        switch ext {
        case "nii":
            return .nifti
        case "nrrd":
            return .nrrd
        case "dcm":
            return .dicomFile
        default:
            if name.hasSuffix(".nii.gz") {
                return .nifti
            }
            // Heuristic: a directory with DICOM files will be treated as `.dicomDirectory`
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return .dicomDirectory
            }
            return .unknown
        }
    }
    
    /// Used when caller specifically wants DICOM, but we need to distinguish file vs dir.
    private func inferDicomFormat(from url: URL) -> VolumeFormat {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return .dicomDirectory
        } else {
            return .dicomFile
        }
    }
}
