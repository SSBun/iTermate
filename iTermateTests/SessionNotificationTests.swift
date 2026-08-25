import UserNotifications
import XCTest
@testable import iTermate

final class SessionNotificationTests: XCTestCase {
    func testDoesNotReportFinishedSessionsFromInitialSnapshot() {
        var tracker = SessionCompletionTracker()

        let completions = tracker.completions(
            in: windows(with: [session(id: "one", status: .finished, exitStatus: 0)])
        )

        XCTAssertTrue(completions.isEmpty)
    }

    func testReportsEveryRunningToFinishedTransitionOnce() {
        var tracker = SessionCompletionTracker()
        let runningSessions = [
            session(id: "one", status: .running),
            session(id: "two", status: .running),
        ]
        let finishedSessions = [
            session(id: "one", status: .finished, exitStatus: 0),
            session(id: "two", status: .finished, exitStatus: 7),
        ]

        XCTAssertTrue(tracker.completions(in: windows(with: runningSessions)).isEmpty)
        XCTAssertEqual(
            tracker.completions(in: windows(with: finishedSessions)).map(\.id),
            ["one", "two"]
        )
        XCTAssertTrue(tracker.completions(in: windows(with: finishedSessions)).isEmpty)
    }

    func testOnlyDefaultNotificationActionTargetsStoredSession() {
        let userInfo = ["sessionID": "one"]

        XCTAssertEqual(
            SessionNotificationController.sessionIDToActivate(
                actionIdentifier: UNNotificationDefaultActionIdentifier,
                userInfo: userInfo
            ),
            "one"
        )
        XCTAssertNil(
            SessionNotificationController.sessionIDToActivate(
                actionIdentifier: UNNotificationDismissActionIdentifier,
                userInfo: userInfo
            )
        )
    }

    private func windows(
        with sessions: [TerminalSessionSnapshot]
    ) -> [TerminalWindowSnapshot] {
        [
            TerminalWindowSnapshot(
                id: "window",
                number: 1,
                isActive: true,
                tabs: [
                    TerminalTabSnapshot(
                        id: "tab",
                        title: "Tab",
                        isSelected: true,
                        sessions: sessions
                    ),
                ]
            ),
        ]
    }

    private func session(
        id: String,
        status: TerminalSessionStatus,
        exitStatus: Int? = nil
    ) -> TerminalSessionSnapshot {
        TerminalSessionSnapshot(
            id: id,
            name: id.capitalized,
            path: nil,
            tty: nil,
            windowId: "window",
            tabId: "tab",
            isActive: false,
            isMinimized: false,
            status: status,
            activityKind: .command,
            exitStatus: exitStatus,
            statusChangedAt: nil
        )
    }
}
