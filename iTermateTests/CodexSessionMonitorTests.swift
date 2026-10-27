import XCTest
@testable import iTermate

final class CodexSessionMonitorTests: XCTestCase {
    private let sessionID = "01988888-1111-7222-8333-444444444444"
    private let secondSessionID = "01988888-1111-7222-8333-555555555555"
    private let tty = "/dev/ttys002"

    private func process(pid: Int32 = 42, tty: String = "/dev/ttys002") -> CodexSessionMonitor.CodexProcess {
        .init(identity: .init(pid: pid, startedAt: 42), tty: tty, cwd: "/tmp/project", arguments: ["codex"])
    }

    private func metadata(_ id: String, padding: String = "") -> String {
        "{\"type\":\"session_meta\",\"payload\":{\"id\":\"\(id)\",\"source\":\"cli\",\"cli_version\":\"0.163.0\",\"padding\":\"\(padding)\"}}\n"
    }

    private func event(_ type: String, turn: String = "turn-1", second: Int = 1) -> String {
        "{\"timestamp\":\"2026-10-21T01:00:\(String(format: "%02d", second))Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"\(type)\",\"turn_id\":\"\(turn)\",\"completed_at\":1792544400}}\n"
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    private func append(_ data: Data, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    private func automaticProcess(
        pid: Int32 = 42,
        tty: String = "/dev/ttys002",
        startedAt: TimeInterval = 1_792_544_400,
        arguments: [String] = ["codex"]
    ) -> CodexSessionMonitor.CodexProcess {
        .init(identity: .init(pid: pid, startedAt: startedAt), tty: tty, cwd: "/tmp/project", arguments: arguments)
    }

    private func discoverableRollout(
        in directory: URL,
        id: String,
        startedAt: TimeInterval = 1_792_544_400,
        cwd: String = "/tmp/project"
    ) throws -> URL {
        let date = Date(timeIntervalSince1970: startedAt)
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let day = directory.appendingPathComponent(String(format: "%04d/%02d/%02d",
            try XCTUnwrap(components.year), try XCTUnwrap(components.month), try XCTUnwrap(components.day)))
        try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
        let file = day.appendingPathComponent("rollout-\(id).jsonl")
        let header: [String: Any] = [
            "type": "session_meta", "timestamp": ISO8601DateFormatter().string(from: date),
            "payload": ["id": id, "cwd": cwd, "source": "cli", "cli_version": "0.163.0"]
        ]
        let line = String(decoding: try JSONSerialization.data(withJSONObject: header), as: UTF8.self)
        try write(line + "\n" + event("task_started"), to: file)
        return file
    }

    func testSharedDaemonSessionAutomaticallyMatchesDirectoryAndStartupTime() throws {
        let directory = try temporaryDirectory()
        let file = try discoverableRollout(in: directory, id: sessionID)
        let message = "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":\"Recover automatic titles\"}}\n"
        try append(Data(message.utf8), to: file)
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        let observation = monitor.observations(in: [tty])[tty]
        XCTAssertEqual(observation?.sessionID, sessionID)
        XCTAssertEqual(observation?.status, .running)
        XCTAssertEqual(observation?.titleExcerpt, "[user]\nRecover automatic titles")
        XCTAssertEqual(observation?.requiresRuntimeStatus, true)
    }

    func testResumeArgumentAutomaticallyMatchesOlderSessionInDifferentDirectory() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID, startedAt: 1_790_000_000, cwd: "/old/project")
        _ = try discoverableRollout(in: directory, id: secondSessionID)
        let process = automaticProcess(arguments: ["codex", "resume", sessionID.uppercased()])
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        let observation = monitor.observations(in: [tty])[tty]
        XCTAssertEqual(observation?.sessionID, sessionID)
        XCTAssertEqual(observation?.requiresRuntimeStatus, true)
    }

    func testOwnedFileOverridesAutomaticAssociationAndStartupResumeArgument() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        let next = try discoverableRollout(in: directory, id: secondSessionID, startedAt: 1_792_544_500)
        let process = automaticProcess(arguments: ["codex", "resume", sessionID])
        var opened: [URL] = []
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in opened }, sessionsDirectory: directory
        )
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.sessionID, sessionID)
        opened = [next]
        let observation = monitor.observations(in: [tty])[tty]
        XCTAssertEqual(observation?.sessionID, secondSessionID)
        XCTAssertEqual(observation?.requiresRuntimeStatus, false)
    }

    func testAutomaticAssociationDoesNotFollowANewerSameDirectoryFile() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID, startedAt: 1_792_544_405)
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.sessionID, sessionID)
        _ = try discoverableRollout(in: directory, id: secondSessionID)
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.sessionID, sessionID)
    }

    func testAmbiguousDirectoryCandidatesRemainUnknown() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        _ = try discoverableRollout(in: directory, id: secondSessionID, startedAt: 1_792_544_401)
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        XCTAssertNil(monitor.observations(in: [tty])[tty]?.sessionID)
    }

    func testTwoCompetingProcessesCannotClaimOneDirectorySession() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        let processes = [automaticProcess(), automaticProcess(pid: 43, tty: "/dev/ttys003")]
        let monitor = CodexSessionMonitor(
            processProvider: { _ in processes }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        for _ in 0..<10 {
            let observations = monitor.observations(in: Set(processes.map(\.tty)))
            XCTAssertTrue(observations.values.allSatisfy { $0.sessionID == nil })
        }
    }

    func testCloserProcessWinsGlobalDirectoryConflictIndependentOfOrder() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        let first = automaticProcess()
        let second = automaticProcess(pid: 43, tty: "/dev/ttys003", startedAt: 1_792_544_410)
        for processes in [[first, second], [second, first]] {
            let monitor = CodexSessionMonitor(
                processProvider: { _ in processes }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
            )
            let observations = monitor.observations(in: [first.tty, second.tty])
            XCTAssertEqual(observations[first.tty]?.sessionID, sessionID)
            XCTAssertNil(observations[second.tty]?.sessionID)
        }
    }

    func testConflictingClaimsRemainVisibleWhenAnotherProcessAppears() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        var processes = [automaticProcess(), automaticProcess(pid: 43, tty: "/dev/ttys003")]
        let monitor = CodexSessionMonitor(
            processProvider: { _ in processes }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        for _ in 0..<4 { _ = monitor.observations(in: Set(processes.map(\.tty))) }
        processes.append(automaticProcess(pid: 44, tty: "/dev/ttys004", startedAt: 1_792_544_410))
        XCTAssertTrue(monitor.observations(in: Set(processes.map(\.tty))).values.allSatisfy { $0.sessionID == nil })
    }

    func testStrongEvidenceWinsOverAnotherProcessesDirectoryCandidate() throws {
        let directory = try temporaryDirectory()
        let file = try discoverableRollout(in: directory, id: sessionID)
        let first = automaticProcess(startedAt: 1_792_544_410, arguments: ["codex", "resume", sessionID])
        let second = automaticProcess(pid: 43, tty: "/dev/ttys003")
        for opened in [false, true] {
            let monitor = CodexSessionMonitor(
                processProvider: { _ in [second, first] },
                rolloutProvider: { opened && $0.identity == first.identity ? [file] : [] },
                sessionsDirectory: directory
            )
            let observations = monitor.observations(in: [first.tty, second.tty])
            XCTAssertEqual(observations[first.tty]?.sessionID, sessionID)
            XCTAssertNil(observations[second.tty]?.sessionID)
        }
    }

    func testDuplicateExplicitResumeClaimsRemainUnknown() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        let processes = [
            automaticProcess(arguments: ["codex", "resume", sessionID]),
            automaticProcess(pid: 43, tty: "/dev/ttys003", arguments: ["codex", "resume", sessionID])
        ]
        let monitor = CodexSessionMonitor(
            processProvider: { _ in processes }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        XCTAssertTrue(monitor.observations(in: Set(processes.map(\.tty))).values.allSatisfy { $0.sessionID == nil })
    }

    func testAutomaticDiscoveryRejectsWrongDirectoryAndOldStartupThenKeepsRetrying() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID, cwd: "/other/project")
        _ = try discoverableRollout(in: directory, id: secondSessionID, startedAt: 1_792_544_300)
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        for _ in 0..<40 { XCTAssertNil(monitor.observations(in: [tty])[tty]?.sessionID) }
        _ = try discoverableRollout(in: directory, id: sessionID)
        var recovered: CodexSessionObservation?
        for _ in 0..<8 { recovered = monitor.observations(in: [tty])[tty] }
        XCTAssertEqual(recovered?.sessionID, sessionID)
        XCTAssertEqual(recovered?.requiresRuntimeStatus, true)
    }

    func testAutomaticMatchRetainsRuntimeStatusRequirementDuringProcessExit() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        let process = automaticProcess()
        var alive = true
        let monitor = CodexSessionMonitor(
            processProvider: { _ in alive ? [process] : [] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.requiresRuntimeStatus, true)
        alive = false
        for _ in 0..<3 {
            let observation = monitor.observations(in: [tty])[tty]
            XCTAssertEqual(observation?.requiresRuntimeStatus, true)
            XCTAssertEqual(observation?.isProcessAlive, false)
        }
    }

    func testNativeTitleFollowsNewAndResumeWithinTheSameProcess() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        let resumed = try discoverableRollout(
            in: directory, id: secondSessionID, startedAt: 1_790_000_000, cwd: "/old/project"
        )
        try append(Data(event("task_complete", second: 2).utf8), to: resumed)
        let process = automaticProcess(arguments: ["codex", "resume", sessionID])
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.sessionID, sessionID)
        let switched = monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: String(secondSessionID.prefix(29))]
        )[tty]
        XCTAssertEqual(switched?.sessionID, secondSessionID)
        XCTAssertEqual(switched?.status, .finished)
        XCTAssertEqual(switched?.requiresRuntimeStatus, true)
        let returned = monitor.observations(in: [tty], terminalThreadPrefixes: [tty: sessionID])[tty]
        XCTAssertEqual(returned?.sessionID, sessionID)
        XCTAssertEqual(returned?.status, .running)
        XCTAssertNil(returned?.latestCompletion)
    }

    func testLostOrInvalidNativeTitleNeverRestoresStaleStartupAssociation() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        _ = try discoverableRollout(in: directory, id: secondSessionID, startedAt: 1_790_000_000)
        let process = automaticProcess(arguments: ["codex", "resume", sessionID])
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        XCTAssertEqual(monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: String(secondSessionID.prefix(29))]
        )[tty]?.sessionID, secondSessionID)
        XCTAssertNil(monitor.observations(in: [tty], terminalThreadPrefixes: [tty: ""])[tty]?.sessionID)
        for _ in 0..<12 { XCTAssertNil(monitor.observations(in: [tty])[tty]?.sessionID) }
        XCTAssertEqual(monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: String(secondSessionID.prefix(29))]
        )[tty]?.sessionID, secondSessionID)
    }

    func testUnresolvedNativeTitleRemainsUnknownEvenWhenStartupMatches() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        XCTAssertNil(monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: String(secondSessionID.prefix(29))]
        )[tty]?.sessionID)
        _ = try discoverableRollout(in: directory, id: secondSessionID, startedAt: 1_790_000_000)
        var resolved: CodexSessionObservation?
        for _ in 0..<8 {
            resolved = monitor.observations(
                in: [tty], terminalThreadPrefixes: [tty: String(secondSessionID.prefix(29))]
            )[tty]
        }
        XCTAssertEqual(resolved?.sessionID, secondSessionID)
    }

    func testShortNativeTitleMustRemainUniqueAgainstFullMetadataIDs() throws {
        let directory = try temporaryDirectory()
        _ = try discoverableRollout(in: directory, id: sessionID)
        let prefix = String(sessionID.prefix(29))
        let collisionID = prefix + "9999999"
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        XCTAssertEqual(monitor.observations(in: [tty], terminalThreadPrefixes: [tty: prefix])[tty]?.sessionID, sessionID)
        _ = try discoverableRollout(in: directory, id: collisionID, startedAt: 1_790_000_000)
        XCTAssertNil(monitor.observations(in: [tty], terminalThreadPrefixes: [tty: prefix])[tty]?.sessionID)
        XCTAssertEqual(monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: sessionID]
        )[tty]?.sessionID, sessionID)
    }

    func testNativeTitleRejectsSubagentButAcceptsResumedEditorRoot() throws {
        let directory = try temporaryDirectory()
        let file = try discoverableRollout(in: directory, id: sessionID)
        let original = try String(contentsOf: file, encoding: .utf8)
        try write(original.replacingOccurrences(of: "\"cli\"", with: "{\"subagent\":{}}"), to: file)
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [] }, sessionsDirectory: directory
        )
        XCTAssertNil(monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: String(sessionID.prefix(29))]
        )[tty]?.sessionID)
        try write(original.replacingOccurrences(of: "\"cli\"", with: "\"vscode\""), to: file)
        XCTAssertEqual(monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: sessionID]
        )[tty]?.sessionID, sessionID)
    }

    func testUnresolvedNativeTitleRejectsAnOldOwnedFile() throws {
        let directory = try temporaryDirectory()
        let file = try discoverableRollout(in: directory, id: sessionID)
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [file] }, sessionsDirectory: directory
        )
        let observation = monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: String(secondSessionID.prefix(29))]
        )[tty]
        XCTAssertNil(observation?.sessionID)
    }

    func testNativeTitleOverridesAConflictingOwnedFile() throws {
        let directory = try temporaryDirectory()
        let first = try discoverableRollout(in: directory, id: sessionID)
        _ = try discoverableRollout(in: directory, id: secondSessionID, startedAt: 1_790_000_000)
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [first] }, sessionsDirectory: directory
        )
        let observation = monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: String(secondSessionID.prefix(29))]
        )[tty]
        XCTAssertEqual(observation?.sessionID, secondSessionID)
        XCTAssertEqual(observation?.requiresRuntimeStatus, true)
        for _ in 0..<10 { XCTAssertNil(monitor.observations(in: [tty])[tty]?.sessionID) }
    }

    func testNativeTitleUsesMatchingOwnedFileWithoutRequiringDaemon() throws {
        let directory = try temporaryDirectory()
        let first = try discoverableRollout(in: directory, id: sessionID)
        let process = automaticProcess()
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [first] }, sessionsDirectory: directory
        )
        let observation = monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: String(sessionID.prefix(29))]
        )[tty]
        XCTAssertEqual(observation?.sessionID, sessionID)
        XCTAssertEqual(observation?.requiresRuntimeStatus, false)
    }

    func testNativeTitleDisambiguatesOwnedFilesRetainedAcrossAThreadSwitch() throws {
        let directory = try temporaryDirectory()
        let first = try discoverableRollout(in: directory, id: sessionID)
        let second = try discoverableRollout(in: directory, id: secondSessionID, startedAt: 1_790_000_000)
        let process = automaticProcess(arguments: ["codex", "resume", sessionID])
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [process] }, rolloutProvider: { _ in [first, second] }, sessionsDirectory: directory
        )
        XCTAssertNil(monitor.observations(in: [tty])[tty]?.sessionID)
        XCTAssertEqual(monitor.observations(
            in: [tty], terminalThreadPrefixes: [tty: String(secondSessionID.prefix(29))]
        )[tty]?.sessionID, secondSessionID)
    }

    func testBoundDaemonThreadSuppliesTitlesWithoutCLIFileDescriptors() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-daemon.jsonl")
        let message = "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":\"Fix Codex titles\"}}\n"
        try write(metadata(sessionID) + message, to: rollout)
        let process = process()
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in [] })
        XCTAssertNil(monitor.observations(in: [tty])[tty]?.sessionID)
        XCTAssertEqual(
            monitor.titleExcerpt(at: rollout.path, threadID: sessionID, process: process.identity),
            "[user]\nFix Codex titles"
        )
        _ = monitor.observations(in: [tty])
        try append(Data(message.replacingOccurrences(of: "Fix Codex titles", with: "Keep statuses accurate").utf8), to: rollout)
        XCTAssertEqual(
            monitor.titleExcerpt(at: rollout.path, threadID: sessionID, process: process.identity),
            "[user]\nFix Codex titles\n\n[user]\nKeep statuses accurate"
        )
        XCTAssertNil(monitor.titleExcerpt(at: rollout.path, threadID: secondSessionID, process: process.identity))
        monitor.reset()
        XCTAssertNil(monitor.titleExcerpt(at: rollout.path, threadID: sessionID, process: process.identity))
    }

    func testBoundTitleRejectsSubagentAndSymlinkRollouts() throws {
        let directory = try temporaryDirectory()
        let rollout = directory.appendingPathComponent("rollout-bound.jsonl")
        let link = directory.appendingPathComponent("rollout-link.jsonl")
        let message = "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":\"Private task\"}}\n"
        try write(metadata(sessionID) + message, to: rollout)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: rollout)
        let process = process()
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in [] })
        _ = monitor.observations(in: [tty])
        XCTAssertNil(monitor.titleExcerpt(at: link.path, threadID: sessionID, process: process.identity))
        try write(metadata(sessionID).replacingOccurrences(of: "\"cli\"", with: "{\"subagent\":{}}") + message, to: rollout)
        XCTAssertNil(monitor.titleExcerpt(at: rollout.path, threadID: sessionID, process: process.identity))
    }

    func testLatestLifecycleEventDeterminesStatusAndStableCompletion() {
        let observation = CodexSessionMonitor.parseObservation(
            metadata(sessionID) + event("task_started") + event("task_complete", second: 2)
        )
        XCTAssertEqual(observation.status, .finished)
        XCTAssertEqual(observation.changedAt ?? 0, 1_792_544_402, accuracy: 0.001)
        XCTAssertEqual(observation.latestCompletion?.id, "codex:\(sessionID):turn-1")
        XCTAssertEqual(observation.latestCompletion?.exitStatus, 0)
    }

    func testCompletionSurvivesNextRunningEventBetweenScans() {
        let observation = CodexSessionMonitor.parseObservation(
            metadata(sessionID) + event("task_started") + event("task_complete", second: 2)
                + event("task_started", turn: "turn-2", second: 3)
        )
        XCTAssertEqual(observation.status, .running)
        XCTAssertEqual(observation.latestCompletion?.id, "codex:\(sessionID):turn-1")
    }

    func testLegacyCompletionDoesNotInventSuccessfulOutcome() {
        let oldMetadata = metadata(sessionID).replacingOccurrences(of: "0.163.0", with: "0.100.0")
        let observed = CodexSessionMonitor.parseObservation(oldMetadata + event("task_complete"))
        XCTAssertEqual(observed.status, .finished)
        XCTAssertNotNil(observed.latestCompletion)
        XCTAssertNil(observed.latestCompletion?.exitStatus)
        let legacyEvent = event("task_complete").replacingOccurrences(of: ",\"completed_at\":1792544400", with: "")
        let oldWriter = CodexSessionMonitor.parseObservation(metadata(sessionID) + legacyEvent)
        XCTAssertNil(oldWriter.latestCompletion?.exitStatus)
    }

    func testMultipleCompletionsBetweenScansSurviveNextRunningTurn() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-multiple-completions.jsonl")
        try write(metadata(sessionID) + event("task_started"), to: rollout)
        let process = process()
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in [rollout] })
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.recentCompletions, [])
        let events = event("task_complete", second: 2)
            + event("task_started", turn: "turn-2", second: 3)
            + event("task_complete", turn: "turn-2", second: 4)
            + event("task_started", turn: "turn-3", second: 5)
        try append(Data(events.utf8), to: rollout)
        let observed = monitor.observations(in: [tty])[tty]
        XCTAssertEqual(observed?.status, .running)
        XCTAssertEqual(observed?.completionInProgressID, "codex:\(sessionID):turn-3")
        XCTAssertEqual(observed?.recentCompletions?.map(\.id), [
            "codex:\(sessionID):turn-1", "codex:\(sessionID):turn-2"
        ])
        XCTAssertEqual(observed?.latestCompletion, observed?.recentCompletions?.last)
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.recentCompletions, observed?.recentCompletions)
        XCTAssertEqual(
            CodexSessionMonitor.observationAfterMissingScan(
                try XCTUnwrap(observed), missedScans: 3
            ).recentCompletions,
            observed?.recentCompletions
        )
    }

    func testRecentCompletionsAreDeduplicatedAndBounded() {
        let completions = (0..<70).map { event("task_complete", turn: "turn-\($0)", second: 2) }.joined()
        let observed = CodexSessionMonitor.parseObservation(
            metadata(sessionID) + completions + event("task_complete", turn: "turn-69", second: 2)
        )
        XCTAssertEqual(observed.recentCompletions?.count, 64)
        XCTAssertEqual(observed.recentCompletions?.first?.id, "codex:\(sessionID):turn-6")
        XCTAssertEqual(observed.recentCompletions?.last?.id, "codex:\(sessionID):turn-69")
    }

    func testAbortedTurnDoesNotCreateSuccessfulCompletion() {
        let observation = CodexSessionMonitor.parseObservation(
            metadata(sessionID) + event("task_started") + event("turn_aborted", second: 2)
        )
        XCTAssertEqual(observation.status, .interrupted)
        XCTAssertNil(observation.latestCompletion)
    }

    func testExplicitFailedCompletionDoesNotCountAsSuccess() {
        let observation = CodexSessionMonitor.parseObservation(
            metadata(sessionID) + event("task_started")
                + "{\"timestamp\":\"2026-10-21T01:00:02Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\",\"turn_id\":\"turn-1\",\"error\":{\"message\":\"failed\"}}}\n"
        )
        XCTAssertEqual(observation.latestCompletion?.exitStatus, 1)
    }

    func testUnknownEventsDoNotGuessRunningOrWaiting() {
        let observation = CodexSessionMonitor.parseObservation(
            "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\"}}"
        )
        XCTAssertNil(observation.status)
    }

    func testTitleExcerptIncludesOnlyRecentVisibleConversationMessages() {
        let observation = CodexSessionMonitor.parseObservation(
            """
            {"type":"response_item","payload":{"type":"message","role":"developer","content":[{"type":"input_text","text":"hidden instructions"}]}}
            {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"修复 Codex 标题"},{"type":"input_image","image_url":"ignored"}]}}
            {"type":"response_item","payload":{"type":"function_call","name":"shell"}}
            {"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"正在检查标题映射"}]}}
            """
        )
        XCTAssertEqual(observation.titleExcerpt, "[user]\n修复 Codex 标题\n\n[assistant]\n正在检查标题映射")
    }

    func testSameDirectoryCannotBindAnotherProcessesRollout() throws {
        let directory = try temporaryDirectory()
        let rollout = directory.appendingPathComponent("rollout-first.jsonl")
        try write(metadata(sessionID) + event("task_started"), to: rollout)
        let first = process()
        let second = process(pid: 43, tty: "/dev/ttys003")
        let monitor = CodexSessionMonitor(
            processProvider: { _ in [first, second] },
            rolloutProvider: { $0.identity == first.identity ? [rollout] : [] }
        )
        let observations = monitor.observations(in: [first.tty, second.tty])
        XCTAssertEqual(observations[first.tty]?.sessionID, sessionID)
        XCTAssertEqual(observations[first.tty]?.isProcessAlive, true)
        XCTAssertNil(observations[second.tty]?.status)
        XCTAssertNil(observations[second.tty]?.sessionID)
        XCTAssertEqual(observations[second.tty]?.processIdentity, second.identity)
        XCTAssertEqual(observations[second.tty]?.isProcessAlive, true)
    }

    func testAmbiguousOpenRolloutsRemainUnknownEvenWithResumeArgument() throws {
        let directory = try temporaryDirectory()
        let first = directory.appendingPathComponent("rollout-\(sessionID).jsonl")
        let second = directory.appendingPathComponent("rollout-\(secondSessionID).jsonl")
        try write(metadata(sessionID) + event("task_complete"), to: first)
        try write(metadata(secondSessionID) + event("task_started"), to: second)
        let process = CodexSessionMonitor.CodexProcess(
            identity: .init(pid: 42, startedAt: 42), tty: tty, cwd: "/tmp/project",
            arguments: ["codex", "resume", sessionID]
        )
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in [first, second] })
        XCTAssertNil(monitor.observations(in: [tty])[tty]?.status)
    }

    func testSameProcessThreadSwitchDiscardsOldStateAndCompletion() throws {
        let directory = try temporaryDirectory()
        let first = directory.appendingPathComponent("rollout-first.jsonl")
        let second = directory.appendingPathComponent("rollout-second.jsonl")
        try write(metadata(sessionID) + event("task_complete"), to: first)
        try write(metadata(secondSessionID) + event("task_started"), to: second)
        let process = process()
        var current = first
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in [current] })
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.status, .finished)
        current = second
        let switched = monitor.observations(in: [tty])[tty]
        XCTAssertEqual(switched?.status, .running)
        XCTAssertEqual(switched?.sessionID, secondSessionID)
        XCTAssertNil(switched?.latestCompletion)
        XCTAssertEqual(switched?.recentCompletions, [])
    }

    func testUnresolvedProcessKeepsRetryingAfterFifteenScans() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-delayed.jsonl")
        try write(metadata(sessionID, padding: String(repeating: "x", count: 100_000)) + event("task_started"), to: rollout)
        let process = process()
        var available = false
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in available ? [rollout] : [] })
        for _ in 0..<40 { XCTAssertNil(monitor.observations(in: [tty])[tty]?.status) }
        available = true
        var resolved: CodexSessionObservation?
        for _ in 0..<8 { resolved = monitor.observations(in: [tty])[tty] }
        XCTAssertEqual(resolved?.status, .running)
        XCTAssertEqual(resolved?.sessionID, sessionID)
    }

    func testPartialLineIncludingSplitUTF8WaitsForNewline() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-partial.jsonl")
        try write(metadata(sessionID) + event("task_started"), to: rollout)
        let process = process()
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in [rollout] })
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.status, .running)
        let line = Data("{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":\"中\"}}\n".utf8)
        let split = try XCTUnwrap(line.firstIndex(of: 0xE4)) + 1
        try append(Data(line[..<split]), to: rollout)
        XCTAssertNil(monitor.observations(in: [tty])[tty]?.titleExcerpt)
        try append(Data(line[split...]), to: rollout)
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.titleExcerpt, "[assistant]\n中")
        let completion = Data(event("task_complete", second: 2).utf8)
        try append(Data(completion.dropLast()), to: rollout)
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.status, .running)
        try append(Data([0x0A]), to: rollout)
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.status, .finished)
    }

    func testUnchangedFileRetainsStableObservation() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-stable.jsonl")
        try write(metadata(sessionID) + event("task_complete"), to: rollout)
        let process = process()
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in [rollout] })
        let first = monitor.observations(in: [tty])[tty]
        XCTAssertEqual(monitor.observations(in: [tty])[tty], first)
    }

    func testTruncationAndAtomicReplacementResetReader() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-replaced.jsonl")
        try write(metadata(sessionID) + event("task_started") + event("task_complete", second: 2), to: rollout)
        let process = process()
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in [rollout] })
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.status, .finished)
        try write(metadata(secondSessionID) + event("task_started"), to: rollout)
        let truncated = monitor.observations(in: [tty])[tty]
        XCTAssertEqual(truncated?.sessionID, secondSessionID)
        XCTAssertEqual(truncated?.status, .running)
        XCTAssertNil(truncated?.latestCompletion)
        try Data((metadata(sessionID) + event("turn_aborted")).utf8).write(to: rollout, options: .atomic)
        let replaced = monitor.observations(in: [tty])[tty]
        XCTAssertEqual(replaced?.sessionID, sessionID)
        XCTAssertEqual(replaced?.status, .interrupted)
    }

    func testCompletionWrittenBeforeProcessExitWinsOverInterruptedFallback() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-final.jsonl")
        try write(metadata(sessionID) + event("task_started"), to: rollout)
        let process = process()
        var alive = true
        let monitor = CodexSessionMonitor(processProvider: { _ in alive ? [process] : [] }, rolloutProvider: { _ in [rollout] })
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.status, .running)
        try append(Data(event("task_complete", second: 2).utf8), to: rollout)
        alive = false
        for _ in 0..<3 {
            let final = monitor.observations(in: [tty])[tty]
            XCTAssertEqual(final?.status, .finished)
            XCTAssertEqual(final?.isProcessAlive, false)
            XCTAssertEqual(final?.latestCompletion?.id, "codex:\(sessionID):turn-1")
            XCTAssertEqual(final?.recentCompletions?.map(\.id), ["codex:\(sessionID):turn-1"])
        }
        XCTAssertNil(monitor.observations(in: [tty])[tty])
    }

    func testTransientProcessMissPreservesStateAndRediscoveryResetsGrace() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-grace.jsonl")
        try write(metadata(sessionID) + event("task_started"), to: rollout)
        let process = process()
        var scans = [[process], [], [process], [], [], [], []]
        let monitor = CodexSessionMonitor(processProvider: { _ in scans.removeFirst() }, rolloutProvider: { _ in [rollout] })
        for expectedAlive in [true, false, true, false, false] {
            let observation = monitor.observations(in: [tty])[tty]
            XCTAssertEqual(observation?.status, .running)
            XCTAssertEqual(observation?.isProcessAlive, expectedAlive)
        }
        let interrupted = monitor.observations(in: [tty])[tty]
        XCTAssertEqual(interrupted?.status, .interrupted)
        XCTAssertEqual(interrupted?.isProcessAlive, false)
        XCTAssertNil(monitor.observations(in: [tty])[tty])
    }

    func testResetInvalidatesDispatchedScanAndPreservesUnrelatedTTY() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-reset.jsonl")
        try write(metadata(sessionID) + event("task_started"), to: rollout)
        let process = process()
        var calls = 0
        let monitor = CodexSessionMonitor(processProvider: { _ in calls += 1; return calls == 1 ? [process] : [] }, rolloutProvider: { _ in [rollout] })
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.status, .running)
        let generation = monitor.scanGeneration()
        monitor.reset(ttys: ["/dev/ttys099"])
        XCTAssertTrue(monitor.observations(in: [tty], expectedGeneration: generation).isEmpty)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(monitor.observations(in: [tty])[tty]?.status, .running)
        monitor.reset()
        XCTAssertNil(monitor.observations(in: [tty])[tty])
    }

    func testFileGrowthWithoutLifecycleRemainsUnknown() throws {
        let rollout = try temporaryDirectory().appendingPathComponent("rollout-unknown.jsonl")
        try write(metadata(sessionID), to: rollout)
        let process = process()
        let monitor = CodexSessionMonitor(processProvider: { _ in [process] }, rolloutProvider: { _ in [rollout] })
        XCTAssertNil(monitor.observations(in: [tty])[tty]?.status)
        try append(Data("{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":\"output\"}}\n".utf8), to: rollout)
        XCTAssertNil(monitor.observations(in: [tty])[tty]?.status)
    }
}
