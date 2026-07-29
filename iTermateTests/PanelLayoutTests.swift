import XCTest
@testable import iTermate

final class PanelLayoutTests: XCTestCase {
    func testPanelReceivesMouseEvents() {
        let panel = ComradePanel()

        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertTrue(panel.canBecomeKey)
    }

    func testPanelResizesHorizontallyAndRestoresSavedWidth() {
        let suiteName = "PanelLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        let panel = ComradePanel(settings: settings)

        XCTAssertTrue(panel.styleMask.contains(.resizable))
        XCTAssertEqual(
            panel.windowWillResize(panel, to: NSSize(width: 100, height: 200)),
            NSSize(width: 180, height: 400)
        )
        XCTAssertEqual(
            panel.windowWillResize(panel, to: NSSize(width: 700, height: 200)),
            NSSize(width: 600, height: 400)
        )

        panel.setFrame(CGRect(x: 0, y: 0, width: 420, height: 400), display: false)
        panel.windowDidEndLiveResize(
            Notification(name: NSWindow.didEndLiveResizeNotification, object: panel)
        )

        XCTAssertEqual(AppSettings(defaults: defaults).panelWidth, 420)
    }

    func testPanelSettingsClampPersistAndResetWidth() {
        let suiteName = "PanelSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.setPanelWidth(700)

        XCTAssertEqual(settings.panelWidth, 600)
        XCTAssertEqual(AppSettings(defaults: defaults).panelWidth, 600)

        settings.resetPanelWidth()

        XCTAssertEqual(settings.panelWidth, 260)
        XCTAssertEqual(AppSettings(defaults: defaults).panelWidth, 260)
    }

    func testSessionListStylePersists() {
        let suiteName = "SessionListStyleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.setSessionListStyle(.projectPath)

        XCTAssertEqual(AppSettings(defaults: defaults).sessionListStyle, .projectPath)
    }

    func testTabHeadersDefaultOnAndPersist() {
        let suiteName = "TabHeaderSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.showsTabHeaders)

        settings.setShowsTabHeaders(false)

        XCTAssertFalse(AppSettings(defaults: defaults).showsTabHeaders)
    }

    func testPlacesPanelToTheRightAndMatchesWindowHeight() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)

        let frame = PanelLayout.frame(for: windowFrame, in: visibleFrame)

        XCTAssertEqual(frame, CGRect(x: 908, y: 100, width: 260, height: 600))
    }

    func testUsesCurrentPanelWidthWhenFollowingIterm() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)

        let frame = PanelLayout.frame(for: windowFrame, in: visibleFrame, width: 420)

        XCTAssertEqual(frame, CGRect(x: 908, y: 100, width: 420, height: 600))
    }

    func testResizedPanelSwitchesSidesWhenNeeded() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let windowFrame = CGRect(x: 600, y: 100, width: 450, height: 600)

        let frame = PanelLayout.frame(for: windowFrame, in: visibleFrame, width: 420)

        XCTAssertEqual(frame, CGRect(x: 172, y: 100, width: 420, height: 600))
    }

    func testPlacesPanelToTheLeftWhenTheRightSideIsFull() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let windowFrame = CGRect(x: 500, y: 100, width: 800, height: 600)

        let frame = PanelLayout.frame(for: windowFrame, in: visibleFrame)

        XCTAssertEqual(frame, CGRect(x: 232, y: 100, width: 260, height: 600))
    }

    func testKeepsPanelInsideTheVisibleScreen() {
        let visibleFrame = CGRect(x: 0, y: 25, width: 600, height: 775)
        let windowFrame = CGRect(x: 0, y: 0, width: 600, height: 900)

        let frame = PanelLayout.frame(for: windowFrame, in: visibleFrame)

        XCTAssertEqual(frame, CGRect(x: 332, y: 25, width: 260, height: 775))
    }
}
