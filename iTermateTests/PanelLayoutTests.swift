import AppKit
import Foundation
import XCTest
@testable import iTermate

final class PanelLayoutTests: XCTestCase {
    private func makeConfigURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iTermateTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("config.toml")
    }

    func testDefaultConfigUsesHiddenHomeDirectory() {
        let expectedURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".iTermate", isDirectory: true)
            .appendingPathComponent("config.toml")

        XCTAssertEqual(AppSettings.defaultConfigURL, expectedURL)
    }

    func testPanelReceivesMouseEvents() {
        let panel = ComradePanel(settings: AppSettings(configURL: makeConfigURL()))

        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertTrue(panel.canBecomeKey)
    }

    func testPanelResizesHorizontallyAndRestoresSavedWidth() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
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

        XCTAssertEqual(AppSettings(configURL: configURL).panelWidth, 420)
    }

    func testPanelSettingsClampPersistAndResetWidth() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        settings.setPanelWidth(700)

        XCTAssertEqual(settings.panelWidth, 600)
        XCTAssertEqual(AppSettings(configURL: configURL).panelWidth, 600)

        settings.resetPanelWidth()

        XCTAssertEqual(settings.panelWidth, 260)
        XCTAssertEqual(AppSettings(configURL: configURL).panelWidth, 260)
    }

    func testSessionListStylePersists() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        settings.setSessionListStyle(.projectPath)

        XCTAssertEqual(AppSettings(configURL: configURL).sessionListStyle, .projectPath)
    }

    func testTabHeadersDefaultOnAndPersist() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        XCTAssertTrue(settings.showsTabHeaders)

        settings.setShowsTabHeaders(false)

        XCTAssertFalse(AppSettings(configURL: configURL).showsTabHeaders)
    }

    func testSettingsWriteTOMLConfig() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        settings.setPanelWidth(420)
        settings.setSessionListStyle(.projectPath)
        settings.setShowsTabHeaders(false)

        let contents = try! String(contentsOf: configURL)
        XCTAssertTrue(contents.contains("panel_width = 420"))
        XCTAssertTrue(contents.contains("session_list_style = \"projectPath\""))
        XCTAssertTrue(contents.contains("shows_tab_headers = false"))
    }

    func testLoadsManuallyEditedTOMLConfig() {
        let configURL = makeConfigURL()
        try! """
        panel_width = 420.0
        session_list_style = "projectPath"
        shows_tab_headers = false
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let settings = AppSettings(configURL: configURL)

        XCTAssertEqual(settings.panelWidth, 420)
        XCTAssertEqual(settings.sessionListStyle, .projectPath)
        XCTAssertFalse(settings.showsTabHeaders)
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
