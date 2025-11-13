//
//  StudyBrowser.swift
//  NeuroMetrica
//

//


import Foundation
import CoreGraphics

/// Loads studies (from disk, demo data, PACS, etc.).
public protocol StudyBrowser {
    func loadDemoStudy() throws -> Study
   
  
}


public protocol ImagingFileImporter {
    /// Given a URL (file or directory), parse into one or more Studies.
    func importStudies(at url: URL) throws -> [Study]
}


public protocol VolumeProcessing {
   
    func register(
        fixed: Volume3D<Int16>,
        moving: Volume3D<Int16>
    ) throws -> Transform3D

    /// Segment a hematoma
    func segmentHematoma(
        in volume: Volume3D<Int16>
    ) throws -> Volume3D<UInt8>
}

/// Turns a 3D volume into a 2D CGImage
public protocol SliceGenerator {
    func makeSlice(
        from volume: Volume3D<Int16>,
        orientation: VolumeOrientation,
        index: Int,
        window: Float,
        level: Float
    ) -> CGImage?
}
