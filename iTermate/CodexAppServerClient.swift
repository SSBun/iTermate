import CryptoKit
import Darwin
import Foundation
import Network

/// Reads an explicitly identified thread from an already running local Codex daemon.
struct CodexAppServerClient {
    struct RuntimeObservation: Equatable {
        let status: TerminalSessionStatus?
        let changedAt: TimeInterval?
        let latestCompletion: SessionCompletion?
        let recentCompletions: [SessionCompletion]
        var completionInProgressID: String? = nil
        /// An exact daemon-supplied path whose file identity and thread metadata still require validation.
        var rolloutPath: String? = nil
        let sessionID: String
    }

    struct ThreadState: Decodable {
        struct Status: Decodable {
            let type: String
            let activeFlags: [String]?
        }

        let id: String
        let status: Status
        let path: String?

        init(id: String, status: Status, path: String? = nil) {
            self.id = id
            self.status = status
            self.path = path
        }

        private enum CodingKeys: String, CodingKey {
            case id, status, path
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            status = try container.decode(Status.self, forKey: .status)
            // The upstream path is optional and unstable; its format must not break status reads.
            path = try? container.decode(String.self, forKey: .path)
        }
    }

    struct Turn: Decodable {
        let id: String
        let status: String
        let startedAt: TimeInterval?
        let completedAt: TimeInterval?
    }

    private let socketPath: String

    init(
        socketPath: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        let codexHome = environment["CODEX_HOME"]
            ?? homeDirectory.appendingPathComponent(".codex", isDirectory: true).path
        self.socketPath = socketPath
            ?? codexHome + "/app-server-control/app-server-control.sock"
    }

    /// Queries metadata and recent turn outcomes, without resuming or subscribing to the thread.
    func observation(threadID: String, includeUnloadedHistory: Bool = false) async throws -> RuntimeObservation {
        let deadline = DispatchTime.now() + 3
        guard let identifier = UUID(uuidString: threadID), threadID.utf8.count == 36 else {
            throw CodexStatusError("Enter a complete Codex thread UUID.")
        }
        guard let resolvedSocketPath = Self.resolvedSocketPath(socketPath) else {
            throw CodexStatusError("The local Codex daemon socket is unavailable.")
        }
        let request = CodexStatusRequest(
            socketPath: resolvedSocketPath, threadID: identifier.uuidString.lowercased(), deadline: deadline,
            includeUnloadedHistory: includeUnloadedHistory
        )
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { request.start(continuation: $0) }
        } onCancel: {
            request.cancel()
        }
    }

    /// Resolves the official control symlink while requiring both it and the socket to belong to this user.
    static func resolvedSocketPath(_ path: String) -> String? {
        guard path.hasPrefix("/"), !path.utf8.contains(0) else { return nil }
        var link = stat()
        guard lstat(path, &link) == 0, link.st_uid == geteuid(),
              [S_IFSOCK, S_IFLNK].contains(link.st_mode & S_IFMT) else { return nil }
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        var target = stat()
        guard lstat(resolved, &target) == 0,
              target.st_mode & S_IFMT == S_IFSOCK, target.st_uid == geteuid() else { return nil }
        return resolved
    }

    /// Maps runtime state independently from durable turn completion evidence.
    static func observation(
        thread: ThreadState, turns: [Turn], includeUnloadedHistory: Bool = false
    ) -> RuntimeObservation {
        let threadID = UUID(uuidString: thread.id)?.uuidString.lowercased() ?? thread.id.lowercased()
        let rolloutPath = thread.path.flatMap { path -> String? in
            guard path.hasPrefix("/"), path.utf8.count < Int(MAXPATHLEN), !path.utf8.contains(0) else {
                return nil
            }
            let url = URL(fileURLWithPath: path)
            return url.lastPathComponent.hasPrefix("rollout-") && url.pathExtension == "jsonl" ? path : nil
        }
        guard ["active", "idle"].contains(thread.status.type)
                || (includeUnloadedHistory && thread.status.type == "notLoaded") else {
            return RuntimeObservation(
                status: nil, changedAt: nil, latestCompletion: nil, recentCompletions: [],
                rolloutPath: rolloutPath, sessionID: threadID
            )
        }
        let completions = turns.compactMap { turn -> SessionCompletion? in
            guard ["completed", "failed"].contains(turn.status),
                  let completedAt = validTimestamp(turn.completedAt),
                  let identifier = UUID(uuidString: turn.id) else { return nil }
            return SessionCompletion(
                id: "codex:\(threadID):\(identifier.uuidString.lowercased())",
                completedAt: completedAt,
                exitStatus: turn.status == "failed" ? 1 : 0
            )
        }.sorted { lhs, rhs in
            lhs.completedAt == rhs.completedAt ? lhs.id < rhs.id : lhs.completedAt < rhs.completedAt
        }

        let status: TerminalSessionStatus?
        let changedAt: TimeInterval?
        let latest = turns.first
        if thread.status.type == "notLoaded" {
            // A final history read can recover durable events without asserting a live state.
            status = nil
            changedAt = nil
        } else if thread.status.type == "active" {
            if let flags = thread.status.activeFlags,
               flags.contains("waitingOnApproval") || flags.contains("waitingOnUserInput") {
                status = .awaitingInput
                changedAt = nil
            } else if thread.status.activeFlags?.isEmpty == true {
                status = .running
                changedAt = latest?.status == "inProgress" ? validTimestamp(latest?.startedAt) : nil
            } else {
                status = nil
                changedAt = nil
            }
        } else {
            switch latest?.status {
            case "completed", "failed": status = .finished
            case "interrupted": status = .interrupted
            case nil: status = .idle
            default: status = nil
            }
            changedAt = status == .finished || status == .interrupted
                ? validTimestamp(latest?.completedAt) : nil
        }
        return RuntimeObservation(
            status: status, changedAt: changedAt, latestCompletion: completions.last,
            recentCompletions: completions,
            completionInProgressID: thread.status.type == "active" && latest?.status == "inProgress"
                ? latest.flatMap { UUID(uuidString: $0.id) }.map { "codex:\(threadID):\($0.uuidString.lowercased())" }
                : nil,
            rolloutPath: rolloutPath,
            sessionID: threadID
        )
    }

    private static func validTimestamp(_ value: TimeInterval?) -> TimeInterval? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }
}

private struct CodexStatusError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// All request state and completion, including cancellation, are serialized on queue.
private final class CodexStatusRequest: @unchecked Sendable {
    private struct ThreadResult: Decodable {
        let thread: CodexAppServerClient.ThreadState
    }

    private struct TurnsResult: Decodable {
        let data: [CodexAppServerClient.Turn]
    }

    private let connection: NWConnection
    private let threadID: String
    private let deadline: DispatchTime
    private let includeUnloadedHistory: Bool
    private let queue = DispatchQueue(label: "com.caishilin.iTermate.codex-status")
    private let handshakeKey = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) }).base64EncodedString()
    private var continuation: CheckedContinuation<CodexAppServerClient.RuntimeObservation, Error>?
    private var timeout: DispatchWorkItem?
    private var finished = false
    private var upgraded = false
    private var buffer = Data()
    private var message = Data()
    private var fragmented = false
    private var frameCount = 0
    private var expectedID = "initialize"
    private var turns: [CodexAppServerClient.Turn] = []

    init(socketPath: String, threadID: String, deadline: DispatchTime, includeUnloadedHistory: Bool) {
        connection = NWConnection(to: .unix(path: socketPath), using: .tcp)
        self.threadID = threadID
        self.deadline = deadline
        self.includeUnloadedHistory = includeUnloadedHistory
    }

    func start(continuation: CheckedContinuation<CodexAppServerClient.RuntimeObservation, Error>) {
        queue.async {
            guard !self.finished else {
                continuation.resume(throwing: CancellationError())
                return
            }
            self.continuation = continuation
            guard DispatchTime.now() < self.deadline else {
                self.finish(.failure(CodexStatusError("The Codex status request timed out.")))
                return
            }
            let timeout = DispatchWorkItem {
                self.finish(.failure(CodexStatusError("The Codex status request timed out.")))
            }
            self.timeout = timeout
            self.queue.asyncAfter(deadline: self.deadline, execute: timeout)
            self.connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let header = "GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: \(self.handshakeKey)\r\nSec-WebSocket-Version: 13\r\n\r\n"
                    self.send(Data(header.utf8))
                    self.receive()
                case .failed, .waiting:
                    self.finish(.failure(CodexStatusError("Could not connect to the local Codex daemon.")))
                default: break
                }
            }
            self.connection.start(queue: self.queue)
        }
    }

    func cancel() {
        queue.async { self.finish(.failure(CancellationError())) }
    }

    private func receive() {
        guard !finished else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, ended, error in
            guard !self.finished else { return }
            do {
                if let data { self.buffer.append(data) }
                guard self.buffer.count <= CodexStatusWebSocket.maximumMessageSize + 8192 + 14 else {
                    throw CodexStatusError("The Codex response exceeded its size limit.")
                }
                try self.consume()
                if !self.finished, ended || error != nil {
                    throw CodexStatusError("Codex disconnected before returning its status.")
                }
                self.receive()
            } catch {
                self.finish(.failure(error as? CodexStatusError ?? CodexStatusError("Codex returned an invalid status response.")))
            }
        }
    }

    private func consume() throws {
        if !upgraded {
            guard let end = buffer.range(of: Data([13, 10, 13, 10])) else {
                guard buffer.count <= 8192 else { throw CodexStatusError("Invalid Codex WebSocket handshake.") }
                return
            }
            guard end.upperBound <= 8192 else { throw CodexStatusError("Invalid Codex WebSocket handshake.") }
            try CodexStatusWebSocket.validateHandshake(Data(buffer[..<end.upperBound]), key: handshakeKey)
            buffer = Data(buffer[end.upperBound...])
            upgraded = true
            try sendRequest("initialize", method: "initialize", parameters: [
                "clientInfo": ["name": "itermate_status", "title": "iTermate Status", "version": "1"],
                "capabilities": [
                    "experimentalApi": false,
                    "requestAttestation": false,
                    "optOutNotificationMethods": ["thread/started"]
                ]
            ])
        }
        while !finished, let frame = try CodexStatusWebSocket.consumeFrame(from: &buffer) {
            frameCount += 1
            guard frameCount <= 128 else { throw CodexStatusError("Codex sent too many status frames.") }
            switch frame.opcode {
            case 8: throw CodexStatusError("Codex closed the status connection.")
            case 9: send(CodexStatusWebSocket.frame(frame.payload, opcode: 10))
            case 10: break
            case 0, 1:
                guard frame.opcode == (fragmented ? 0 : 1) else {
                    throw CodexStatusError("Invalid Codex WebSocket fragmentation.")
                }
                message.append(frame.payload)
                guard message.count <= CodexStatusWebSocket.maximumMessageSize else {
                    throw CodexStatusError("The Codex response exceeded its size limit.")
                }
                fragmented = !frame.isFinal
                if frame.isFinal {
                    let data = message
                    message = Data()
                    try handleResponse(data)
                }
            default: throw CodexStatusError("Unsupported Codex WebSocket frame.")
            }
        }
    }

    private func handleResponse(_ data: Data) throws {
        guard String(data: data, encoding: .utf8) != nil,
              let reply = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexStatusError("Codex returned an invalid status response.")
        }
        if reply["method"] != nil {
            guard reply["id"] == nil else {
                throw CodexStatusError("Codex requested interaction on a read-only status connection.")
            }
            return
        }
        guard reply["id"] as? String == expectedID, reply["error"] == nil,
              let result = reply["result"] as? [String: Any] else {
            throw CodexStatusError("Codex did not confirm the requested status read.")
        }
        let resultData = try JSONSerialization.data(withJSONObject: result)
        switch expectedID {
        case "initialize":
            try sendJSON(["method": "initialized", "params": [:]])
            try readThread(id: "thread")
        case "thread", "finalThread":
            // Preview and other conversation fields are never retained or logged.
            let thread = try JSONDecoder().decode(ThreadResult.self, from: resultData).thread
            guard UUID(uuidString: thread.id) == UUID(uuidString: threadID) else {
                throw CodexStatusError("Codex returned a different thread.")
            }
            let canReadHistory = ["idle", "active"].contains(thread.status.type)
                || (includeUnloadedHistory && thread.status.type == "notLoaded")
            if expectedID == "finalThread" || !canReadHistory {
                finish(.success(CodexAppServerClient.observation(
                    thread: thread, turns: turns, includeUnloadedHistory: includeUnloadedHistory
                )))
            } else {
                try sendRequest("turns", method: "thread/turns/list", parameters: [
                    "threadId": threadID, "limit": 8, "sortDirection": "desc", "itemsView": "notLoaded"
                ])
            }
        case "turns":
            turns = try JSONDecoder().decode(TurnsResult.self, from: resultData).data
            guard turns.count <= 8 else { throw CodexStatusError("Codex exceeded the requested turn limit.") }
            // Re-read runtime state so a new active turn cannot inherit an earlier idle snapshot.
            try readThread(id: "finalThread")
        default: throw CodexStatusError("Unexpected Codex status response.")
        }
    }

    private func readThread(id: String) throws {
        try sendRequest(id, method: "thread/read", parameters: ["threadId": threadID, "includeTurns": false])
    }

    private func sendRequest(_ id: String, method: String, parameters: [String: Any]) throws {
        expectedID = id
        try sendJSON(["id": id, "method": method, "params": parameters])
    }

    private func sendJSON(_ value: [String: Any]) throws {
        send(CodexStatusWebSocket.frame(try JSONSerialization.data(withJSONObject: value)))
    }

    private func send(_ data: Data) {
        guard !finished else { return }
        connection.send(content: data, completion: .contentProcessed { error in
            if error != nil { self.finish(.failure(CodexStatusError("Could not send the Codex status request."))) }
        })
    }

    private func finish(_ result: Result<CodexAppServerClient.RuntimeObservation, Error>) {
        guard !finished else { return }
        finished = true
        timeout?.cancel()
        timeout = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
        buffer = Data()
        message = Data()
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}

/// The small bounded WebSocket transport required by Codex's Unix control socket.
enum CodexStatusWebSocket {
    static let maximumMessageSize = 262_144

    struct Frame {
        let opcode: UInt8
        let isFinal: Bool
        let payload: Data
    }

    static func validateHandshake(_ data: Data, key: String) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CodexStatusError("Invalid Codex WebSocket handshake.")
        }
        let lines = text.components(separatedBy: "\r\n")
        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            let pieces = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2 else { throw CodexStatusError("Invalid Codex WebSocket headers.") }
            let name = pieces[0].trimmingCharacters(in: .whitespaces).lowercased()
            guard headers[name] == nil else { throw CodexStatusError("Duplicate Codex WebSocket headers.") }
            headers[name] = pieces[1].trimmingCharacters(in: .whitespaces)
        }
        let digest = Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
        guard lines.first?.split(separator: " ").prefix(2) == ["HTTP/1.1", "101"],
              headers["upgrade"]?.lowercased() == "websocket",
              headers["connection"]?.lowercased().split(separator: ",").contains(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "upgrade"
              }) == true,
              headers["sec-websocket-accept"] == Data(digest).base64EncodedString(),
              headers["sec-websocket-extensions"] == nil,
              headers["sec-websocket-protocol"] == nil else {
            throw CodexStatusError("Codex did not accept the WebSocket handshake.")
        }
    }

    static func consumeFrame(from buffer: inout Data) throws -> Frame? {
        guard buffer.count >= 2 else { return nil }
        let first = buffer[0]
        let second = buffer[1]
        let opcode = first & 0x0f
        let isFinal = first & 0x80 != 0
        guard first & 0x70 == 0, second & 0x80 == 0, [0, 1, 8, 9, 10].contains(opcode) else {
            throw CodexStatusError("Invalid Codex WebSocket frame.")
        }
        let marker = second & 0x7f
        var length = UInt64(marker)
        var offset = 2
        if marker >= 126 {
            let byteCount = marker == 126 ? 2 : 8
            guard buffer.count >= offset + byteCount else { return nil }
            length = buffer[offset..<(offset + byteCount)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            offset += byteCount
            guard length >= (marker == 126 ? 126 : 65_536) else {
                throw CodexStatusError("Invalid Codex WebSocket frame length.")
            }
        }
        guard length <= maximumMessageSize, opcode < 8 || (isFinal && length <= 125),
              opcode != 8 || length != 1 else {
            throw CodexStatusError("The Codex WebSocket frame exceeded its limits.")
        }
        let end = offset + Int(length)
        guard buffer.count >= end else { return nil }
        let payload = Data(buffer[offset..<end])
        buffer = Data(buffer.dropFirst(end))
        return Frame(opcode: opcode, isFinal: isFinal, payload: payload)
    }

    static func frame(_ payload: Data, opcode: UInt8 = 1) -> Data {
        var data = Data([0x80 | opcode])
        if payload.count < 126 {
            data.append(0x80 | UInt8(payload.count))
        } else if payload.count <= 65_535 {
            data.append(0x80 | 126)
            data.append(UInt8(payload.count >> 8))
            data.append(UInt8(payload.count & 0xff))
        } else {
            data.append(0x80 | 127)
            let length = UInt64(payload.count)
            for shift in stride(from: 56, through: 0, by: -8) {
                data.append(UInt8((length >> shift) & 0xff))
            }
        }
        let mask = (0..<4).map { _ in UInt8.random(in: .min ... .max) }
        data.append(contentsOf: mask)
        data.append(contentsOf: payload.enumerated().map { $0.element ^ mask[$0.offset % 4] })
        return data
    }
}
