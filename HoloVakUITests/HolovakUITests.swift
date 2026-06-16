import XCTest

final class HolovakUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Launch

    func testLaunch_showsDropZone() {
        XCTAssertTrue(app.staticTexts["Drop a video file here"].exists)
    }

    func testLaunch_showsHolovakTitle() {
        XCTAssertTrue(app.staticTexts["Holovak"].exists)
    }

    func testLaunch_showsBrowseButton() {
        XCTAssertTrue(app.buttons["Or click to browse…"].exists)
    }
}

final class HolovakUITestsLaunchTests: XCTestCase {

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
