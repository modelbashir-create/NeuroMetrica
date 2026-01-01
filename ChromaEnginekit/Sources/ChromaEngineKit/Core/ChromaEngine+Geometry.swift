//
//  ChromaEngine+Geometry.swift
//  ChromaEngineKit
//

import Foundation
import simd

// MARK: - Geometry

extension ChromaEngine {

    func directionColumns(volume: CImageVolume) -> (x: SIMD3<Double>, y: SIMD3<Double>, z: SIMD3<Double>) {
        let dir = directionMatrix(volume: volume)
        let x = SIMD3<Double>(dir[0][0], dir[1][0], dir[2][0])
        let y = SIMD3<Double>(dir[0][1], dir[1][1], dir[2][1])
        let z = SIMD3<Double>(dir[0][2], dir[1][2], dir[2][2])
        return (x: x, y: y, z: z)
    }

    func directionMatrix(volume: CImageVolume) -> [[Double]] {
        let d = volume.direction
        return [
            [d[0], d[1], d[2]],
            [d[4], d[5], d[6]],
            [d[8], d[9], d[10]]
        ]
    }

    func multiply(_ matrix: [[Double]], _ vector: SIMD3<Double>) -> SIMD3<Double> {
        let x = matrix[0][0] * vector.x + matrix[0][1] * vector.y + matrix[0][2] * vector.z
        let y = matrix[1][0] * vector.x + matrix[1][1] * vector.y + matrix[1][2] * vector.z
        let z = matrix[2][0] * vector.x + matrix[2][1] * vector.y + matrix[2][2] * vector.z
        return SIMD3<Double>(x, y, z)
    }

    func invert3x3(_ matrix: [[Double]]) -> [[Double]]? {
        let a = matrix[0][0], b = matrix[0][1], c = matrix[0][2]
        let d = matrix[1][0], e = matrix[1][1], f = matrix[1][2]
        let g = matrix[2][0], h = matrix[2][1], i = matrix[2][2]

        let det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
        if abs(det) < 1e-12 {
            return nil
        }
        let invDet = 1.0 / det
        return [
            [(e * i - f * h) * invDet, (c * h - b * i) * invDet, (b * f - c * e) * invDet],
            [(f * g - d * i) * invDet, (a * i - c * g) * invDet, (c * d - a * f) * invDet],
            [(d * h - e * g) * invDet, (b * g - a * h) * invDet, (a * e - b * d) * invDet]
        ]
    }

    func validateDirectionMatrix(volume: CImageVolume) {
        let dir = directionMatrix(volume: volume)
        let x = SIMD3<Double>(dir[0][0], dir[1][0], dir[2][0])
        let y = SIMD3<Double>(dir[0][1], dir[1][1], dir[2][1])
        let z = SIMD3<Double>(dir[0][2], dir[1][2], dir[2][2])

        let epsilon = 1e-4
        let xNorm = simd_length(x)
        let yNorm = simd_length(y)
        let zNorm = simd_length(z)
        let xy = abs(simd_dot(x, y))
        let xz = abs(simd_dot(x, z))
        let yz = abs(simd_dot(y, z))

        if abs(xNorm - 1.0) > epsilon || abs(yNorm - 1.0) > epsilon || abs(zNorm - 1.0) > epsilon ||
            xy > epsilon || xz > epsilon || yz > epsilon {
            NSLog("ChromaEngine: non-orthonormal direction matrix detected (norms: %.6f/%.6f/%.6f, dots: %.6f/%.6f/%.6f)",
                  xNorm, yNorm, zNorm, xy, xz, yz)
            if shouldAssertOnGeometryIssue() {
                assertionFailure("Non-orthonormal direction matrix detected; MPR may be inaccurate.")
            }
        }

        let det = dir[0][0] * (dir[1][1] * dir[2][2] - dir[1][2] * dir[2][1])
            - dir[0][1] * (dir[1][0] * dir[2][2] - dir[1][2] * dir[2][0])
            + dir[0][2] * (dir[1][0] * dir[2][1] - dir[1][1] * dir[2][0])

        if det < 0 {
            NSLog("ChromaEngine: left-handed direction matrix detected (det=%.6f)", det)
            if shouldAssertOnGeometryIssue() {
                assertionFailure("Left-handed direction matrix detected; reslicing may be mirrored.")
            }
        }
    }

    func shouldAssertOnGeometryIssue() -> Bool {
        ProcessInfo.processInfo.environment["NEUROMETRICA_GEOMETRY_ASSERT"] == "1"
    }
}

// MARK: - Private helpers

extension ChromaEngine {
    func isLeftHandedDirection(volume: CImageVolume) -> Bool {
        let d = volume.direction
        let det = d[0] * (d[5] * d[10] - d[6] * d[9])
            - d[1] * (d[4] * d[10] - d[6] * d[8])
            + d[2] * (d[4] * d[9] - d[5] * d[8])
        return det < 0
    }
}
