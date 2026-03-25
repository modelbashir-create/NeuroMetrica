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
import simd
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
    let imageDataReport: ImageDataReport
    
    let sizeX: Int
    let sizeY: Int
    let sizeZ: Int
    
    /// Spacing in mm (or whatever ITK/Core reports).
    let spacingX: Double
    let spacingY: Double
    let spacingZ: Double

    /// World-space origin (mm) of index (0,0,0).
    let originX: Double
    let originY: Double
    let originZ: Double

    /// Direction cosines as row-major 4x4.
    let direction: [Double]
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

/// Controls how the bridge chooses backends for IO and rendering.
struct ChromaEngineBridgeConfig {
    var dicomBackend: DicomBackend
    var renderingBackend: RenderingBackendPreference

    static let standard = ChromaEngineBridgeConfig(
        dicomBackend: .dcmtkPreferred,
        renderingBackend: .automatic
    )
}

// MARK: - Internal Volume Record

private struct VolumeRecord {
    let handle: VolumeHandle
    let url: URL
    let format: VolumeFormat
    let metadata: CIMetadata
    let imageDataReport: ImageDataReport
    
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
    private var rawSliceCache: [String: CIRawSlice2D] = [:]
    
    // MARK: - Init
    
    init(
        config: ChromaEngineBridgeConfig,
        engine: ChromaEngine = ChromaEngine()
    ) {
        self.config = config
        self.engine = engine
        self.engine.config = ChromaEngineConfig(
            dicomBackend: config.dicomBackend,
            renderingBackend: Self.mapRenderingBackend(config.renderingBackend)
        )
    }

    func updateDicomBackend(_ backend: DicomBackend) {
        config.dicomBackend = backend
        engine.config = ChromaEngineConfig(
            dicomBackend: backend,
            renderingBackend: Self.mapRenderingBackend(config.renderingBackend)
        )
    }

    func updateRenderingBackendPreference(_ preference: RenderingBackendPreference) {
        config.renderingBackend = preference
        engine.config.renderingBackend = Self.mapRenderingBackend(preference)
        invalidateRenderingCaches()
#if DEBUG
        AppLogger.info("ChromaEngineBridge: rendering backend set to \(preference.rawValue)")
#endif
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

    private nonisolated static func mapRenderingBackend(_ preference: RenderingBackendPreference) -> RenderingBackend {
        switch preference {
        case .automatic:
            return .automatic
        case .cpu:
            return .cpu
        case .gpu:
            return .gpu
        }
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
            return await registerVolume(
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
            return await registerVolume(
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

            let descriptor = await registerVolume(
                engineDescriptor,
                url: url,
                format: dicomFormat
            )
            let modality = engineDescriptor.metadata.modality ?? "UNKNOWN"
            await MainActor.run {
                AppLogger.info("DICOM load  succeeded (\(modality)) \(descriptor.sizeX)x\(descriptor.sizeY)x\(descriptor.sizeZ) from \(url.lastPathComponent)")
            }
            return descriptor
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
            return try await engine.makeSlice(
                from: record.engineVolume,
                orientation: orientation,
                index: index,
                window: window,
                level: level
            )
        } catch {
            throw ChromaEngineBridgeError.underlyingEngineError(error.localizedDescription)
        }
    }

    /// Render a slice for a patient-space plane descriptor.
    /// Canonical axial/coronal/sagittal planes are routed through the GPU-capable path.
    func makeSlice(
        from handle: VolumeHandle,
        plane: PatientPlane,
        window: Float,
        level: Float,
        interpolation: MPRInterpolation
    ) async throws -> CIImage2D {
        guard let record = volumes[handle.id] else {
            throw ChromaEngineBridgeError.volumeNotFound
        }

        let volume = record.engineVolume
        if isCanonicalPlane(plane, volume: volume) && interpolation == .linear {
            do {
                return try await engine.makeSlice(
                    from: volume,
                    orientation: plane.orientationHint,
                    index: plane.sliceIndexHint,
                    window: window,
                    level: level
                )
            } catch {
                throw ChromaEngineBridgeError.underlyingEngineError(error.localizedDescription)
            }
        }

        do {
            if interpolation != .linear {
                return try engine.makeSlicePatientSpace(
                    from: volume,
                    orientation: plane.orientationHint,
                    index: plane.sliceIndexHint,
                    window: window,
                    level: level,
                    rescaleSlope: volume.rescaleSlope,
                    rescaleIntercept: volume.rescaleIntercept,
                    interpolation: interpolation
                )
            }
            return try await engine.makeSlice(from: volume, plane: plane, window: window, level: level)
        } catch {
            throw ChromaEngineBridgeError.underlyingEngineError(error.localizedDescription)
        }
    }

    /// Build a canonical axial/coronal/sagittal plane centered on a patient-space point.
    func makeCanonicalPlane(
        for handle: VolumeHandle,
        orientation: SliceOrientation,
        crosshairPoint: SIMD3<Double>
    ) throws -> PatientPlane {
        guard let record = volumes[handle.id] else {
            throw ChromaEngineBridgeError.volumeNotFound
        }

        return Self.makeCanonicalPlane(
            volume: record.engineVolume,
            orientation: orientation,
            crosshairPoint: crosshairPoint
        )
    }

    /// Clamp a patient-space point to the volume bounds.
    func clampPatientPoint(
        for handle: VolumeHandle,
        point: SIMD3<Double>
    ) throws -> SIMD3<Double> {
        guard let record = volumes[handle.id] else {
            throw ChromaEngineBridgeError.volumeNotFound
        }

        return Self.clampPatientPoint(volume: record.engineVolume, point: point)
    }
    
    /// Clean up a volume when a ViewModel is done with it.
    func unloadVolume(_ handle: VolumeHandle) {
        if let record = volumes.removeValue(forKey: handle.id) {
            engine.invalidateGPUCache(for: record.engineVolume)
        }
        let prefix = handle.id.uuidString + "|"
        rawSliceCache = rawSliceCache.filter { !$0.key.hasPrefix(prefix) }
    }
    
    /// Optionally return the descriptor for an existing handle (for inspector/overlays).
    func descriptor(for handle: VolumeHandle) -> VolumeDescriptor? {
        volumes[handle.id]?.descriptor
    }

#if DEBUG
    /// Registers a synthetic volume for unit tests without hitting disk.
    func registerVolumeForTesting(
        volume: CImageVolume,
        metadata: CIMetadata = CIMetadata()
    ) async -> VolumeDescriptor {
        let engineDescriptor = EngineVolumeDescriptor(volume: volume, metadata: metadata)
        return await registerVolume(
            engineDescriptor,
            url: URL(fileURLWithPath: "/tmp/neurometrica_test_volume"),
            format: .unknown
        )
    }
#endif
    
    // MARK: - Private Helpers
    
    /// Registers a newly loaded volume in the internal registry and returns its descriptor.
    private func registerVolume(
        _ engineDescriptor: EngineVolumeDescriptor,
        url: URL,
        format: VolumeFormat
    ) async -> VolumeDescriptor {
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

        let imageDataReport = await MainActor.run {
            ImageDataDiagnostics.report(
                for: engineVolume,
                metadata: engineDescriptor.metadata
            )
        }
        await MainActor.run {
            ImageDataDiagnostics.logReport(imageDataReport)
        }
        
        let descriptor = VolumeDescriptor(
            handle: handle,
            url: url,
            format: format,
            metadata: engineDescriptor.metadata,
            imageDataReport: imageDataReport,
            sizeX: sizeX,
            sizeY: sizeY,
            sizeZ: sizeZ,
            spacingX: spacingX,
            spacingY: spacingY,
            spacingZ: spacingZ,
            originX: engineVolume.originX,
            originY: engineVolume.originY,
            originZ: engineVolume.originZ,
            direction: engineVolume.direction
        )
        
        let record = VolumeRecord(
            handle: handle,
            url: url,
            format: format,
            metadata: engineDescriptor.metadata,
            imageDataReport: imageDataReport,
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

    private func invalidateRenderingCaches() {
        for record in volumes.values {
            engine.invalidateGPUCache(for: record.engineVolume)
        }
        rawSliceCache.removeAll()
    }

    private func rawSliceCacheKey(handle: VolumeHandle, orientation: SliceOrientation, index: Int) -> String {
        "\(handle.id.uuidString)|\(orientation.rawValue)|\(index)"
    }

    private func isCanonicalPlane(_ plane: PatientPlane, volume: CImageVolume) -> Bool {
        let orientation = plane.orientationHint
        let axes = Self.directionColumns(volume: volume)
        let spacing = SIMD3<Double>(volume.spacingX, volume.spacingY, volume.spacingZ)
        let epsilon = 1e-5

        switch orientation {
        case .axial:
            return near(plane.axisU, axes.x, epsilon: epsilon)
                && near(plane.axisV, axes.y, epsilon: epsilon)
                && abs(plane.spacingU - spacing.x) <= epsilon
                && abs(plane.spacingV - spacing.y) <= epsilon
        case .coronal:
            return near(plane.axisU, axes.x, epsilon: epsilon)
                && near(plane.axisV, axes.z, epsilon: epsilon)
                && abs(plane.spacingU - spacing.x) <= epsilon
                && abs(plane.spacingV - spacing.z) <= epsilon
        case .sagittal:
            return near(plane.axisU, axes.y, epsilon: epsilon)
                && near(plane.axisV, axes.z, epsilon: epsilon)
                && abs(plane.spacingU - spacing.y) <= epsilon
                && abs(plane.spacingV - spacing.z) <= epsilon
        }
    }

    private func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>, epsilon: Double) -> Bool {
        abs(a.x - b.x) <= epsilon && abs(a.y - b.y) <= epsilon && abs(a.z - b.z) <= epsilon
    }

    static func makeCanonicalPlane(
        volume: CImageVolume,
        orientation: SliceOrientation,
        crosshairPoint: SIMD3<Double>
    ) -> PatientPlane {
        let axes = directionColumns(volume: volume)
        let direction = directionMatrix(volume: volume)
        let spacing = SIMD3<Double>(volume.spacingX, volume.spacingY, volume.spacingZ)
        let origin = SIMD3<Double>(volume.originX, volume.originY, volume.originZ)

        let index = patientToVoxelIndex(
            direction: direction,
            spacing: spacing,
            origin: origin,
            point: crosshairPoint
        )

        let sizeX = volume.sizeX
        let sizeY = volume.sizeY
        let sizeZ = volume.sizeZ

        let sliceIndex: Int
        switch orientation {
        case .axial:
            sliceIndex = clamp(Int(index.z.rounded()), 0, max(sizeZ - 1, 0))
        case .coronal:
            sliceIndex = clamp(Int(index.y.rounded()), 0, max(sizeY - 1, 0))
        case .sagittal:
            sliceIndex = clamp(Int(index.x.rounded()), 0, max(sizeX - 1, 0))
        }

        let outputWidth: Int
        let outputHeight: Int
        switch orientation {
        case .axial:
            outputWidth = sizeX
            outputHeight = sizeY
        case .coronal:
            outputWidth = sizeX
            outputHeight = sizeZ
        case .sagittal:
            outputWidth = sizeY
            outputHeight = sizeZ
        }

        let planeOrigin: SIMD3<Double>
        let axisU: SIMD3<Double>
        let axisV: SIMD3<Double>
        let spacingU: Double
        let spacingV: Double

        switch orientation {
        case .axial:
            planeOrigin = voxelToPatient(direction: direction, spacing: spacing, origin: origin, index: SIMD3<Double>(0, 0, Double(sliceIndex)))
            axisU = axes.x
            axisV = axes.y
            spacingU = spacing.x
            spacingV = spacing.y
        case .coronal:
            planeOrigin = voxelToPatient(direction: direction, spacing: spacing, origin: origin, index: SIMD3<Double>(0, Double(sliceIndex), 0))
            axisU = axes.x
            axisV = axes.z
            spacingU = spacing.x
            spacingV = spacing.z
        case .sagittal:
            planeOrigin = voxelToPatient(direction: direction, spacing: spacing, origin: origin, index: SIMD3<Double>(Double(sliceIndex), 0, 0))
            axisU = axes.y
            axisV = axes.z
            spacingU = spacing.y
            spacingV = spacing.z
        }

        return PatientPlane(
            origin: planeOrigin,
            axisU: axisU,
            axisV: axisV,
            spacingU: spacingU,
            spacingV: spacingV,
            width: outputWidth,
            height: outputHeight,
            orientationHint: orientation,
            sliceIndexHint: sliceIndex
        )
    }

    static func clampPatientPoint(volume: CImageVolume, point: SIMD3<Double>) -> SIMD3<Double> {
        let direction = directionMatrix(volume: volume)
        let spacing = SIMD3<Double>(volume.spacingX, volume.spacingY, volume.spacingZ)
        let origin = SIMD3<Double>(volume.originX, volume.originY, volume.originZ)
        let maxX = max(volume.sizeX - 1, 0)
        let maxY = max(volume.sizeY - 1, 0)
        let maxZ = max(volume.sizeZ - 1, 0)

        let corners = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(Double(maxX), 0, 0),
            SIMD3<Double>(0, Double(maxY), 0),
            SIMD3<Double>(0, 0, Double(maxZ)),
            SIMD3<Double>(Double(maxX), Double(maxY), 0),
            SIMD3<Double>(Double(maxX), 0, Double(maxZ)),
            SIMD3<Double>(0, Double(maxY), Double(maxZ)),
            SIMD3<Double>(Double(maxX), Double(maxY), Double(maxZ))
        ].map { voxelToPatient(direction: direction, spacing: spacing, origin: origin, index: $0) }

        var minPoint = SIMD3<Double>(Double.greatestFiniteMagnitude,
                                     Double.greatestFiniteMagnitude,
                                     Double.greatestFiniteMagnitude)
        var maxPoint = SIMD3<Double>(-Double.greatestFiniteMagnitude,
                                     -Double.greatestFiniteMagnitude,
                                     -Double.greatestFiniteMagnitude)

        for corner in corners {
            minPoint = SIMD3<Double>(
                min(minPoint.x, corner.x),
                min(minPoint.y, corner.y),
                min(minPoint.z, corner.z)
            )
            maxPoint = SIMD3<Double>(
                max(maxPoint.x, corner.x),
                max(maxPoint.y, corner.y),
                max(maxPoint.z, corner.z)
            )
        }

        return SIMD3<Double>(
            min(max(point.x, minPoint.x), maxPoint.x),
            min(max(point.y, minPoint.y), maxPoint.y),
            min(max(point.z, minPoint.z), maxPoint.z)
        )
    }

    private static func directionMatrix(volume: CImageVolume) -> [[Double]] {
        let d = volume.direction
        return [
            [d[0], d[1], d[2]],
            [d[4], d[5], d[6]],
            [d[8], d[9], d[10]]
        ]
    }

    private static func directionColumns(volume: CImageVolume) -> (x: SIMD3<Double>, y: SIMD3<Double>, z: SIMD3<Double>) {
        let dir = directionMatrix(volume: volume)
        let x = SIMD3<Double>(dir[0][0], dir[1][0], dir[2][0])
        let y = SIMD3<Double>(dir[0][1], dir[1][1], dir[2][1])
        let z = SIMD3<Double>(dir[0][2], dir[1][2], dir[2][2])
        return (x: x, y: y, z: z)
    }

    private static func patientToVoxelIndex(
        direction: [[Double]],
        spacing: SIMD3<Double>,
        origin: SIMD3<Double>,
        point: SIMD3<Double>
    ) -> SIMD3<Double> {
        let inv = invert3x3(direction)
        let relative = point - origin
        let indexContinuous = multiply(inv, relative)
        return SIMD3<Double>(
            indexContinuous.x / spacing.x,
            indexContinuous.y / spacing.y,
            indexContinuous.z / spacing.z
        )
    }

    private static func voxelToPatient(
        direction: [[Double]],
        spacing: SIMD3<Double>,
        origin: SIMD3<Double>,
        index: SIMD3<Double>
    ) -> SIMD3<Double> {
        let scaled = SIMD3<Double>(
            index.x * spacing.x,
            index.y * spacing.y,
            index.z * spacing.z
        )
        let rotated = multiply(direction, scaled)
        return origin + rotated
    }

    private static func multiply(_ matrix: [[Double]], _ vector: SIMD3<Double>) -> SIMD3<Double> {
        let x = matrix[0][0] * vector.x + matrix[0][1] * vector.y + matrix[0][2] * vector.z
        let y = matrix[1][0] * vector.x + matrix[1][1] * vector.y + matrix[1][2] * vector.z
        let z = matrix[2][0] * vector.x + matrix[2][1] * vector.y + matrix[2][2] * vector.z
        return SIMD3<Double>(x, y, z)
    }

    private static func invert3x3(_ matrix: [[Double]]) -> [[Double]] {
        let a = matrix[0][0], b = matrix[0][1], c = matrix[0][2]
        let d = matrix[1][0], e = matrix[1][1], f = matrix[1][2]
        let g = matrix[2][0], h = matrix[2][1], i = matrix[2][2]

        let det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
        if abs(det) < 1e-12 {
            return [
                [1, 0, 0],
                [0, 1, 0],
                [0, 0, 1]
            ]
        }
        let invDet = 1.0 / det
        return [
            [(e * i - f * h) * invDet, (c * h - b * i) * invDet, (b * f - c * e) * invDet],
            [(f * g - d * i) * invDet, (a * i - c * g) * invDet, (c * d - a * f) * invDet],
            [(d * h - e * g) * invDet, (b * g - a * h) * invDet, (a * e - b * d) * invDet]
        ]
    }

    private static func clamp(_ value: Int, _ minValue: Int, _ maxValue: Int) -> Int {
        min(max(value, minValue), maxValue)
    }

}
