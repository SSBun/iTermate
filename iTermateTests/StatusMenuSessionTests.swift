import XCTest
@testable import iTermate

final class StatusMenuSessionTests: XCTestCase {
    func testMenuExcludesRunningUnknownAndShellSessions() throws {
        let store = try makeStore()
        try apply([
            session("waiting", .awaitingInput),
            session("finished", .finished),
            session("failed", .finished, exitStatus: 1),
            session("idle", .idle),
            session("interrupted", .interrupted),
            session("running", .running),
            session("unknown", nil),
            session("shell", .finished, agent: false)
        ], to: store)
        XCTAssertEqual(Set(store.statusMenuSessions.map(\.id)), ["waiting", "finished", "failed", "idle", "interrupted"])
        XCTAssertEqual(store.statusMenuSessions.filter(\.isUnread).map(\.id), ["finished"])
        XCTAssertEqual(Set(store.statusMenuSessions.filter(\.isFailure).map(\.id)), ["failed", "interrupted"])
    }

    func testBulkReadKeepsLifecycleFailuresWaitingAndStatistics() throws {
        let store = try makeStore()
        try apply([
            session("done", .finished), session("waiting", .awaitingInput),
            session("failed", .finished, exitStatus: 1)
        ], to: store)
        let lifecycle = store.lifecycleWindows
        let statistics = store.agentCompletionStatistics
        store.markMenuCompletionsRead()
        XCTAssertEqual(store.statusMenuSessions.count, 3)
        XCTAssertTrue(store.statusMenuSessions.allSatisfy { !$0.isUnread })
        XCTAssertEqual(store.statusMenuSessions.first { $0.id == "waiting" }?.status, .awaitingInput)
        XCTAssertEqual(store.statusMenuSessions.first { $0.id == "failed" }?.isFailure, true)
        XCTAssertEqual(store.lifecycleWindows, lifecycle)
        XCTAssertEqual(store.agentCompletionStatistics, statistics)
        try apply([session("done", .finished, changedAt: 200, completionID: "new")], to: store, sequence: 2)
        XCTAssertEqual(store.statusMenuSessions.first?.isUnread, true)
    }

    func testPiFocusAcknowledgementRetainsFailureUntilNewWork() throws {
        let store = try makeStore()
        try apply([session("pane", .finished, exitStatus: 1)], to: store)
        try apply([session("pane", .idle, changedAt: 101, completionExitStatus: 1)], to: store, sequence: 2)
        XCTAssertEqual(store.statusMenuSessions.first?.isFailure, true)
        XCTAssertEqual(store.statusMenuSessions.first?.isUnread, false)
        try apply([session("pane", .running, changedAt: 102)], to: store, sequence: 3)
        XCTAssertTrue(store.statusMenuSessions.isEmpty)
        try apply([session("pane", .idle, changedAt: 103, completionExitStatus: 1)], to: store, sequence: 4)
        XCTAssertEqual(store.statusMenuSessions.first?.status, .idle)
        XCTAssertEqual(store.statusMenuSessions.first?.isFailure, false)
    }

    func testReadCompletionCanBeRecoveredFromExactCompletionTimestamp() throws {
        let store = try makeStore()
        try apply([session("pane", .idle)], to: store)
        XCTAssertEqual(store.statusMenuSessions.first?.status, .finished)
        XCTAssertEqual(store.statusMenuSessions.first?.isUnread, false)
    }

    func testManualWaitingOverrideDoesNotHideMenuRequest() throws {
        let store = try makeStore()
        try apply([session("pane", .awaitingInput)], to: store)
        store.markSessionIdle(sessionID: "pane")
        XCTAssertEqual(store.windows.first?.tabs.first?.sessions.first?.status, .idle)
        XCTAssertEqual(store.statusMenuSessions.first?.status, .awaitingInput)
    }

    func testDisconnectHidesEntriesAndPreservesExplicitReadForSameEvent() throws {
        let store = try makeStore()
        try apply([session("pane", .finished)], to: store)
        store.markMenuCompletionsRead()
        store.updateConnectionState(.disconnected("offline"))
        XCTAssertTrue(store.statusMenuSessions.isEmpty)
        try hello(store)
        try apply([session("pane", .finished)], to: store)
        XCTAssertEqual(store.statusMenuSessions.first?.isUnread, false)
    }

    func testStaleSelectionIsRejectedBeforeActivation() throws {
        let store = try makeStore()
        try apply([session("pane", .finished)], to: store)
        let entry = try XCTUnwrap(store.statusMenuSessions.first)
        try apply([session("pane", .awaitingInput, changedAt: 101)], to: store, sequence: 2)
        var receivedError: String?
        store.activateMenuSession(entry) { receivedError = $0 }
        XCTAssertNotNil(receivedError)
        XCTAssertEqual(store.statusMenuSessions.first?.status, .awaitingInput)
    }

    private func makeStore() throws -> ItermStore {
        let suite = "iTermateTests.menu.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suite)
        }
        let store = ItermStore(titleDefaults: defaults, statusDefaults: defaults)
        try hello(store)
        return store
    }

    private func hello(_ store: ItermStore) throws {
        store.apply(try JSONDecoder().decode(BridgeMessage.self, from: Data("{\"type\":\"hello\"}".utf8)))
    }

    private func apply(_ sessions: [TerminalSessionSnapshot], to store: ItermStore, sequence: Int = 1) throws {
        let windows = [TerminalWindowSnapshot(
            id: "window", number: 1, isActive: false,
            tabs: [TerminalTabSnapshot(id: "tab", title: "Tab", isSelected: false, sessions: sessions)]
        )]
        let encoded = String(decoding: try JSONEncoder().encode(windows), as: UTF8.self)
        store.apply(try JSONDecoder().decode(BridgeMessage.self, from: Data("{\"type\":\"snapshot\",\"sequence\":\(sequence),\"windows\":\(encoded)}".utf8)))
    }

    private func session(
        _ id: String,
        _ status: TerminalSessionStatus?,
        changedAt: TimeInterval = 100,
        exitStatus: Int = 0,
        completionID: String = "completion",
        completionExitStatus: Int? = nil,
        agent: Bool = true
    ) -> TerminalSessionSnapshot {
        TerminalSessionSnapshot(
            id: id, name: id, path: nil, tty: "/dev/ttys001", windowId: "window", tabId: "tab",
            isActive: false, isMinimized: false, status: status, activityKind: agent ? .agent : .command,
            exitStatus: status == .finished ? exitStatus : nil, statusChangedAt: changedAt,
            agentKind: agent ? .pi : nil,
            latestCompletion: SessionCompletion(
                id: "\(id)-\(completionID)", completedAt: status == .finished ? changedAt : 100,
                exitStatus: completionExitStatus ?? exitStatus
            )
        )
    }
}
