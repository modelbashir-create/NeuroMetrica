import Foundation
import ChromaEngineKit

/// OrientationAliases.swift
///
/// Thin adapter so the NeuroMetrica app can talk about slice
/// orientations without importing `ChromaEngineKit` everywhere.
///
/// Use `SliceOrientation` in your UI / ViewModel layers; it is just
/// an alias of the engine’s `ChromaEngineKit.SliceOrientation` enum.
typealias SliceOrientation = ChromaEngineKit.SliceOrientation
