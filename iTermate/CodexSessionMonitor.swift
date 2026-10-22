import Darwin
import Foundation

struct CodexSessionObservation: Equatable {
    let status: TerminalSessionStatus?
    let changedAt: TimeInterval?
    let processIdentity: CodexSessionMonitor.ProcessIdentity?
    let titleExcerpt: String?

    init(
        status: TerminalSessionStatus?,
        changedAt: TimeInterval?,
        processIdentity: CodexSessionMonitor.ProcessIdentity? = nil,
        titleExcerpt: String? = nil
    ) {
        self.status = status
        self.changedAt = changedAt
        self.processIdentity = processIdentity
        self.titleExcerpt = titleExcerpt
    }
}

/// Passively observes original Codex CLI sessions without hooks or command wrappers.
final class CodexSessionMonitor {
    struct ProcessIdentity: Hashable {
        let pid: pid_t
        let startedAt: TimeInterval
    }

    struct CodexProcess {
        let identity: ProcessIdentity
        let tty: String
        let cwd: String
        let arguments: [String]
    }

    private struct SessionMetadata: Decodable {
        struct Payload: Decodable {
            let cwd: String
            let source: Source
        }

        enum Source: Decodable, Equatable {
            case root
            case subagent

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                self = (try? container.decode(String.self)) == nil ? .subagent : .root
            }
        }

        let timestamp: String?
        let type: String
        let payload: Payload
    }

    private let fileManager: FileManager
    private let sessionsDirectory: URL
    private let processProvider: ((Set<String>) -> [CodexProcess])?
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var rolloutByProcess: [ProcessIdentity: URL] = [:]
    private var resolutionAttempts: [ProcessIdentity: Int] = [:]
    private var observationByProcess: [ProcessIdentity: CodexSessionObservation] = [:]
    private var missedScansByProcess: [ProcessIdentity: Int] = [:]
    private var rolloutLengthByProcess: [ProcessIdentity: UInt64] = [:]
    private var ttyByProcess: [ProcessIdentity: String] = [:]

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        processProvider: ((Set<String>) -> [CodexProcess])? = nil
    ) {
        self.fileManager = fileManager
        self.processProvider = processProvider
        sessionsDirectory = homeDirectory.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    /// Returns observations keyed by the visible terminal TTY of each original Codex CLI.
    func scanGeneration() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    func observations(
        in ttys: Set<String>,
        expectedGeneration: UInt64? = nil
    ) -> [String: CodexSessionObservation] {
        lock.lock()
        defer { lock.unlock() }
        guard expectedGeneration == nil || expectedGeneration == generation else { return [:] }
        let processes = processProvider?(ttys) ?? ttys.compactMap(codexProcess(on:))
        let identities = Set(processes.map(\.identity))
        var retainedIdentities = identities
        let previousObservations = observationByProcess
        let previousTTYs = ttyByProcess
        var observations: [String: CodexSessionObservation] = [:]

        for process in processes {
            missedScansByProcess[process.identity] = nil
            var rollout = rolloutByProcess[process.identity]
            if rollout == nil, resolutionAttempts[process.identity, default: 0] < 15 {
                resolutionAttempts[process.identity, default: 0] += 1
                rollout = resolveRollout(for: process)
            }
            if let rollout {
                rolloutByProcess[process.identity] = rollout
                resolutionAttempts[process.identity] = nil
            }
            let rolloutLength = rollout.flatMap(fileLength(at:))
            let observation = rollout.flatMap(observation(at:))
                ?? CodexSessionObservation(status: nil, changedAt: nil)
            let resolved = Self.resolvedObservation(
                observation,
                previous: previousObservations[process.identity],
                rolloutGrew: rolloutLength.map {
                    $0 > rolloutLengthByProcess[process.identity, default: $0]
                } ?? false
            )
            let identified = CodexSessionObservation(
                status: resolved.status,
                changedAt: resolved.changedAt,
                processIdentity: process.identity,
                titleExcerpt: resolved.titleExcerpt
            )
            observations[process.tty] = identified
            ttyByProcess[process.identity] = process.tty
            rolloutLengthByProcess[process.identity] = rolloutLength
            observationByProcess[process.identity] = identified
        }

        for (identity, observation) in previousObservations
        where !identities.contains(identity) {
            guard let tty = previousTTYs[identity], ttys.contains(tty), observations[tty] == nil else {
                continue
            }
            let missedScans = missedScansByProcess[identity, default: 0] + 1
            missedScansByProcess[identity] = missedScans
            observations[tty] = Self.observationAfterMissingScan(
                observation,
                missedScans: missedScans
            )
            if missedScans <= 2 {
                retainedIdentities.insert(identity)
            }
        }

        rolloutByProcess = rolloutByProcess.filter { retainedIdentities.contains($0.key) }
        resolutionAttempts = resolutionAttempts.filter { retainedIdentities.contains($0.key) }
        observationByProcess = observationByProcess.filter { retainedIdentities.contains($0.key) }
        missedScansByProcess = missedScansByProcess.filter { retainedIdentities.contains($0.key) }
        rolloutLengthByProcess = rolloutLengthByProcess.filter { retainedIdentities.contains($0.key) }
        ttyByProcess = ttyByProcess.filter { retainedIdentities.contains($0.key) }
        return observations
    }

    func reset(ttys: Set<String>? = nil) {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        guard let ttys else {
            rolloutByProcess.removeAll()
            resolutionAttempts.removeAll()
            observationByProcess.removeAll()
            missedScansByProcess.removeAll()
            rolloutLengthByProcess.removeAll()
            ttyByProcess.removeAll()
            return
        }
        let removedIdentities = Set(ttyByProcess.compactMap { ttys.contains($0.value) ? $0.key : nil })
        rolloutByProcess = rolloutByProcess.filter { !removedIdentities.contains($0.key) }
        resolutionAttempts = resolutionAttempts.filter { !removedIdentities.contains($0.key) }
        observationByProcess = observationByProcess.filter { !removedIdentities.contains($0.key) }
        missedScansByProcess = missedScansByProcess.filter { !removedIdentities.contains($0.key) }
        rolloutLengthByProcess = rolloutLengthByProcess.filter { !removedIdentities.contains($0.key) }
        ttyByProcess = ttyByProcess.filter { !removedIdentities.contains($0.key) }
    }

    private func codexProcess(on tty: String) -> CodexProcess? {
        guard let device = terminalDevice(for: tty) else { return nil }
        var visited: Set<pid_t> = []
        return processIDs(type: UInt32(PROC_TTY_ONLY), value: device)
            .compactMap(processInfo)
            .filter {
                $0.pbi_uid == getuid()
                    && $0.pbi_pgid == $0.e_tpgid
                    && $0.e_tdev == device
            }
            .compactMap { codexProcess(in: $0, visibleTTY: tty, depth: 0, visited: &visited) }
            .first
    }

    private func codexProcess(
        in parent: proc_bsdinfo,
        visibleTTY: String,
        depth: Int,
        visited: inout Set<pid_t>
    ) -> CodexProcess? {
        let pid = pid_t(parent.pbi_pid)
        guard depth <= 8, visited.count < 128, visited.insert(pid).inserted else { return nil }
        if parent.pbi_pgid == parent.e_tpgid,
           let arguments = arguments(of: pid), Self.isCodexCLI(arguments),
           let cwd = workingDirectory(of: pid),
           let current = processInfo(pid), sameProcess(parent, current) {
            return CodexProcess(
                identity: ProcessIdentity(
                    pid: pid,
                    startedAt: TimeInterval(parent.pbi_start_tvsec)
                        + TimeInterval(parent.pbi_start_tvusec) / 1_000_000
                ),
                tty: visibleTTY,
                cwd: cwd,
                arguments: arguments
            )
        }
        let children = processIDs(type: UInt32(PROC_PPID_ONLY), value: parent.pbi_pid)
            .compactMap(processInfo)
            .filter { $0.pbi_ppid == parent.pbi_pid && $0.pbi_uid == parent.pbi_uid }
        let process = children.compactMap {
            codexProcess(in: $0, visibleTTY: visibleTTY, depth: depth + 1, visited: &visited)
        }.first
        guard process != nil, let current = processInfo(pid), sameProcess(parent, current) else {
            return nil
        }
        return process
    }

    private func resolveRollout(for process: CodexProcess) -> URL? {
        if let sessionID = process.arguments.first(where: Self.isSessionID),
           let explicit = rolloutFile(sessionID: sessionID) {
            return explicit
        }

        let files = rolloutFiles(near: process.identity.startedAt)
        let candidates = files.compactMap { url -> (URL, TimeInterval)? in
            guard let metadata = sessionMetadata(at: url),
                  let sessionStartedAt = Self.timestamp(metadata.timestamp),
                  abs(sessionStartedAt - process.identity.startedAt) <= 30,
                  metadata.payload.source == .root,
                  metadata.payload.cwd == process.cwd else { return nil }
            return (url, abs(sessionStartedAt - process.identity.startedAt))
        }.sorted { $0.1 < $1.1 }

        guard let first = candidates.first,
              candidates.count == 1 || first.1 + 1 < candidates[1].1 else { return nil }
        return first.0
    }

    private func observation(at url: URL) -> CodexSessionObservation? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let length = (try? handle.seekToEnd()) ?? 0
        let tailLength = min(length, 1_048_576)
        try? handle.seek(toOffset: length - tailLength)
        guard let data = try? handle.readToEnd(),
              let text = Self.decodableTail(data, wasTruncated: tailLength < length) else { return nil }
        return Self.parseObservation(text)
    }

    static func decodableTail(_ data: Data, wasTruncated: Bool) -> String? {
        var data = data
        if wasTruncated {
            guard let newline = data.firstIndex(of: 0x0A) else { return nil }
            data = Data(data[data.index(after: newline)...])
        }
        return String(data: data, encoding: .utf8)
    }

    static func parseObservation(_ text: String) -> CodexSessionObservation {
        var latestStatus: TerminalSessionStatus?
        var latestStatusChangedAt: TimeInterval?
        var titleParts: [String] = []
        var titleMessageCounts = ["user": 0, "assistant": 0]

        for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard let data = line.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = root["payload"] as? [String: Any] else { continue }
            if latestStatus == nil,
               root["type"] as? String == "event_msg",
               let event = payload["type"] as? String {
                switch event {
                case "task_started": latestStatus = .running
                case "task_complete": latestStatus = .finished
                case "turn_aborted": latestStatus = .interrupted
                default: break
                }
                if latestStatus != nil {
                    latestStatusChangedAt = Self.timestamp(root["timestamp"] as? String)
                }
            }
            if titleParts.count < 8,
               root["type"] as? String == "response_item",
               payload["type"] as? String == "message",
               let role = payload["role"] as? String,
               titleMessageCounts[role] != nil,
               titleMessageCounts[role, default: 0] < 4,
               let message = titleMessage(in: payload), !message.isEmpty {
                titleParts.append("[\(role)]\n\(boundedTitleMessage(message))")
                titleMessageCounts[role, default: 0] += 1
            }
        }
        return CodexSessionObservation(
            status: latestStatus,
            changedAt: latestStatusChangedAt,
            titleExcerpt: titleParts.isEmpty ? nil : titleParts.reversed().joined(separator: "\n\n")
        )
    }

    static func resolvedObservation(
        _ observation: CodexSessionObservation,
        previous: CodexSessionObservation?,
        rolloutGrew: Bool = false
    ) -> CodexSessionObservation {
        let titleExcerpt = observation.titleExcerpt ?? previous?.titleExcerpt
        if observation.status == nil, rolloutGrew {
            return CodexSessionObservation(
                status: .running,
                changedAt: Date().timeIntervalSince1970,
                processIdentity: previous?.processIdentity,
                titleExcerpt: titleExcerpt
            )
        }
        guard observation.status == nil, let previous else { return observation }
        return CodexSessionObservation(
            status: previous.status,
            changedAt: previous.changedAt,
            processIdentity: previous.processIdentity,
            titleExcerpt: titleExcerpt
        )
    }

    static func observationAfterMissingScan(
        _ observation: CodexSessionObservation,
        missedScans: Int
    ) -> CodexSessionObservation {
        guard missedScans > 2, observation.status == .running else { return observation }
        return CodexSessionObservation(
            status: .interrupted,
            changedAt: Date().timeIntervalSince1970,
            processIdentity: observation.processIdentity,
            titleExcerpt: observation.titleExcerpt
        )
    }

    private static func titleMessage(in payload: [String: Any]) -> String? {
        if let content = payload["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let content = payload["content"] as? [[String: Any]] else { return nil }
        return content.compactMap { block -> String? in
            guard ["text", "input_text", "output_text"].contains(block["type"] as? String),
                  let text = block["text"] as? String else { return nil }
            return text
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func boundedTitleMessage(_ message: String) -> String {
        guard message.count > 2_000 else { return message }
        return String(message.prefix(1_000)) + "\n[…]\n" + String(message.suffix(1_000))
    }

    private func fileLength(at url: URL) -> UInt64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return (attributes[.size] as? NSNumber)?.uint64Value
    }

    private func rolloutFiles(near timestamp: TimeInterval) -> [URL] {
        let calendar = Calendar(identifier: .gregorian)
        let date = Date(timeIntervalSince1970: timestamp)
        return (-1...1).flatMap { offset -> [URL] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { return [] }
            let components = calendar.dateComponents([.year, .month, .day], from: day)
            guard let year = components.year, let month = components.month, let day = components.day else {
                return []
            }
            let directory = sessionsDirectory
                .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", day), isDirectory: true)
            return (try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ))?.filter {
                $0.lastPathComponent.hasPrefix("rollout-") && $0.pathExtension == "jsonl"
            } ?? []
        }
    }

    private func rolloutFile(sessionID: String) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return enumerator.compactMap { $0 as? URL }.first {
            $0.lastPathComponent.contains(sessionID) && $0.pathExtension == "jsonl"
        }
    }

    private func sessionMetadata(at url: URL) -> SessionMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 65_536),
              let newline = data.firstIndex(of: 0x0A) else { return nil }
        return try? JSONDecoder().decode(SessionMetadata.self, from: Data(data[..<newline]))
    }

    private static func isCodexCLI(_ arguments: [String]) -> Bool {
        guard let executable = arguments.first,
              URL(fileURLWithPath: executable).lastPathComponent == "codex" else { return false }
        return !arguments.dropFirst().contains { ["app-server", "exec", "mcp-server"].contains($0) }
    }

    private static func isSessionID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    private static func timestamp(_ value: String?) -> TimeInterval? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return (fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value))?
            .timeIntervalSince1970
    }

    private func terminalDevice(for tty: String) -> UInt32? {
        guard TerminalStatusRegistry.normalizedTTY(tty) != nil else { return nil }
        var attributes = stat()
        guard stat(tty, &attributes) == 0,
              attributes.st_mode & S_IFMT == S_IFCHR else { return nil }
        return UInt32(bitPattern: attributes.st_rdev)
    }

    private func processIDs(type: UInt32, value: UInt32) -> [pid_t] {
        let requiredBytes = proc_listpids(type, value, nil, 0)
        guard requiredBytes > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(requiredBytes) / MemoryLayout<pid_t>.size + 16)
        let capacity = pids.count * MemoryLayout<pid_t>.size
        let bytes = pids.withUnsafeMutableBytes { buffer in
            proc_listpids(type, value, buffer.baseAddress, Int32(capacity))
        }
        guard bytes > 0, bytes < capacity else { return [] }
        return pids.prefix(Int(bytes) / MemoryLayout<pid_t>.size).filter { $0 > 0 }
    }

    private func processInfo(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size,
              info.pbi_status != SZOMB, info.pbi_status != SSTOP else { return nil }
        return info
    }

    private func sameProcess(_ first: proc_bsdinfo, _ second: proc_bsdinfo) -> Bool {
        first.pbi_pid == second.pbi_pid && first.pbi_ppid == second.pbi_ppid
            && first.pbi_start_tvsec == second.pbi_start_tvsec
            && first.pbi_start_tvusec == second.pbi_start_tvusec
    }

    private func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, Int32(size)) == size else {
            return nil
        }
        return withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
    }

    private func arguments(of pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size, size <= 1_048_576 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        let result = bytes.withUnsafeMutableBytes { buffer in
            sysctl(&mib, UInt32(mib.count), buffer.baseAddress, &size, nil, 0)
        }
        guard result == 0, size > MemoryLayout<Int32>.size else { return nil }
        let count = bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard count > 0, count <= 4096 else { return nil }
        var index = MemoryLayout<Int32>.size
        while index < size, bytes[index] != 0 { index += 1 }
        while index < size, bytes[index] == 0 { index += 1 }
        var arguments: [String] = []
        for _ in 0..<count {
            let start = index
            while index < size, bytes[index] != 0 { index += 1 }
            guard index < size,
                  let argument = String(bytes: bytes[start..<index], encoding: .utf8) else { return nil }
            arguments.append(argument)
            index += 1
        }
        return arguments
    }
}
