import XCTest

/// Drives the app through the 6 hero flows and calls `snapshot(...)` at each
/// stop. Meant to be run via `fastlane snapshot`, which injects its helper.
final class ScreenshotUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-UITestScreenshotMode", "YES"]
        app.launch()
    }

    func testTakeScreenshots() {
        let app = XCUIApplication()

        // 1 — Dashboard (multi-currency summary cards)
        app.tabBars.buttons["Overview"].firstMatch.tap()
        snapshot("01_dashboard")

        // 2 — Scan
        app.tabBars.buttons["Scan"].firstMatch.tap()
        snapshot("02_scan")

        // 3 — Expenses list (post Gmail sync state)
        app.tabBars.buttons["Expenses"].firstMatch.tap()
        snapshot("03_gmail")

        // 4 — Export (ZIP download screen)
        app.tabBars.buttons["Export"].firstMatch.tap()
        snapshot("04_export")

        // 5 — Multi-currency expenses (scroll the list)
        app.tabBars.buttons["Expenses"].firstMatch.tap()
        app.swipeUp()
        snapshot("05_multiccy")

        // 6 — Onboarding / trial CTA
        app.tabBars.buttons["Settings"].firstMatch.tap()
        app.buttons["Show onboarding"].firstMatch.tap()
        snapshot("06_trial")
    }
}
