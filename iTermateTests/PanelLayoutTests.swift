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
        XCTAssertTrue(panel.acceptsMouseMovedEvents)
        XCTAssertTrue(panel.canBecomeKey)
    }

    func testPanelUsesAlwaysActiveResizeTrackingAreas() {
        let panel = ComradePanel(settings: AppSettings(configURL: makeConfigURL()))
        let contentView = try! XCTUnwrap(panel.contentView)

        contentView.updateTrackingAreas()

        let edgeAreas = contentView.trackingAreas.filter {
            $0.userInfo?["iTermateResizeEdge"] != nil
        }
        XCTAssertEqual(edgeAreas.count, 2)
        XCTAssertTrue(edgeAreas.allSatisfy { $0.options.contains(.activeAlways) })
        XCTAssertTrue(edgeAreas.allSatisfy { $0.options.contains(.mouseEnteredAndExited) })
    }

    func testResizeTrackingHandlesMouseMovedWithoutTrackingArea() throws {
        let panel = ComradePanel(settings: AppSettings(configURL: makeConfigURL()))
        let contentView = try XCTUnwrap(panel.contentView)
        let event = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .mouseMoved,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            )
        )

        NSCursor.arrow.push()
        defer { NSCursor.pop() }
        contentView.mouseMoved(with: event)

        XCTAssertEqual(NSCursor.current, .resizeLeftRight)
    }

    func testManualPanelResizePreservesOppositeEdgeAndClampsWidth() {
        let panel = ComradePanel(settings: AppSettings(configURL: makeConfigURL()))
        let initialFrame = NSRect(x: 700, y: 200, width: 260, height: 500)

        XCTAssertEqual(
            panel.manuallyResizedFrame(
                from: initialFrame,
                leftEdge: true,
                mouseDeltaX: -51
            ),
            NSRect(x: 649, y: 200, width: 311, height: 500)
        )
        XCTAssertEqual(
            panel.manuallyResizedFrame(
                from: initialFrame,
                leftEdge: false,
                mouseDeltaX: 500
            ),
            NSRect(x: 700, y: 200, width: 600, height: 500)
        )
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

    func testPanelFontDefaultsPersistsAndFallsBackWhenUnavailable() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)

        XCTAssertEqual(settings.panelFontName, "system")
        XCTAssertEqual(settings.panelFontSize, 13)

        guard let menlo = NSFont(name: "Menlo-Regular", size: 15) else {
            return XCTFail("Menlo must be available on macOS")
        }
        settings.setPanelFont(menlo)

        let restoredSettings = AppSettings(configURL: configURL)
        XCTAssertEqual(restoredSettings.panelFontName, menlo.fontName)
        XCTAssertEqual(restoredSettings.panelFontSize, menlo.pointSize)

        try! """
        panel_font_name = "MissingFont-Regular"
        panel_font_size = 15
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let unavailableSettings = AppSettings(configURL: configURL)
        let fallback = NSFont.systemFont(ofSize: 15)
        XCTAssertEqual(unavailableSettings.panelFont.fontName, fallback.fontName)
        XCTAssertEqual(unavailableSettings.panelFont.pointSize, fallback.pointSize)
    }

    func testPanelBackgroundStylesMapAndPersist() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)

        XCTAssertEqual(PanelBackgroundStyle.allCases.count, 6)
        XCTAssertEqual(settings.panelBackgroundStyle, .systemBlur)
        XCTAssertTrue(PanelBackgroundStyle.darkBlur.usesBlur)
        XCTAssertFalse(PanelBackgroundStyle.lightOpaque.usesBlur)
        XCTAssertNil(PanelBackgroundStyle.systemOpaque.colorScheme)
        XCTAssertEqual(PanelBackgroundStyle.darkOpaque.colorScheme, .dark)
        XCTAssertEqual(PanelBackgroundStyle.lightBlur.colorScheme, .light)

        settings.setPanelBackgroundStyle(.darkOpaque)

        XCTAssertEqual(
            AppSettings(configURL: configURL).panelBackgroundStyle,
            .darkOpaque
        )
    }

    func testFocusedSectionBackgroundOpacityDefaultsClampsAndPersists() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)

        XCTAssertEqual(settings.focusedSectionBackgroundOpacity, 0.05)
        settings.setFocusedSectionBackgroundOpacity(0.24)

        XCTAssertEqual(
            AppSettings(configURL: configURL).focusedSectionBackgroundOpacity,
            0.24
        )

        try! "focused_section_background_opacity = 2".write(
            to: configURL,
            atomically: true,
            encoding: .utf8
        )
        XCTAssertEqual(
            AppSettings(configURL: configURL).focusedSectionBackgroundOpacity,
            1
        )
    }

    func testPanelDockingSideDefaultsAndPersists() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)

        XCTAssertEqual(settings.panelDockingSide, .right)
        settings.setPanelDockingSide(.left)

        XCTAssertEqual(AppSettings(configURL: configURL).panelDockingSide, .left)
    }

    func testSessionListStylePersists() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        settings.setSessionListStyle(.projectPath)

        XCTAssertEqual(AppSettings(configURL: configURL).sessionListStyle, .projectPath)
    }

    func testSectionTitleStylePersistsAndFormatsFolderName() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)

        XCTAssertEqual(settings.sectionTitleStyle, .fullPath)
        settings.setSectionTitleStyle(.folderName)

        XCTAssertEqual(
            AppSettings(configURL: configURL).sectionTitleStyle,
            .folderName
        )
        XCTAssertEqual(
            SectionTitleStyle.folderName.title(for: "/repo/subdirectory"),
            "subdirectory"
        )
        XCTAssertEqual(SectionTitleStyle.folderName.title(for: "/"), "/")
        XCTAssertEqual(
            SectionTitleStyle.fullPath.title(for: "/repo/subdirectory"),
            "/repo/subdirectory"
        )
    }

    func testUnrelatedChangesDoNotOverwriteNewerConfigValues() {
        let configURL = makeConfigURL()
        let firstSettings = AppSettings(configURL: configURL)
        let staleSettings = AppSettings(configURL: configURL)

        firstSettings.setSectionTitleStyle(.folderName)
        staleSettings.setPanelWidth(420)

        let restoredSettings = AppSettings(configURL: configURL)
        XCTAssertEqual(restoredSettings.sectionTitleStyle, .folderName)
        XCTAssertEqual(restoredSettings.panelWidth, 420)
    }

    func testTabHeadersDefaultOnAndPersist() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        XCTAssertTrue(settings.showsTabHeaders)

        settings.setShowsTabHeaders(false)

        XCTAssertFalse(AppSettings(configURL: configURL).showsTabHeaders)
    }

    func testStatusAnimationPreferencesPersistIndependently() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        let staleSettings = AppSettings(configURL: configURL)

        XCTAssertEqual(settings.statusAnimationStyle(for: .agentRunning), .alien)
        XCTAssertEqual(settings.statusAnimationStyle(for: .commandRunning), .robot)

        settings.setStatusAnimationStyle(.classic, for: .agentRunning)
        settings.setStatusAnimationColor(.systemPink, for: .agentRunning)
        staleSettings.setStatusAnimationStyle(.alien, for: .commandFailed)

        let restoredSettings = AppSettings(configURL: configURL)
        XCTAssertEqual(
            restoredSettings.statusAnimationStyle(for: .agentRunning),
            .classic
        )
        XCTAssertEqual(
            restoredSettings.statusAnimationStyle(for: .commandFailed),
            .alien
        )
        XCTAssertEqual(
            restoredSettings.statusAnimationStyle(for: .agentSucceeded),
            .alien
        )
        XCTAssertNotNil(
            restoredSettings.statusAnimationCustomColor(for: .agentRunning)
        )
        XCTAssertNil(
            restoredSettings.statusAnimationCustomColor(for: .commandFailed)
        )
    }

    func testSessionTimeDisplayDefaultsAndPersists() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        XCTAssertTrue(settings.showsSessionTime)
        XCTAssertEqual(settings.sessionTimeFormat, .compact)

        settings.setShowsSessionTime(false)
        settings.setSessionTimeFormat(.detailed)

        let restoredSettings = AppSettings(configURL: configURL)
        XCTAssertFalse(restoredSettings.showsSessionTime)
        XCTAssertEqual(restoredSettings.sessionTimeFormat, .detailed)
    }

    func testCompletionNotificationsDefaultOffAndPersist() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        XCTAssertFalse(settings.completionNotificationsEnabled)

        settings.setCompletionNotificationsEnabled(true)

        XCTAssertTrue(
            AppSettings(configURL: configURL).completionNotificationsEnabled
        )
    }

    func testSettingsWriteTOMLConfig() {
        let configURL = makeConfigURL()
        let settings = AppSettings(configURL: configURL)
        settings.setPanelWidth(420)
        settings.setPanelBackgroundStyle(.lightOpaque)
        settings.setPanelDockingSide(.left)
        settings.setSessionListStyle(.projectPath)
        settings.setSectionTitleStyle(.folderName)
        settings.setShowsTabHeaders(false)
        settings.setShowsSessionTime(false)
        settings.setSessionTimeFormat(.detailed)
        settings.setCompletionNotificationsEnabled(true)

        let contents = try! String(contentsOf: configURL)
        XCTAssertTrue(contents.contains("panel_width = 420"))
        XCTAssertTrue(contents.contains("panel_font_name = \"system\""))
        XCTAssertTrue(contents.contains("panel_font_size = 13"))
        XCTAssertTrue(contents.contains("panel_background_style = \"lightOpaque\""))
        XCTAssertTrue(contents.contains("panel_docking_side = \"left\""))
        XCTAssertTrue(contents.contains("session_list_style = \"projectPath\""))
        XCTAssertTrue(contents.contains("section_title_style = \"folderName\""))
        XCTAssertTrue(contents.contains("shows_tab_headers = false"))
        XCTAssertTrue(contents.contains("shows_session_time = false"))
        XCTAssertTrue(contents.contains("session_time_format = \"detailed\""))
        XCTAssertTrue(contents.contains("completion_notifications_enabled = true"))
    }

    func testLoadsManuallyEditedTOMLConfig() {
        let configURL = makeConfigURL()
        try! """
        panel_width = 420.0
        panel_docking_side = "left"
        session_list_style = "projectPath"
        shows_tab_headers = false
        shows_session_time = false
        session_time_format = "detailed"
        completion_notifications_enabled = true
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let settings = AppSettings(configURL: configURL)

        XCTAssertEqual(settings.panelWidth, 420)
        XCTAssertEqual(settings.panelDockingSide, .left)
        XCTAssertEqual(settings.sessionListStyle, .projectPath)
        XCTAssertFalse(settings.showsTabHeaders)
        XCTAssertFalse(settings.showsSessionTime)
        XCTAssertEqual(settings.sessionTimeFormat, .detailed)
        XCTAssertTrue(settings.completionNotificationsEnabled)
    }

    func testProjectFolderCustomizationsPersistAndClear() {
        let configURL = makeConfigURL()
        let path = "/repo/# Project \"One\""
        let settings = AppSettings(configURL: configURL)

        settings.togglePinnedProjectFolder(at: path)
        settings.toggleFavoriteProjectFolder(at: path)
        settings.setProjectFolderColor(.systemPurple, at: path)

        let restoredSettings = AppSettings(configURL: configURL)
        let customization = restoredSettings.projectFolderCustomization(at: path)
        XCTAssertTrue(customization.isPinned)
        XCTAssertTrue(customization.isFavorite)
        XCTAssertNotNil(customization.colorHex)
        XCTAssertNotNil(restoredSettings.projectFolderColor(at: path))
        XCTAssertEqual(restoredSettings.pinnedProjectFolderPaths, [path])

        restoredSettings.togglePinnedProjectFolder(at: path)
        restoredSettings.toggleFavoriteProjectFolder(at: path)
        restoredSettings.setProjectFolderColor(nil, at: path)

        XCTAssertTrue(
            AppSettings(configURL: configURL).projectFolderCustomization(at: path).isEmpty
        )
    }

    func testPlacesPanelToTheRightAndMatchesWindowHeight() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)

        let frame = PanelLayout.frame(for: windowFrame, in: visibleFrame)

        XCTAssertEqual(frame, CGRect(x: 908, y: 100, width: 260, height: 600))
    }

    func testPlacesPanelOnPreferredLeftSide() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let windowFrame = CGRect(x: 500, y: 100, width: 600, height: 600)

        let frame = PanelLayout.frame(
            for: windowFrame,
            in: visibleFrame,
            preferredSide: .left
        )

        XCTAssertEqual(frame, CGRect(x: 232, y: 100, width: 260, height: 600))
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

    func testPlacesPanelToTheRightWhenPreferredLeftSideIsFull() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)

        let frame = PanelLayout.frame(
            for: windowFrame,
            in: visibleFrame,
            preferredSide: .left
        )

        XCTAssertEqual(frame, CGRect(x: 908, y: 100, width: 260, height: 600))
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

    func testItermWindowSelectionIgnoresSmallerModalAlert() {
        let mainWindow = CGRect(x: 0, y: 0, width: 1_600, height: 900)
        let modalAlert = CGRect(x: 600, y: 300, width: 520, height: 240)

        XCTAssertEqual(
            TerminalAppWindow.largestWindowFrame(from: [modalAlert, mainWindow]),
            mainWindow
        )
    }
}
