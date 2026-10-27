import XCTest
@testable import iTermate

final class PiStatusRecoveryTests: XCTestCase {
    private let tty = "/dev/ttys001"

    func testRestoringAgentFinishedOverShellDoesNotCreateACompletion() {
        func windows(_ status: TerminalSessionStatus, kind: SessionActivityKind) -> [TerminalWindowSnapshot] {
            let session = TerminalSessionSnapshot(id: "pane", name: "Pi", path: nil, tty: tty,
                windowId: "window", tabId: "tab", isActive: false, isMinimized: false,
                status: status, activityKind: kind, exitStatus: nil, statusChangedAt: nil)
            return [TerminalWindowSnapshot(id: "window", number: 1, isActive: false,
                tabs: [TerminalTabSnapshot(id: "tab", title: "tab", isSelected: false, sessions: [session])])]
        }
        var tracker = SessionCompletionTracker()
        XCTAssertTrue(tracker.completions(in: windows(.running, kind: .command)).isEmpty)
        XCTAssertTrue(tracker.completions(in: windows(.finished, kind: .agent)).isEmpty)
        XCTAssertTrue(tracker.completions(in: windows(.running, kind: .agent)).isEmpty)
        XCTAssertEqual(tracker.completions(in: windows(.finished, kind: .agent)).count, 1)
        XCTAssertTrue(tracker.completions(in: windows(.running, kind: .command)).isEmpty)
        XCTAssertEqual(tracker.completions(in: windows(.finished, kind: .command)).count, 1)
        XCTAssertTrue(tracker.completions(in: windows(.finished, kind: .command)).isEmpty)
    }

    func testSlowFirstFourCannotStarveTheNextFourRecoveryCandidates() {
        var scheduler = PiStatusRecoveryScheduler()
        let keys = (0..<8).map { "session-\($0)" }
        // t=0: the first four requests take three seconds to time out.
        XCTAssertEqual(scheduler.reserve(from: keys), [0, 1, 2, 3])
        XCTAssertEqual(scheduler.inFlight.count, 4)
        // t=2: no capacity; this tick must preserve the next candidate.
        XCTAssertTrue(scheduler.reserve(from: keys).isEmpty)
        // t=3: timeouts finish. t=4 must reach the healthy second half.
        for key in keys.prefix(4) { scheduler.complete(key) }
        XCTAssertEqual(scheduler.reserve(from: keys), [4, 5, 6, 7])
        XCTAssertEqual(scheduler.inFlight.count, 4)
        for key in keys.suffix(4) { scheduler.complete(key) }
        XCTAssertEqual(scheduler.reserve(from: keys), [0, 1, 2, 3])
        XCTAssertTrue(scheduler.reserve(from: keys).isEmpty)
        for key in keys.prefix(4) { scheduler.complete(key) }
        XCTAssertEqual(scheduler.reserve(from: keys), [4, 5, 6, 7])
    }

    func testRecoveryReservationsSkipDuplicatesAndRetainTheirLimit() {
        var scheduler = PiStatusRecoveryScheduler()
        let keys = ["a", "b", "a", "c", "d", "e"]
        XCTAssertEqual(scheduler.reserve(from: keys), [0, 1, 3, 4])
        XCTAssertTrue(scheduler.reserve(from: []).isEmpty)
        scheduler.complete("b")
        XCTAssertEqual(scheduler.reserve(from: keys), [5])
        XCTAssertEqual(scheduler.inFlight.count, 4)
        for key in scheduler.inFlight { scheduler.complete(key) }
        XCTAssertEqual(scheduler.reserve(from: ["remaining"]), [0])
    }

    func testSnapshotValidationAndUnknownState() {
        let id = UUID().uuidString
        func snapshot(_ state: TerminalSessionStatus?, sequence: Int = 1, exitStatus: Int? = nil, children: Bool = false) -> PiStatusSnapshot {
            PiStatusSnapshot(version: 1, instanceId: id, sessionId: "session", reporterId: id,
                             sequence: sequence, status: state, exitStatus: exitStatus, hasRunningSubagents: children)
        }
        XCTAssertTrue(snapshot(nil).isValid)
        XCTAssertTrue(snapshot(.interrupted).isValid)
        XCTAssertTrue(snapshot(.awaitingInput, children: true).isValid)
        XCTAssertTrue(snapshot(.finished, exitStatus: 0).isValid)
        XCTAssertFalse(snapshot(.finished).isValid)
        XCTAssertFalse(snapshot(.idle, children: true).isValid)
        XCTAssertFalse(snapshot(.running, sequence: 0).isValid)
        XCTAssertFalse(snapshot(.running, sequence: 9_007_199_254_740_992).isValid)
        XCTAssertFalse(snapshot(.running, exitStatus: 0).isValid)
    }

    func testCompletionEventValidationSurvivesUnknownState() {
        let reporter = UUID().uuidString
        let completion = SessionCompletion(id: UUID().uuidString, completedAt: 100, exitStatus: 0)
        var value = PiStatusSnapshot(version: 1, instanceId: reporter, sessionId: "session",
                                    reporterId: reporter, sequence: 1, status: nil, exitStatus: nil,
                                    hasRunningSubagents: false, latestCompletion: completion)
        XCTAssertTrue(value.isValid)
        value.recentCompletions = [completion]
        XCTAssertTrue(value.isValid)
        value.recentCompletions = []
        XCTAssertFalse(value.isValid)
        value.recentCompletions = nil
        value.latestCompletion = .init(id: completion.id, completedAt: .infinity, exitStatus: 0)
        XCTAssertFalse(value.isValid)
        value.latestCompletion = .init(id: "not-a-uuid", completedAt: 100, exitStatus: 0)
        XCTAssertFalse(value.isValid)
    }
}
