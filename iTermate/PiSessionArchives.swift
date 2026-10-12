import AppKit
import CryptoKit
import Darwin
import Foundation
import Network
import SwiftUI

struct PiArchiveRecord: Codable, Identifiable, Equatable, Sendable {
    let version: Int
    let id: String
    let sessionId: String
    let name: String
    let cwd: String
    let archivedAt: TimeInterval
    let filename: String
    let sha256: String
    let originalSessionFile: String
    let terminal: String
    let summary: String?

    var terminalApp: TerminalApp { terminal == "Ghostty" ? .ghostty : .iTerm2 }
}

private struct LivePiSession: Decodable {
    let version: Int
    let id: String
    let pid: Int32
    let parentPid: Int32
    let token: String
    let socketPath: String
    let terminal: String
    let terminalSessionId: String?
    let tty: String?
    let sessionId: String
    let sessionFile: String
    let cwd: String
    let name: String
    let canArchive: Bool
    let supportsSummary: Bool?
    let supportsStatus: Bool?
    let updatedAt: TimeInterval
}

/// An authenticated observation, not a command to advance or terminate the Pi session.
struct PiStatusSnapshot: Decodable {
    let version: Int
    let instanceId: String
    let sessionId: String
    let reporterId: String
    let sequence: Int
    let status: TerminalSessionStatus?
    let exitStatus: Int?
    let hasRunningSubagents: Bool

    var isValid: Bool {
        version == 1 && UUID(uuidString: reporterId) != nil && sequence > 0
            && sequence <= 9_007_199_254_740_991
            && (status == .finished ? exitStatus.map { (0...255).contains($0) } == true : exitStatus == nil)
            && (!hasRunningSubagents || status == .running || status == .awaitingInput)
    }
}

struct PiResumeLocation: Sendable {
    let directory: URL
    let sessionID: String
    let cwd: String
}

/// Owns private archive discovery and verified copies, not terminal state inference.
final class PiSessionArchives: ObservableObject {
    static let archiveRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/iTermate/ArchivedPiSessions", isDirectory: true)
    static let liveRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".iTermate/pi-live", isDirectory: true)
    static let resumeRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/iTermate/ResumedPiSessions", isDirectory: true)

    @Published private(set) var records: [PiArchiveRecord] = []
    @Published private(set) var isBusy = false
    @Published var error: String?
    @Published private var liveSessions: [LivePiSession] = []
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refreshLiveSessions() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        refreshLiveSessions()
        let folders = (try? FileManager.default.contentsOfDirectory(at: Self.archiveRoot,
            includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        records = folders.compactMap { folder in
            guard UUID(uuidString: folder.lastPathComponent) != nil else { return nil }
            return try? Self.readManifest(at: folder)
        }.sorted { $0.archivedAt > $1.archivedAt }
    }

    private func refreshLiveSessions() {
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.liveRoot,
            includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        liveSessions = files.filter { $0.pathExtension == "json" }.compactMap { file in
            guard let data = try? Self.boundedData(at: file, maximum: 16384),
                  let session = try? JSONDecoder().decode(LivePiSession.self, from: data),
                  session.version == 1, UUID(uuidString: session.id) != nil,
                  session.pid > 1, session.parentPid > 1, kill(session.pid, 0) == 0,
                  Self.validSessionID(session.sessionId),
                  session.socketPath == Self.liveRoot.appendingPathComponent(String(session.id.prefix(16)) + ".sock").path,
                  session.token.count == 64, session.token.allSatisfy({ $0.isHexDigit }),
                  (0...8).contains(Date().timeIntervalSince1970 - session.updatedAt)
            else { return nil }
            return session
        }
    }

    private func descriptor(for session: TerminalSessionSnapshot, terminal: TerminalApp) -> LivePiSession? {
        let matches = liveSessions.filter { live in
            guard live.terminal == terminal.displayName else { return false }
            return terminal == .iTerm2 ? live.terminalSessionId == session.id
                : (session.tty != nil && live.tty == session.tty)
        }
        return matches.count == 1 ? matches.first : nil
    }

    func canQueryStatus(_ session: TerminalSessionSnapshot, terminal: TerminalApp) -> Bool {
        descriptor(for: session, terminal: terminal)?.supportsStatus == true
    }

    @MainActor
    func queryStatus(_ session: TerminalSessionSnapshot, terminal: TerminalApp) async throws -> PiStatusSnapshot? {
        refreshLiveSessions()
        guard let live = descriptor(for: session, terminal: terminal), live.supportsStatus == true else { return nil }
        let data = try await PiArchiveRPC.response(socketPath: live.socketPath, payload: [
            "action": "status", "token": live.token, "sessionId": live.sessionId,
        ], timeout: 3)
        let snapshot = try JSONDecoder().decode(PiStatusSnapshot.self, from: data)
        refreshLiveSessions()
        guard let current = descriptor(for: session, terminal: terminal),
              current.id == live.id, current.pid == live.pid, current.sessionId == live.sessionId,
              snapshot.instanceId == live.id, snapshot.sessionId == live.sessionId,
              snapshot.isValid else { return nil }
        return snapshot
    }

    func canArchive(_ session: TerminalSessionSnapshot, terminal: TerminalApp) -> Bool {
        guard !isBusy, session.activityKind == .agent, session.status != .running,
              session.hasRunningSubagents != true, let live = descriptor(for: session, terminal: terminal)
        else { return false }
        return live.canArchive && live.supportsSummary == true && !live.sessionFile.isEmpty
    }

    /// Requests a snapshot from the identified Pi process, verifies it, then waits for graceful exit.
    @MainActor
    func archive(_ session: TerminalSessionSnapshot, terminal: TerminalApp) async throws -> Int32 {
        refreshLiveSessions()
        guard canArchive(session, terminal: terminal), let live = descriptor(for: session, terminal: terminal) else {
            throw PiArchiveError("Pi is busy or its identity is unavailable. Install/reload the Pi integration and retry when idle.")
        }
        isBusy = true
        error = nil
        defer { isBusy = false; refresh() }
        let archiveID = try await PiArchiveRPC.request(socketPath: live.socketPath, payload: [
            "action": "archive", "sessionId": live.sessionId, "token": live.token,
        ])
        guard UUID(uuidString: archiveID) != nil else { throw PiArchiveError("Invalid archive response; terminal was not closed.") }
        let root = Self.archiveRoot
        let record = try await Task.detached(priority: .utility) {
            try Self.validatedArchive(at: root.appendingPathComponent(archiveID))
        }.value
        guard record.sessionId == live.sessionId, record.cwd == live.cwd, record.summary != nil else {
            throw PiArchiveError("Archive identity verification failed; terminal was not closed.")
        }
        for _ in 0..<100 {
            if kill(live.pid, 0) != 0 && errno == ESRCH {
                refreshLiveSessions()
                guard descriptor(for: session, terminal: terminal) == nil else {
                    throw PiArchiveError("A new Pi session is using this terminal. Archive saved; terminal left open.")
                }
                return live.parentPid
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw PiArchiveError("Archive saved, but Pi has not exited. The terminal was left open.")
    }

    /// Moves only the selected archive to Trash, preserving original sessions and resume copies.
    @MainActor
    func delete(_ record: PiArchiveRecord) async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false; refresh() }
        do {
            try await Task.detached(priority: .utility) {
                guard UUID(uuidString: record.id) != nil else {
                    throw PiArchiveError("Invalid archive identity.")
                }
                let folder = Self.archiveRoot.appendingPathComponent(record.id, isDirectory: true)
                let current = try Self.readManifest(at: folder)
                guard current == record else {
                    throw PiArchiveError("Archive metadata changed. Refresh and retry.")
                }
                try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
            }.value
        } catch {
            self.error = "Could not delete archive: \(error.localizedDescription)"
        }
    }

    /// Makes a writable resume copy so later conversation entries cannot change the archive.
    @MainActor
    func prepareResume(_ record: PiArchiveRecord) async throws -> PiResumeLocation {
        guard !isBusy else { throw PiArchiveError("Another archive operation is in progress.") }
        refreshLiveSessions()
        guard !liveSessions.contains(where: { $0.sessionId == record.sessionId }) else {
            throw PiArchiveError("This Pi session is already active. Close it before resuming the archive.")
        }
        isBusy = true
        error = nil
        var prepared = false
        defer { if !prepared { isBusy = false } }
        let location = try await Task.detached(priority: .utility) {
            let folder = Self.archiveRoot.appendingPathComponent(record.id)
            let current = try Self.validatedArchive(at: folder)
            guard current == record else { throw PiArchiveError("Archive metadata changed. Refresh and retry.") }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: record.cwd, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw PiArchiveError("The original working directory no longer exists.")
            }
            try FileManager.default.createDirectory(at: Self.resumeRoot, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: Self.resumeRoot.path)
            let destination = Self.resumeRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            do {
                let data = try Self.boundedData(at: folder.appendingPathComponent(record.filename), maximum: 64 * 1024 * 1024)
                guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == record.sha256 else {
                    throw PiArchiveError("Archive changed while preparing the resume copy.")
                }
                try data.write(to: destination.appendingPathComponent(record.filename), options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.appendingPathComponent(record.filename).path)
                return PiResumeLocation(directory: destination, sessionID: record.sessionId, cwd: record.cwd)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }.value
        prepared = true
        return location
    }

    /// Confirms that the intended Pi file, not merely a new terminal, was opened.
    @MainActor
    func waitForResume(_ location: PiResumeLocation) async throws {
        let expectedFile = location.directory.appendingPathComponent("archive_\(location.sessionID).jsonl").path
        for _ in 0..<50 {
            refreshLiveSessions()
            if liveSessions.contains(where: { $0.sessionId == location.sessionID && $0.sessionFile == expectedFile }) { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw PiArchiveError("Terminal opened, but Pi resume was not confirmed. Check the pi command, permissions and integration. The archive is unchanged.")
    }

    func finishResume(error: String?) {
        isBusy = false
        self.error = error
        refresh()
    }

    private static func validSessionID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9](?:[A-Za-z0-9._-]{0,126}[A-Za-z0-9])?$", options: .regularExpression) != nil
    }

    private static func boundedData(at url: URL, maximum: Int) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard size.isRegularFile == true, let count = size.fileSize, count <= maximum else {
            throw PiArchiveError("Archive file is missing, invalid or too large.")
        }
        let data = try Data(contentsOf: url)
        guard data.count <= maximum else { throw PiArchiveError("Archive size changed while reading.") }
        return data
    }

    private static func readManifest(at folder: URL) throws -> PiArchiveRecord {
        guard UUID(uuidString: folder.lastPathComponent) != nil,
              folder.resolvingSymlinksInPath().standardizedFileURL == folder.standardizedFileURL else {
            throw PiArchiveError("Invalid archive directory.")
        }
        let record = try JSONDecoder().decode(PiArchiveRecord.self,
            from: boundedData(at: folder.appendingPathComponent("manifest.json"), maximum: 16384))
        guard record.version == 1, record.id == folder.lastPathComponent,
              validSessionID(record.sessionId), record.filename == "archive_\(record.sessionId).jsonl",
              record.cwd.hasPrefix("/"), !record.cwd.contains("\0"), record.cwd.utf8.count <= 4096,
              record.sha256.count == 64, record.sha256.allSatisfy({ $0.isHexDigit }),
              record.archivedAt.isFinite, ["iTerm2", "Ghostty"].contains(record.terminal),
              record.summary.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && $0.utf8.count <= 4800 }) ?? true else {
            throw PiArchiveError("Invalid archive metadata.")
        }
        return record
    }

    /// Checks the manifest, immutable transcript checksum and native Pi identity.
    static func validatedArchive(at folder: URL) throws -> PiArchiveRecord {
        let record = try readManifest(at: folder)
        let file = folder.appendingPathComponent(record.filename)
        guard file.resolvingSymlinksInPath().standardizedFileURL == file.standardizedFileURL else {
            throw PiArchiveError("Archive transcript must not be a symbolic link.")
        }
        let data = try boundedData(at: file, maximum: 64 * 1024 * 1024)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == record.sha256, let newline = data.firstIndex(of: 0x0a),
              let header = try JSONSerialization.jsonObject(with: Data(data[..<newline])) as? [String: Any],
              header["type"] as? String == "session", header["id"] as? String == record.sessionId,
              header["cwd"] as? String == record.cwd else {
            throw PiArchiveError("Archive checksum or Pi session header verification failed.")
        }
        return record
    }
}

private struct PiArchiveError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// Network callbacks and timeout completion share one serial queue; mutable
// buffer/completion state is never accessed outside that queue after start.
private final class PiArchiveRPC: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.caishilin.iTermate.pi-archive")
    private var buffer = Data()
    private var completion: ((Result<Data, Error>) -> Void)?

    private init(socketPath: String, completion: @escaping (Result<Data, Error>) -> Void) {
        connection = NWConnection(to: .unix(path: socketPath), using: .tcp)
        self.completion = completion
    }

    static func request(socketPath: String, payload: [String: String]) async throws -> String {
        let data = try await response(socketPath: socketPath, payload: payload, timeout: 90)
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = value["archiveId"] as? String else {
            throw PiArchiveError("Pi did not confirm the archive.")
        }
        return id
    }

    static func response(socketPath: String, payload: [String: String], timeout: TimeInterval) async throws -> Data {
        var data = try JSONEncoder().encode(payload)
        data.append(0x0a)
        let payloadData = data
        return try await withCheckedThrowingContinuation { continuation in
            let rpc = PiArchiveRPC(socketPath: socketPath) { continuation.resume(with: $0) }
            rpc.connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    rpc.connection.send(content: payloadData, completion: .contentProcessed { error in
                        if error != nil { rpc.finish(.failure(PiArchiveError("Could not request Pi archive."))) }
                        else { rpc.receive() }
                    })
                case .failed, .waiting:
                    rpc.finish(.failure(PiArchiveError("The Pi integration is unavailable. Reload it and retry.")))
                default: break
                }
            }
            rpc.queue.asyncAfter(deadline: .now() + timeout) {
                rpc.finish(.failure(PiArchiveError("Pi archive request timed out. Check Archives before retrying; the terminal was not closed.")))
            }
            rpc.connection.start(queue: rpc.queue)
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, ended, error in
            if let data { self.buffer.append(data) }
            guard self.buffer.count <= 8192 else {
                self.finish(.failure(PiArchiveError("Pi archive response was too large."))); return
            }
            if let newline = self.buffer.firstIndex(of: 0x0a),
               let value = try? JSONSerialization.jsonObject(with: Data(self.buffer[..<newline])) as? [String: Any] {
                if value["ok"] as? Bool == true {
                    self.finish(.success(Data(self.buffer[..<newline])))
                } else {
                    self.finish(.failure(PiArchiveError(value["error"] as? String ?? "Pi refused the archive request.")))
                }
            } else if ended || error != nil {
                self.finish(.failure(PiArchiveError("Pi disconnected before confirming the archive.")))
            } else { self.receive() }
        }
    }

    private func finish(_ result: Result<Data, Error>) {
        guard let completion else { return }
        self.completion = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
        completion(result)
    }
}

struct PiArchivesSettingsView: View {
    @ObservedObject var archives: PiSessionArchives
    @ObservedObject var store: ItermStore

    var body: some View {
        Form {
            Section("Archived Pi Sessions") {
                Text("Private local snapshots. Resume opens a new terminal in the original working directory using a writable copy; the archive and original Pi file remain unchanged.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Refresh") { archives.refresh() }
                if let error = archives.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                if archives.records.isEmpty { Text("No archived Pi sessions.").foregroundStyle(.secondary) }
                ForEach(archives.records) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(record.name).font(.headline).lineLimit(1)
                            Spacer()
                            Button("Resume in \(record.terminal)") { store.resumePiArchive(record) }
                                .disabled(archives.isBusy)
                        }
                        Text(record.cwd).font(.caption).textSelection(.enabled)
                        Text("Session ID: \(record.sessionId)").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        Text(Date(timeIntervalSince1970: record.archivedAt), style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                    .help(record.summary ?? "No summary available for this archive.")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { archives.refresh() }
    }
}
