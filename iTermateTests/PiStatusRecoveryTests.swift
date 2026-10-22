import XCTest
@testable import iTermate

final class PiStatusRecoveryTests: XCTestCase {
    private let tty = "/dev/ttys001"

    private func report(_ state: TerminalStatusReport.State, sequence: Int, source: SessionActivityKind = .agent) -> TerminalStatusReport {
        TerminalStatusReport(tty: tty, source: source, reporterID: "pi", sequence: sequence,
                             state: state, exitStatus: state == .finished ? 0 : nil, heartbeat: false)
    }

    func testRecoveryDoesNotOverrideFocusedIdleOrNewPush() {
        var registry = TerminalStatusRegistry()
        registry.reconcile(terminals: [tty: "pane"])
        XCTAssertTrue(registry.apply(report(.finished, sequence: 1)))
        XCTAssertTrue(registry.activate(tty: tty))
        XCTAssertFalse(registry.apply(report(.finished, sequence: 2), recovering: true))
        XCTAssertEqual(registry.visibleStatus(for: tty)?.status, .idle)
        XCTAssertTrue(registry.apply(report(.running, sequence: 3)))
        XCTAssertFalse(registry.apply(report(.idle, sequence: 4), recovering: true))
        XCTAssertEqual(registry.visibleStatus(for: tty)?.status, .running)
    }

    func testViewedCompletionSurvivesRegistryRecreationWithoutHidingNewWork() throws {
        let suite = "PiStatusRecoveryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let completionID = UUID().uuidString
        func finished(_ identity: String?, sequence: Int = 1) -> TerminalStatusReport {
            TerminalStatusReport(tty: tty, source: .agent, reporterID: "pi", sequence: sequence,
                state: .finished, exitStatus: 0, heartbeat: false, agentKind: .pi, completionID: identity)
        }
        var registry = TerminalStatusRegistry(defaults: defaults)
        registry.reconcile(terminals: [tty: "pane"])
        XCTAssertTrue(registry.apply(finished(completionID)))
        XCTAssertEqual(registry.visibleStatus(for: tty)?.status, .finished)

        var unseen = TerminalStatusRegistry(defaults: defaults)
        unseen.reconcile(terminals: [tty: "pane"])
        XCTAssertTrue(unseen.apply(finished(completionID), recovering: true))
        XCTAssertEqual(unseen.visibleStatus(for: tty)?.status, .finished)
        XCTAssertTrue(registry.activate(tty: tty))

        var reopened = TerminalStatusRegistry(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        reopened.reconcile(terminals: [tty: "pane"])
        XCTAssertTrue(reopened.apply(finished(completionID, sequence: 10), recovering: true))
        XCTAssertEqual(reopened.visibleStatus(for: tty)?.status, .idle)
        XCTAssertNil(reopened.visibleStatus(for: tty)?.exitStatus)
        XCTAssertTrue(reopened.apply(report(.running, sequence: 11)))
        XCTAssertEqual(reopened.visibleStatus(for: tty)?.status, .running)
        XCTAssertTrue(reopened.apply(finished(UUID().uuidString, sequence: 12)))
        XCTAssertEqual(reopened.visibleStatus(for: tty)?.status, .finished)

        var reusedTTY = TerminalStatusRegistry(defaults: defaults)
        reusedTTY.reconcile(terminals: [tty: "different-pane"])
        XCTAssertTrue(reusedTTY.apply(finished(completionID), recovering: true))
        XCTAssertEqual(reusedTTY.visibleStatus(for: tty)?.status, .finished)
        reusedTTY.reconcile(terminals: [tty: "legacy-pane"])
        XCTAssertTrue(reusedTTY.apply(finished(nil), recovering: true))
        XCTAssertEqual(reusedTTY.visibleStatus(for: tty)?.status, .finished)
        XCTAssertFalse(reusedTTY.apply(finished("invalid", sequence: 2)))
    }

    func testDelayedActivationCannotAcknowledgeANewerCompletion() throws {
        let suite = "PiActivationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        func finished(_ id: String, sequence: Int) -> TerminalStatusReport {
            TerminalStatusReport(tty: tty, source: .agent, reporterID: "pi", sequence: sequence,
                state: .finished, exitStatus: 0, heartbeat: false, agentKind: .pi, completionID: id)
        }
        var registry = TerminalStatusRegistry(defaults: defaults)
        registry.reconcile(terminals: [tty: "pane"])
        XCTAssertTrue(registry.apply(finished(UUID().uuidString, sequence: 1)))
        let activationA = try XCTUnwrap(registry.activationIdentity(for: tty))
        XCTAssertTrue(registry.apply(report(.running, sequence: 2)))
        let completionB = UUID().uuidString
        XCTAssertTrue(registry.apply(finished(completionB, sequence: 3)))
        XCTAssertFalse(registry.activate(tty: tty, matching: activationA))
        XCTAssertEqual(registry.visibleStatus(for: tty)?.status, .finished)

        var reopened = TerminalStatusRegistry(defaults: defaults)
        reopened.reconcile(terminals: [tty: "pane"])
        XCTAssertTrue(reopened.apply(finished(completionB, sequence: 4), recovering: true))
        XCTAssertEqual(reopened.visibleStatus(for: tty)?.status, .finished)
        let activationB = try XCTUnwrap(reopened.activationIdentity(for: tty))
        // Retransmission of the same completion is not a new event.
        XCTAssertTrue(reopened.apply(finished(completionB, sequence: 5)))
        XCTAssertTrue(reopened.activate(tty: tty, matching: activationB))
        XCTAssertEqual(reopened.visibleStatus(for: tty)?.status, .idle)

        let previousPane = try XCTUnwrap(reopened.activationIdentity(for: tty))
        reopened.reconcile(terminals: [tty: "different-pane"])
        XCTAssertTrue(reopened.apply(finished(UUID().uuidString, sequence: 6)))
        XCTAssertFalse(reopened.activate(tty: tty, matching: previousPane))
        XCTAssertEqual(reopened.visibleStatus(for: tty)?.status, .finished)
    }

    func testActivationOfAnInitiallyUnknownOrRunningAgentDoesNotAcknowledgeLaterWork() throws {
        var registry = TerminalStatusRegistry()
        registry.reconcile(terminals: [tty: "pane"])
        let unknown = try XCTUnwrap(registry.activationIdentity(for: tty))
        XCTAssertTrue(registry.apply(report(.running, sequence: 1)))
        let running = try XCTUnwrap(registry.activationIdentity(for: tty))
        XCTAssertTrue(registry.apply(report(.finished, sequence: 2)))
        XCTAssertFalse(registry.activate(tty: tty, matching: unknown))
        XCTAssertFalse(registry.activate(tty: tty, matching: running))
        XCTAssertEqual(registry.visibleStatus(for: tty)?.status, .finished)
    }

    func testRecoveryFillsAgentGapOverShellFallback() {
        var registry = TerminalStatusRegistry()
        registry.reconcile(terminals: [tty: "pane"])
        XCTAssertTrue(registry.apply(report(.running, sequence: 1, source: .command)))
        XCTAssertTrue(registry.apply(report(.idle, sequence: 1), recovering: true))
        XCTAssertEqual(registry.visibleStatus(for: tty)?.activityKind, .agent)
        XCTAssertEqual(registry.visibleStatus(for: tty)?.status, .idle)
    }

    func testDetachAndLeaseKeepSequenceProtection() {
        var registry = TerminalStatusRegistry()
        registry.reconcile(terminals: [tty: "pane"])
        XCTAssertTrue(registry.apply(report(.running, sequence: 1), uptime: 10))
        XCTAssertTrue(registry.apply(report(.detached, sequence: 3)))
        XCTAssertFalse(registry.apply(report(.finished, sequence: 2), recovering: true))
        XCTAssertNil(registry.visibleStatus(for: tty))
        XCTAssertTrue(registry.apply(report(.running, sequence: 4), uptime: 20, recovering: true))
        XCTAssertTrue(registry.expireStaleAgentHeartbeats(uptime: 29))
        XCTAssertNil(registry.visibleStatus(for: tty))
        XCTAssertTrue(registry.apply(report(.finished, sequence: 5), recovering: true))
    }

    func testUnmappedTTYCannotBeRecovered() {
        var registry = TerminalStatusRegistry()
        XCTAssertFalse(registry.apply(report(.idle, sequence: 1), recovering: true))
    }

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
        XCTAssertTrue(snapshot(.awaitingInput, children: true).isValid)
        XCTAssertTrue(snapshot(.finished, exitStatus: 0).isValid)
        XCTAssertFalse(snapshot(.finished).isValid)
        XCTAssertFalse(snapshot(.idle, children: true).isValid)
        XCTAssertFalse(snapshot(.running, sequence: 0).isValid)
        XCTAssertFalse(snapshot(.running, sequence: 9_007_199_254_740_992).isValid)
        XCTAssertFalse(snapshot(.running, exitStatus: 0).isValid)
    }
}
