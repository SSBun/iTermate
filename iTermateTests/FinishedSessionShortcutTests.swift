import Foundation
import XCTest
@testable import iTermate

final class FinishedSessionShortcutTests: XCTestCase {
    func testShortcutRoundTripAndClearPreserveOtherSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.toml")
        let first = AppSettings(configURL: url)
        let second = AppSettings(configURL: url)
        second.setShowsTabHeaders(false)
        let shortcut = try JSONDecoder().decode(SessionShortcut.self, from: Data(
            #"{"keyCode":38,"modifiers":6144,"keyLabel":"J"}"#.utf8
        ))
        XCTAssertTrue(shortcut.isValid)
        XCTAssertEqual(shortcut.displayName, "⌃⌥J")
        try first.setNextFinishedSessionShortcut(shortcut)
        let restored = AppSettings(configURL: url)
        XCTAssertEqual(restored.nextFinishedSessionShortcut, shortcut)
        XCTAssertFalse(restored.showsTabHeaders)
        try first.setNextFinishedSessionShortcut(nil)
        let cleared = AppSettings(configURL: url)
        XCTAssertNil(cleared.nextFinishedSessionShortcut)
        XCTAssertFalse(cleared.showsTabHeaders)
    }

    func testRejectsUnmodifiedAndInvalidBindings() throws {
        for json in [
            #"{"keyCode":38,"modifiers":0,"keyLabel":"J"}"#,
            #"{"keyCode":38,"modifiers":512,"keyLabel":"J"}"#,
            #"{"keyCode":128,"modifiers":6144,"keyLabel":"J"}"#,
            #"{"keyCode":38,"modifiers":6144,"keyLabel":""}"#,
        ] {
            let shortcut = try JSONDecoder().decode(SessionShortcut.self, from: Data(json.utf8))
            XCTAssertFalse(shortcut.isValid)
        }
    }
}
