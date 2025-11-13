//
//  StudyBrowser.swift
//  NeuroMetrica
//
//  Created by Mohamed Elbashir on 11/12/25.
//


import Foundation
import CoreGraphics

/// Loads studies (from disk, demo data, PACS, etc.).
public protocol StudyBrowser {
    func loadDemoStudy() throws -> Study
    // Later you can add:
    // func listRecentStudies() throws -> [StudySummary]
    // func loadStudy(id: UUID) throws -> Study
}

/// Turns a 3D volume into a 2D CGImage for display.
public protocol SliceGenerator {
    func makeSlice(
        from volume: Volume3D<Int16>,
        orientation: VolumeOrientation,
        index: Int,
        window: Float,
        level: Float
    ) -> CGImage?
}