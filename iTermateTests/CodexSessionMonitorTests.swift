import XCTest
@testable import iTermate

final class CodexSessionMonitorTests: XCTestCase {
    func testLatestLifecycleEventDeterminesStatus() {
        let observation = CodexSessionMonitor.parseObservation(
            """
            {"timestamp":"2026-10-21T01:00:00.243Z","type":"event_msg","payload":{"type":"task_started"}}
            {"timestamp":"2026-10-21T01:01:00Z","type":"response_item","payload":{"type":"message"}}
            {"timestamp":"2026-10-21T01:02:00.243Z","type":"event_msg","payload":{"type":"task_complete"}}
            """
        )

        XCTAssertEqual(observation.status, .finished)
        XCTAssertEqual(observation.changedAt ?? 0, 1_792_544_520.243, accuracy: 0.001)
    }

    func testUnknownEventsRemainUnknownWithoutGuessingAwaitingInput() {
        let observation = CodexSessionMonitor.parseObservation(
            """
            {"timestamp":"2026-10-21T01:00:00Z","type":"response_item","payload":{"type":"message"}}
            """
        )

        XCTAssertNil(observation.status)
        XCTAssertNil(observation.changedAt)
    }

    func testTurnAbortedIsInterrupted() {
        let observation = CodexSessionMonitor.parseObservation(
            """
            {"timestamp":"2026-10-21T01:00:00Z","type":"event_msg","payload":{"type":"turn_aborted"}}
            """
        )

        XCTAssertEqual(observation.status, .interrupted)
    }

    func testTitleExcerptIncludesOnlyRecentVisibleConversationMessages() {
        let observation = CodexSessionMonitor.parseObservation(
            """
            {"type":"response_item","payload":{"type":"message","role":"developer","content":[{"type":"input_text","text":"hidden instructions"}]}}
            {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"修复 Codex 标题"},{"type":"input_image","image_url":"ignored"}]}}
            {"type":"response_item","payload":{"type":"function_call","name":"shell"}}
            {"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"正在检查标题映射"}]}}
            {"type":"event_msg","payload":{"type":"task_complete"}}
            """
        )

        XCTAssertEqual(
            observation.titleExcerpt,
            "[user]\n修复 Codex 标题\n\n[assistant]\n正在检查标题映射"
        )
    }

    func testActiveStateCanBePreservedWhenLifecycleEventFallsOutsideTail() {
        let previous = CodexSessionObservation(status: .running, changedAt: 42)
        let text = String(repeating: "{\"type\":\"response_item\"}\n", count: 40_000)
        XCTAssertGreaterThan(text.utf8.count, 1_048_576)

        let tail = String(text.suffix(1_048_576))
        let parsed = CodexSessionMonitor.parseObservation(tail)
        let resolved = CodexSessionMonitor.resolvedObservation(parsed, previous: previous)

        XCTAssertEqual(resolved, previous)
    }

    func testGrowingRolloutRestoresRunningWhenLifecycleEventFallsOutsideTail() {
        let resolved = CodexSessionMonitor.resolvedObservation(
            CodexSessionObservation(status: nil, changedAt: nil),
            previous: nil,
            rolloutGrew: true
        )

        XCTAssertEqual(resolved.status, .running)
        XCTAssertNotNil(resolved.changedAt)
    }

    func testRolloutUsesSessionTimestampWhenFileCreationIsDelayed() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let sessions = home.appendingPathComponent(".codex/sessions/2026/10/21", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let rollout = sessions.appendingPathComponent("rollout-delayed.jsonl")
        try Data(
            """
            {"timestamp":"2026-10-21T01:00:00Z","type":"session_meta","payload":{"cwd":"/tmp/project","source":"vscode"}}
            {"timestamp":"2026-10-21T01:00:01Z","type":"event_msg","payload":{"type":"task_started"}}

            """.utf8
        ).write(to: rollout)
        let process = CodexSessionMonitor.CodexProcess(
            identity: .init(pid: 42, startedAt: 1_792_544_400),
            tty: "/dev/ttys002",
            cwd: "/tmp/project",
            arguments: ["codex"]
        )
        let monitor = CodexSessionMonitor(homeDirectory: home) { _ in [process] }

        XCTAssertEqual(monitor.observations(in: [process.tty])[process.tty]?.status, .running)
    }

    func testTransientProcessScanMissRetainsStateAndRediscoveryResetsMissCount() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let sessionID = UUID()
        let sessions = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let rollout = sessions.appendingPathComponent("rollout-\(sessionID.uuidString).jsonl")
        try Data(
            "{\"timestamp\":\"2026-10-21T01:00:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\"}}\n".utf8
        ).write(to: rollout)
        let process = CodexSessionMonitor.CodexProcess(
            identity: .init(pid: 42, startedAt: 42),
            tty: "/dev/ttys002",
            cwd: "/tmp",
            arguments: ["codex", sessionID.uuidString]
        )
        var scans = [[process], [], [process], [], [], [], []]
        let monitor = CodexSessionMonitor(homeDirectory: home) { _ in scans.removeFirst() }
        let ttys: Set<String> = [process.tty]

        XCTAssertEqual(monitor.observations(in: ttys)[process.tty]?.status, .running)
        XCTAssertEqual(monitor.observations(in: ttys)[process.tty]?.status, .running)
        XCTAssertEqual(monitor.observations(in: ttys)[process.tty]?.status, .running)
        XCTAssertEqual(monitor.observations(in: ttys)[process.tty]?.status, .running)
        XCTAssertEqual(monitor.observations(in: ttys)[process.tty]?.status, .running)
        XCTAssertEqual(monitor.observations(in: ttys)[process.tty]?.status, .interrupted)
        XCTAssertNil(monitor.observations(in: ttys)[process.tty])
    }

    func testResetDropsConfirmedObservationBeforeTTYReuse() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let sessionID = UUID()
        let sessions = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try Data(
            "{\"timestamp\":\"2026-10-21T01:00:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\"}}\n".utf8
        ).write(to: sessions.appendingPathComponent("rollout-\(sessionID.uuidString).jsonl"))
        let process = CodexSessionMonitor.CodexProcess(
            identity: .init(pid: 42, startedAt: 42),
            tty: "/dev/ttys002",
            cwd: "/tmp",
            arguments: ["codex", sessionID.uuidString]
        )
        var scans = [[process], []]
        let monitor = CodexSessionMonitor(homeDirectory: home) { _ in scans.removeFirst() }

        XCTAssertEqual(monitor.observations(in: [process.tty])[process.tty]?.status, .running)
        monitor.reset()
        XCTAssertNil(monitor.observations(in: [process.tty])[process.tty])
    }

    func testResetInvalidatesScanDispatchedBeforeReset() {
        var providerWasCalled = false
        let monitor = CodexSessionMonitor { _ in
            providerWasCalled = true
            return []
        }
        let generation = monitor.scanGeneration()

        monitor.reset()
        XCTAssertTrue(monitor.observations(
            in: ["/dev/ttys002"],
            expectedGeneration: generation
        ).isEmpty)
        XCTAssertFalse(providerWasCalled)
    }

    func testResettingUnrelatedTTYPreservesConfirmedCodexGrace() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let sessionID = UUID()
        let sessions = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try Data(
            "{\"timestamp\":\"2026-10-21T01:00:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\"}}\n".utf8
        ).write(to: sessions.appendingPathComponent("rollout-\(sessionID.uuidString).jsonl"))
        let process = CodexSessionMonitor.CodexProcess(
            identity: .init(pid: 42, startedAt: 42),
            tty: "/dev/ttys002",
            cwd: "/tmp",
            arguments: ["codex", sessionID.uuidString]
        )
        var scans = [[process], []]
        let monitor = CodexSessionMonitor(homeDirectory: home) { _ in scans.removeFirst() }

        XCTAssertEqual(monitor.observations(in: [process.tty])[process.tty]?.status, .running)
        monitor.reset(ttys: ["/dev/ttys099"])
        XCTAssertEqual(monitor.observations(in: [process.tty])[process.tty]?.status, .running)
    }

    func testTruncatedTailDropsPartialUTF8LineBeforeDecoding() {
        let lifecycle =
            "{\"timestamp\":\"2026-10-21T01:00:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\"}}\n"
        var data = Data([0x82, 0xAC, 0x0A])
        data.append(contentsOf: lifecycle.utf8)

        let text = CodexSessionMonitor.decodableTail(data, wasTruncated: true)
        XCTAssertEqual(CodexSessionMonitor.parseObservation(text ?? "").status, .running)
    }
}
