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

    func testCompletionIdentitySurvivesUnobservedRunningAndReconnect() {
        var tracker = SessionCompletionTracker()
        let idle = session(id: "one", status: .idle)
        XCTAssertTrue(tracker.completions(in: windows(with: [idle]), now: 100).isEmpty)
        var nextTurn = session(id: "one", status: .running)
        nextTurn.latestCompletion = .init(id: "turn-one", completedAt: 101, exitStatus: 0)
        let delivered = tracker.completions(in: windows(with: [nextTurn]), now: 102)
        XCTAssertEqual(delivered.count, 1)
        XCTAssertEqual(delivered.first?.status, .finished)
        XCTAssertEqual(delivered.first?.exitStatus, 0)
        XCTAssertTrue(tracker.completions(in: [], now: 103).isEmpty)
        XCTAssertTrue(tracker.completions(in: windows(with: [nextTurn]), now: 104).isEmpty)
        nextTurn.latestCompletion = .init(id: "turn-two", completedAt: 105, exitStatus: 7)
        XCTAssertEqual(tracker.completions(in: windows(with: [nextTurn]), now: 106).first?.exitStatus, 7)
    }

    func testRecoveredHistoricalCompletionAndOutOfOrderReplayAreNotDelivered() {
        var tracker = SessionCompletionTracker()
        XCTAssertTrue(tracker.completions(in: [], now: 100).isEmpty)
        var restored = session(id: "one", status: .finished, exitStatus: 0)
        restored.latestCompletion = .init(id: "old-turn", completedAt: 99, exitStatus: 0)
        XCTAssertTrue(tracker.completions(in: windows(with: [restored]), now: 101).isEmpty)
        restored.latestCompletion = .init(id: "new-turn", completedAt: 102, exitStatus: 0)
        XCTAssertEqual(tracker.completions(in: windows(with: [restored]), now: 103).count, 1)
        restored.latestCompletion = .init(id: "old-turn", completedAt: 99, exitStatus: 0)
        XCTAssertTrue(tracker.completions(in: windows(with: [restored]), now: 104).isEmpty)
        restored.latestCompletion = .init(id: "new-turn", completedAt: 102, exitStatus: 0)
        XCTAssertTrue(tracker.completions(in: windows(with: [restored]), now: 105).isEmpty)
    }

    func testMultipleCompletionsBetweenSnapshotsAreDeliveredOnceAcrossPanes() {
        var tracker = SessionCompletionTracker()
        _ = tracker.completions(in: [], now: 100)
        let events = [
            SessionCompletion(id: "first", completedAt: 101, exitStatus: 0),
            SessionCompletion(id: "second", completedAt: 101, exitStatus: 1),
        ]
        var running = session(id: "one", status: .running)
        running.latestCompletion = events.last
        running.recentCompletions = events
        XCTAssertEqual(tracker.completions(in: windows(with: [running]), now: 102).count, 2)
        var duplicatePane = session(id: "two", status: .finished)
        duplicatePane.recentCompletions = events
        XCTAssertTrue(tracker.completions(in: windows(with: [duplicatePane]), now: 103).isEmpty)
    }

    func testSecondPrecisionCompletionAfterObservedRunningDoesNotReplaySameSecondHistory() {
        var tracker = SessionCompletionTracker()
        let old = SessionCompletion(id: "old", completedAt: 100, exitStatus: 0)
        let new = SessionCompletion(id: "new", completedAt: 100, exitStatus: 0)
        var running = session(id: "one", status: .running)
        running.recentCompletions = [old]
        running.completionInProgressID = new.id
        XCTAssertTrue(tracker.completions(in: windows(with: [running]), now: 100.5).isEmpty)
        XCTAssertTrue(tracker.completions(in: [], now: 100.6).isEmpty)
        var finished = session(id: "one", status: .finished)
        finished.recentCompletions = [old, new]
        XCTAssertEqual(tracker.completions(in: windows(with: [finished]), now: 101).map {
            $0.latestCompletion?.id
        }, ["new"])
        XCTAssertTrue(tracker.completions(in: windows(with: [finished]), now: 102).isEmpty)
    }

    func testSameSecondHistoryCannotBorrowAnotherThreadsRunningEvidence() {
        var tracker = SessionCompletionTracker()
        var runningA = session(id: "one", status: .running)
        runningA.completionInProgressID = "codex:thread-a:turn-a"
        runningA.recentCompletions = []
        XCTAssertTrue(tracker.completions(in: windows(with: [runningA]), now: 100.5).isEmpty)
        var historicalB = session(id: "one", status: .finished)
        historicalB.recentCompletions = [
            .init(id: "codex:thread-b:turn-b", completedAt: 100, exitStatus: 0)
        ]
        XCTAssertTrue(tracker.completions(in: windows(with: [historicalB]), now: 101).isEmpty)
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
