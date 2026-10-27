import Darwin
import Foundation
import XCTest
@testable import iTermate

final class CodexAppServerClientTests: XCTestCase {
    private let threadID = "019a1145-8980-7123-8abc-0123456789ab"
    private let turnID = "019a1145-8981-7123-8abc-0123456789ab"

    func testOfficialControlSocketSymlinkResolvesButRegularFilesDoNot() throws {
        let directory = URL(fileURLWithPath: "/tmp").appendingPathComponent("itermate-socket-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("daemon.sock")
        let control = directory.appendingPathComponent("control.sock")
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        guard descriptor >= 0 else { return }
        defer { Darwin.close(descriptor) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let path = Array(target.path.utf8CString)
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            for (index, value) in path.enumerated() { bytes[index] = UInt8(bitPattern: value) }
        }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        XCTAssertEqual(result, 0)
        guard result == 0 else { return }
        try FileManager.default.createSymbolicLink(at: control, withDestinationURL: target)
        XCTAssertEqual(CodexAppServerClient.resolvedSocketPath(control.path), target.resolvingSymlinksInPath().path)
        XCTAssertEqual(CodexAppServerClient.resolvedSocketPath(target.path), target.resolvingSymlinksInPath().path)
        try FileManager.default.removeItem(at: target)
        XCTAssertNil(CodexAppServerClient.resolvedSocketPath(control.path))
        try Data().write(to: target)
        XCTAssertNil(CodexAppServerClient.resolvedSocketPath(control.path))
        XCTAssertNil(CodexAppServerClient.resolvedSocketPath(target.path))
    }

    func testDaemonRolloutPathSurvivesUnknownLifecycleForTitleBackfill() throws {
        let path = "/Users/example/.codex/sessions/rollout-\(threadID).jsonl"
        for type in ["active", "idle", "notLoaded"] {
            let data = try JSONSerialization.data(withJSONObject: [
                "id": threadID, "status": ["type": type, "activeFlags": []], "path": path
            ])
            let thread = try JSONDecoder().decode(CodexAppServerClient.ThreadState.self, from: data)
            let result = CodexAppServerClient.observation(thread: thread, turns: [])
            XCTAssertEqual(result.rolloutPath, path)
            XCTAssertEqual(result.sessionID, threadID)
        }
    }

    func testUnavailableOrMalformedRolloutPathDoesNotBreakStatus() throws {
        let paths: [Any] = [
            NSNull(), 12, "rollout-relative.jsonl", "/tmp/other.jsonl", "/tmp/rollout-file.txt",
            "/tmp/rollout-\0.jsonl", "/tmp/rollout-" + String(repeating: "a", count: 1024) + ".jsonl"
        ]
        for path in paths {
            let data = try JSONSerialization.data(withJSONObject: [
                "id": threadID, "status": ["type": "active", "activeFlags": []], "path": path
            ])
            let thread = try JSONDecoder().decode(CodexAppServerClient.ThreadState.self, from: data)
            let result = CodexAppServerClient.observation(thread: thread, turns: [turn(status: "inProgress")])
            XCTAssertNil(result.rolloutPath)
            XCTAssertEqual(result.status, .running)
        }
        let data = try JSONSerialization.data(withJSONObject: [
            "id": threadID, "status": ["type": "idle"]
        ])
        let thread = try JSONDecoder().decode(CodexAppServerClient.ThreadState.self, from: data)
        XCTAssertNil(CodexAppServerClient.observation(thread: thread, turns: []).rolloutPath)
    }

    func testApprovalAndUserInputFlagsAreAuthoritativeWhileActive() {
        for flag in ["waitingOnApproval", "waitingOnUserInput"] {
            let observation = observation(type: "active", flags: [flag], turns: [turn(status: "inProgress")])
            XCTAssertEqual(observation.status, .awaitingInput)
            XCTAssertNil(observation.changedAt, "Turn start is not the time an approval prompt appeared.")
            XCTAssertNil(observation.latestCompletion)
        }
    }

    func testRunningRetainsARecordedEarlierCompletion() {
        let completed = turn(status: "completed", completedAt: 110)
        let active = CodexAppServerClient.Turn(
            id: "019a1145-8982-7123-8abc-0123456789ab", status: "inProgress", startedAt: 120, completedAt: nil
        )
        let observation = observation(type: "active", flags: [], turns: [active, completed])
        XCTAssertEqual(observation.status, .running)
        XCTAssertEqual(observation.completionInProgressID,
                       "codex:\(threadID):019a1145-8982-7123-8abc-0123456789ab")
        XCTAssertEqual(observation.changedAt, 120)
        XCTAssertEqual(observation.latestCompletion?.completedAt, 110)
        XCTAssertEqual(observation.latestCompletion?.exitStatus, 0)
        XCTAssertEqual(observation.latestCompletion?.id, "codex:\(threadID):\(turnID)")
    }

    func testFailureAndInterruptionHaveDifferentOutcomes() {
        let failure = observation(type: "idle", turns: [turn(status: "failed", completedAt: 110)])
        XCTAssertEqual(failure.status, .finished)
        XCTAssertEqual(failure.changedAt, 110)
        XCTAssertEqual(failure.latestCompletion?.exitStatus, 1)

        let interruption = observation(type: "idle", turns: [turn(status: "interrupted", completedAt: 110)])
        XCTAssertEqual(interruption.status, .interrupted)
        XCTAssertNil(interruption.latestCompletion)
    }

    func testRecentCompletionsIncludeEveryValidOutcomeInAscendingOrder() {
        let newer = CodexAppServerClient.Turn(
            id: "019a1145-8982-7123-8abc-0123456789ab", status: "failed", startedAt: 120, completedAt: 130
        )
        let result = observation(type: "idle", turns: [
            newer, turn(status: "completed", completedAt: 110),
            turn(status: "interrupted", completedAt: 105), turn(status: "completed")
        ])
        XCTAssertEqual(result.recentCompletions.map(\.completedAt), [110, 130])
        XCTAssertEqual(result.recentCompletions.map(\.exitStatus), [0, 1])
        XCTAssertEqual(result.latestCompletion, result.recentCompletions.last)
    }

    func testMissingOrInvalidTimeDoesNotInventCompletionEvidence() {
        for timestamp in [nil, 0, -1, .infinity, .nan] as [TimeInterval?] {
            let result = observation(type: "idle", turns: [turn(status: "completed", completedAt: timestamp)])
            XCTAssertEqual(result.status, .finished)
            XCTAssertNil(result.changedAt)
            XCTAssertNil(result.latestCompletion)
            XCTAssertTrue(result.recentCompletions.isEmpty)
        }
    }

    func testUnloadedOrBrokenRuntimeDoesNotTreatStoredHistoryAsLiveState() {
        for type in ["notLoaded", "systemError", "futureStatus"] {
            let result = observation(type: type, turns: [turn(status: "completed", completedAt: 110)])
            XCTAssertNil(result.status)
            XCTAssertNil(result.changedAt)
            XCTAssertNil(result.latestCompletion)
            XCTAssertTrue(result.recentCompletions.isEmpty)
        }
    }

    func testExplicitFinalHistoryReadRecoversEventsWithoutClaimingLiveState() {
        for latestStatus in ["completed", "failed", "inProgress", "interrupted"] {
            let result = CodexAppServerClient.observation(
                thread: .init(id: threadID, status: .init(type: "notLoaded", activeFlags: nil)),
                turns: [
                    .init(id: "019a1145-8982-7123-8abc-0123456789ab", status: latestStatus,
                          startedAt: 120, completedAt: latestStatus == "inProgress" ? nil : 130),
                    turn(status: "completed", completedAt: 110)
                ],
                includeUnloadedHistory: true
            )
            XCTAssertNil(result.status)
            XCTAssertNil(result.changedAt)
            let expectedTimes: [TimeInterval] = ["completed", "failed"].contains(latestStatus) ? [110, 130] : [110]
            XCTAssertEqual(result.recentCompletions.map(\.completedAt), expectedTimes)
            XCTAssertEqual(result.latestCompletion, result.recentCompletions.last)
        }
    }

    func testFinalHistoryReadStillRejectsBrokenOrUnknownRuntime() {
        for type in ["systemError", "futureStatus"] {
            let result = CodexAppServerClient.observation(
                thread: .init(id: threadID, status: .init(type: type, activeFlags: nil)),
                turns: [turn(status: "completed", completedAt: 110)], includeUnloadedHistory: true
            )
            XCTAssertNil(result.status)
            XCTAssertNil(result.changedAt)
            XCTAssertNil(result.latestCompletion)
            XCTAssertTrue(result.recentCompletions.isEmpty)
        }
    }

    func testUnknownFlagsAndInconsistentIdleSnapshotRemainUnknown() {
        XCTAssertNil(observation(type: "active", flags: nil, turns: []).status)
        XCTAssertNil(observation(type: "active", flags: ["futureWaitReason"], turns: []).status)
        XCTAssertNil(observation(type: "idle", turns: [turn(status: "inProgress")]).status)
        XCTAssertEqual(observation(type: "idle", turns: []).status, .idle)
    }

    func testWebSocketHandshakeChecksAcceptAndUpgrade() throws {
        let response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n"
        try CodexStatusWebSocket.validateHandshake(Data(response.utf8), key: "dGhlIHNhbXBsZSBub25jZQ==")
        XCTAssertThrowsError(try CodexStatusWebSocket.validateHandshake(Data(response.utf8), key: "wrong"))
        XCTAssertThrowsError(try CodexStatusWebSocket.validateHandshake(
            Data(response.replacingOccurrences(of: "101", with: "200").utf8), key: "dGhlIHNhbXBsZSBub25jZQ=="
        ))
    }

    func testWebSocketParserRetainsIncompleteFramesAndConsumesOneAtATime() throws {
        var buffer = Data([0x81, 3, 65])
        XCTAssertNil(try CodexStatusWebSocket.consumeFrame(from: &buffer))
        XCTAssertEqual(buffer, Data([0x81, 3, 65]))
        buffer.append(contentsOf: [66, 67, 0x89, 0])
        let text = try XCTUnwrap(CodexStatusWebSocket.consumeFrame(from: &buffer))
        XCTAssertEqual(text.payload, Data("ABC".utf8))
        XCTAssertEqual(text.opcode, 1)
        XCTAssertTrue(text.isFinal)
        XCTAssertEqual(try CodexStatusWebSocket.consumeFrame(from: &buffer)?.opcode, 9)
        XCTAssertTrue(buffer.isEmpty)
    }

    func testWebSocketParserRejectsMaskedServerFramesAndOversizedLengths() {
        for frame in [
            Data([0x81, 0x80, 1, 2, 3, 4]),
            Data([0x89, 126, 0, 126]),
            Data([0x81, 127, 0, 0, 0, 0, 0, 16, 0, 0]),
            Data([0xc1, 0]),
            Data([0x09, 0]),
            Data([0x88, 1, 0])
        ] {
            var buffer = frame
            XCTAssertThrowsError(try CodexStatusWebSocket.consumeFrame(from: &buffer))
        }
    }

    func testOutgoingFramesMaskEveryPayloadByte() {
        let payload = Data("{\"id\":\"initialize\"}".utf8)
        let frame = CodexStatusWebSocket.frame(payload)
        XCTAssertEqual(frame[0], 0x81)
        XCTAssertEqual(frame[1], 0x80 | UInt8(payload.count))
        let mask = Array(frame[2..<6])
        let decoded = Data(frame.dropFirst(6).enumerated().map { $0.element ^ mask[$0.offset % 4] })
        XCTAssertEqual(decoded, payload)
    }

    private func observation(
        type: String,
        flags: [String]? = [],
        turns: [CodexAppServerClient.Turn]
    ) -> CodexAppServerClient.RuntimeObservation {
        CodexAppServerClient.observation(
            thread: .init(id: threadID, status: .init(type: type, activeFlags: flags)), turns: turns
        )
    }

    private func turn(status: String, completedAt: TimeInterval? = nil) -> CodexAppServerClient.Turn {
        .init(id: turnID, status: status, startedAt: 100, completedAt: completedAt)
    }
}
