//
//  NeuroMetricaApp.swift
//  NeuroMetrica
//
//  Created by Mohamed Elbashir on 11/12/25.
//


import SwiftUI

@main
struct NeuroMetricaApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            container.makeRootView()
        }
    }
}