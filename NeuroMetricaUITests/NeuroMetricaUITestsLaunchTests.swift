//
//  NeuroMetricaUITestsLaunchTests.swift
//  NeuroMetricaUITests
//
//  Created by Mohamed Elbashir on 11/12/25.
//

import XCTest

final class NeuroMetricaUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

      

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
