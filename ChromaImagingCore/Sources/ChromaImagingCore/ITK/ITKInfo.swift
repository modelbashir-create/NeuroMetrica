//
//  ITKInfo.swift
//  ChromaImagingCore
//
//  Swift-friendly helpers for querying ITK / bridge metadata.
//

import Foundation
import ITKBridge

/// High-level ITK / bridge information used by the engine and DevTools.
public enum ITKInfo {

    /// Human-readable ITK version string reported by the bridge.
    ///
    /// Falls back to `"ITK (unknown version)"` if anything goes wrong.
    public static func versionString() -> String {
        // The C function from ITKBridge.h:
        //   bool ITKBridgeGetVersionString(char *buffer, int bufferLength);
        //
        // In Swift that’s imported as:
        //   func ITKBridgeGetVersionString(
        //       _ buffer: UnsafeMutablePointer<CChar>!,
        //       _ bufferLength: Int32
        //   ) -> Bool

        let capacity = 256
        var utf8Buffer = [CChar](repeating: 0, count: capacity)

        let ok = ITKBridgeGetVersionString(&utf8Buffer, Int32(capacity))
        guard ok else {
            return "ITK (unknown version)"
        }

        // C string is guaranteed null-terminated if ok == true and capacity > 0.
        return String(cString: utf8Buffer)
    }

    /// Convenience flag used by DevTools / diagnostics.
    public static var isAvailable: Bool {
        let v = versionString().trimmingCharacters(in: .whitespacesAndNewlines)
        return !v.isEmpty && !v.contains("unknown")
    }
}
