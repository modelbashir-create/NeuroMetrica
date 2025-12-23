import XCTest

final class NeuroMetricaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testSplashTransitionsToViewer() throws {
        let app = XCUIApplication()
        app.launch()

        let splash = app.otherElements["LoadingView"]
        XCTAssertTrue(splash.waitForExistence(timeout: 1.0))

        let viewer = app.otherElements["ViewerContentView"]
        XCTAssertTrue(viewer.waitForExistence(timeout: 8.0))
    }
}
