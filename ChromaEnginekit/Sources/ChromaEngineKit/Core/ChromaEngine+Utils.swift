//
//  ChromaEngine+Utils.swift
//  ChromaEngineKit
//

import Foundation

// MARK: - Utils

extension ChromaEngine {

    /// Invalidate all cached GPU volumes.
    public func invalidateAllGPUCache() {
        ChromaEngine.sharedMetalService.invalidateAll()
    }

    func fallbackReason(for error: Error) -> String {
        if let metalError = error as? MetalSliceRendererError {
            switch metalError {
            case .metalUnavailable:
                return "gpu_unavailable"
            case .unsupportedComponentsPerPixel:
                return "unsupported_components_per_pixel"
            case .unsupportedComponentType:
                return "unsupported_component_type"
            case .unsupportedOrientation:
                return "unsupported_orientation"
            case .pipelineStateCreationFailed, .functionUnavailable, .libraryUnavailable:
                return "pipeline_unavailable"
            case .outputBufferUnavailable:
                return "output_buffer_unavailable"
            case .commandBufferFailed:
                return "command_buffer_failed"
            case .pipelineUnavailable:
                return "pipeline_unavailable"
            case .notImplemented:
                return "not_implemented"
            }
        }
        return "unknown_error"
    }

    func parseInt(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func parseDouble(_ value: String?) -> Double? {
        guard let value else { return nil }
        return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func parsePixelSpacing(_ value: String?) -> CIPixelSpacing? {
        guard let value else { return nil }
        let components = value
            .replacingOccurrences(of: ",", with: "\\")
            .split(separator: "\\")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard components.count >= 2,
              let row = Double(components[0]),
              let column = Double(components[1]) else {
            return nil
        }
        return CIPixelSpacing(row: row, column: column)
    }

    func formatNumber(_ value: Double) -> String {
        var text = String(format: "%.6f", value)
        while text.contains(".") && text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        if text.isEmpty {
            return "0"
        }
        return text
    }

    func formatNumberArray(_ values: [Double]) -> String {
        values.map { formatNumber($0) }.joined(separator: "\\")
    }
}

// MARK: - Collection helpers

extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
