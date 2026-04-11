import XCTest

/// Captures App Store screenshots by navigating through the main screens.
///
/// The `-UITestScreenshotMode` flag seeds realistic mock data via
/// `ScreenshotData.swift`, so no real auth, API, or network is needed.
///
/// ## Running
///
/// Single device (quick test):
///   xcodebuild test \
///     -project FacturaAI.xcodeproj \
///     -scheme FacturaAI \
///     -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
///     -only-testing:FacturaAIUITests/ScreenshotUITests
///
/// All devices + languages (App Store ready):
///   cd apps/ios && bundle exec fastlane screenshots
///
/// ## Updating screenshots
///
/// 1. Edit mock data in `ScreenshotData.swift` to reflect new features
/// 2. Update this test to navigate to any new screens
/// 3. Update `Framefile.json` titles for new/renamed snapshots
/// 4. Run `bundle exec fastlane screenshots`
/// 5. Output lands in `marketing/screenshots/raw/`
///
final class ScreenshotUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        setupSnapshot(app)
        app.launchArguments += ["-UITestScreenshotMode", "YES"]
        app.launch()
    }

    func testTakeScreenshots() {
        // Wait for mock data to load
        waitForStableUI()

        // 1 — Dashboard: summary cards, income/expense breakdown
        snapshot("01_Dashboard")

        // 2 — Dashboard scrolled: monthly chart, top vendors, tax summary
        app.swipeUp()
        waitForStableUI()
        snapshot("02_Dashboard_Charts")

        // 3 — Invoices list with filter chips
        tapTab(1)
        waitForStableUI()
        snapshot("03_Invoices")

        // 4 — Export screen
        tapTab(2)
        waitForStableUI()
        snapshot("04_Export")

        // 5 — Settings (shows Gmail connected, accountant, Pro plan)
        tapTab(3)
        waitForStableUI()
        snapshot("05_Settings")

        // 6 — Back to dashboard top
        tapTab(0)
        app.swipeDown()
        app.swipeDown()
        waitForStableUI()
        snapshot("06_Dashboard_Top")
    }

    // MARK: - Helpers

    /// Tap a tab by position index (0-based).
    private func tapTab(_ index: Int) {
        let tabBar = app.tabBars.firstMatch
        let buttons = tabBar.buttons
        guard buttons.count > index else { return }
        buttons.element(boundBy: index).tap()
    }

    /// Brief pause for UI to settle after navigation.
    private func waitForStableUI() {
        // RunLoop approach avoids hard sleep — waits for main thread idle
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
    }
}
