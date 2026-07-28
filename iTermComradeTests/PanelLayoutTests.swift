import XCTest
@testable import iTermComrade

final class PanelLayoutTests: XCTestCase {
    func testPanelReceivesMouseEvents() {
        let panel = ComradePanel()

        XCTAssertFalse(panel.ignoresMouseEvents)
    }

    func testPlacesPanelToTheRightAndMatchesWindowHeight() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)

        let frame = PanelLayout.frame(for: windowFrame, in: visibleFrame)

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
}
