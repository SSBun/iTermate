import CoreFoundation
import Darwin
import Foundation

struct CodexSessionObservation: Equatable {
    let status: TerminalSessionStatus?
    let changedAt: TimeInterval?
    let processIdentity: CodexSessionMonitor.ProcessIdentity?
    let titleExcerpt: String?
    let sessionID: String?
    let latestCompletion: SessionCompletion?
    let recentCompletions: [SessionCompletion]?
    let completionInProgressID: String?
    let isProcessAlive: Bool
    /// Requests daemon state for a thread discovered without an owned rollout descriptor.
    let requiresRuntimeStatus: Bool

    init(
        status: TerminalSessionStatus?,
        changedAt: TimeInterval?,
        processIdentity: CodexSessionMonitor.ProcessIdentity? = nil,
        titleExcerpt: String? = nil,
        sessionID: String? = nil,
        latestCompletion: SessionCompletion? = nil,
        recentCompletions: [SessionCompletion]? = nil,
        completionInProgressID: String? = nil,
        isProcessAlive: Bool = true,
        requiresRuntimeStatus: Bool = false
    ) {
        self.status = status
        self.changedAt = changedAt
        self.processIdentity = processIdentity
        self.titleExcerpt = titleExcerpt
        self.sessionID = sessionID
        self.latestCompletion = latestCompletion
        self.recentCompletions = recentCompletions
        self.completionInProgressID = completionInProgressID
        self.isProcessAlive = isProcessAlive
        self.requiresRuntimeStatus = requiresRuntimeStatus
    }
}

/// Passively observes original Codex CLI sessions without hooks or command wrappers.
// All public instance operations serialize mutable state and provider calls with lock.
final class CodexSessionMonitor: @unchecked Sendable {
    struct ProcessIdentity: Codable, Hashable {
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
            let id: String
            let source: Source
            let cli_version: String?
            let cwd: String?
        }

        enum Source: Decodable {
            case root
            case subagent

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                self = (try? container.decode(String.self)) == nil ? .subagent : .root
            }
        }

        let type: String
        let timestamp: String?
        let payload: Payload
    }

    private struct FileIdentity: Hashable {
        let device: Int32
        let inode: UInt64

        init(_ attributes: stat) {
            device = attributes.st_dev
            inode = attributes.st_ino
        }
    }

    private struct Rollout: Hashable {
        let url: URL
        let identity: FileIdentity
    }

    private struct Retry {
        let attempts: Int
        let nextScan: UInt64
    }

    private struct Match {
        let rollout: Rollout
        let sessionID: String
        let requiresRuntimeStatus = true
    }

    private struct Parser {
        var status: TerminalSessionStatus?
        var changedAt: TimeInterval?
        var sessionID: String?
        var supportsCompletionOutcomes = false
        var turnID: String?
        var latestCompletion: SessionCompletion?
        var recentCompletions: [SessionCompletion] = []
        var messages: [(role: String, text: String)] = []

        var observation: CodexSessionObservation {
            CodexSessionObservation(
                status: status,
                changedAt: changedAt,
                titleExcerpt: messages.isEmpty ? nil : messages.map { "[\($0.role)]\n\($0.text)" }
                    .joined(separator: "\n\n"),
                sessionID: sessionID,
                latestCompletion: latestCompletion,
                recentCompletions: recentCompletions,
                completionInProgressID: sessionID.flatMap { session in
                    turnID.map { "codex:\(session.lowercased()):\($0.lowercased())" }
                }
            )
        }

        mutating func consume(_ data: Data) {
            guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = root["payload"] as? [String: Any] else { return }
            if root["type"] as? String == "session_meta", let id = payload["id"] as? String {
                if let sessionID, sessionID != id { self = Parser() }
                sessionID = id
                supportsCompletionOutcomes = CodexSessionMonitor.supportsCompletionOutcomes(payload["cli_version"] as? String)
            }
            if root["type"] as? String == "event_msg", let event = payload["type"] as? String {
                let timestamp = CodexSessionMonitor.timestamp(root["timestamp"] as? String)
                switch event {
                case "task_started", "turn_started":
                    status = .running
                    changedAt = timestamp
                    turnID = payload["turn_id"] as? String
                case "task_complete", "turn_complete":
                    status = .finished
                    changedAt = timestamp
                    let failed = payload["error"] != nil && !(payload["error"] is NSNull)
                    // Older writers can finish after an unpersisted error; absence of error alone is insufficient.
                    let endedAt = payload["completed_at"] as? NSNumber
                    let hasOutcome = supportsCompletionOutcomes && endedAt.map {
                        CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite && $0.doubleValue > 0
                    } == true
                    if let sessionID, let timestamp, timestamp > 0 {
                        let completionID = payload["turn_id"] as? String ?? turnID
                            ?? root["timestamp"] as? String ?? String(timestamp)
                        let completion = SessionCompletion(
                            id: "codex:\(sessionID.lowercased()):\(completionID.lowercased())",
                            completedAt: timestamp,
                            exitStatus: failed ? 1 : hasOutcome ? 0 : nil
                        )
                        latestCompletion = completion
                        if let index = recentCompletions.firstIndex(where: { $0.id == completion.id }) {
                            recentCompletions[index] = completion
                        } else {
                            recentCompletions.append(completion)
                            if recentCompletions.count > 64 { recentCompletions.removeFirst() }
                        }
                    }
                    turnID = nil
                case "turn_aborted":
                    status = .interrupted
                    changedAt = timestamp
                    turnID = nil
                default: break
                }
            }
            if root["type"] as? String == "response_item",
               payload["type"] as? String == "message",
               let role = payload["role"] as? String, ["user", "assistant"].contains(role),
               let message = CodexSessionMonitor.titleMessage(in: payload), !message.isEmpty {
                messages.append((role, CodexSessionMonitor.boundedTitleMessage(message)))
                if messages.filter({ $0.role == role }).count > 4,
                   let first = messages.firstIndex(where: { $0.role == role }) {
                    messages.remove(at: first)
                }
            }
        }
    }

    private struct Reader {
        var offset: UInt64
        var pending = Data()
        var skipsPartialLine: Bool
        var anchor = Data()
        var modifiedAt: timespec?
        var parser: Parser
    }

    private static let maximumLineBytes = 8_388_608
    private let processProvider: ((Set<String>) -> [CodexProcess])?
    private let rolloutProvider: ((CodexProcess) -> [URL])?
    private let sessionsDirectory: URL?
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var scanNumber: UInt64 = 0
    private var matchesByProcess: [ProcessIdentity: Match] = [:]
    private var boundRolloutByProcess: [ProcessIdentity: Rollout] = [:]
    private var retries: [ProcessIdentity: Retry] = [:]
    private var readers: [Rollout: Reader] = [:]
    private var metadataByRollout: [Rollout: SessionMetadata] = [:]
    private var observationByProcess: [ProcessIdentity: CodexSessionObservation] = [:]
    private var missedScansByProcess: [ProcessIdentity: Int] = [:]
    private var ttyByProcess: [ProcessIdentity: String] = [:]
    private var terminalPrefixesByProcess: [ProcessIdentity: String] = [:]
    private var rolloutURLsForScan: [URL]?

    init(
        processProvider: ((Set<String>) -> [CodexProcess])? = nil,
        rolloutProvider: ((CodexProcess) -> [URL])? = nil,
        sessionsDirectory: URL? = nil
    ) {
        self.processProvider = processProvider
        self.rolloutProvider = rolloutProvider
        if let sessionsDirectory {
            self.sessionsDirectory = sessionsDirectory
        } else if processProvider == nil && rolloutProvider == nil {
            let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
            self.sessionsDirectory = codexHome.appendingPathComponent("sessions", isDirectory: true)
        } else {
            self.sessionsDirectory = nil
        }
    }

    func scanGeneration() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    func observations(
        in ttys: Set<String>,
        expectedGeneration: UInt64? = nil,
        terminalThreadPrefixes: [String: String] = [:]
    ) -> [String: CodexSessionObservation] {
        lock.lock()
        defer { lock.unlock() }
        guard expectedGeneration == nil || expectedGeneration == generation else { return [:] }
        scanNumber &+= 1
        let processes = processProvider?(ttys) ?? ttys.compactMap(codexProcess(on:))
        let identities = Set(processes.map(\.identity))
        var retainedIdentities = identities
        let previousObservations = observationByProcess
        let previousTTYs = ttyByProcess
        var observations: [String: CodexSessionObservation] = [:]
        let resolvedMatches = resolveMatches(for: processes, terminalThreadPrefixes: terminalThreadPrefixes)

        for process in processes {
            missedScansByProcess[process.identity] = nil
            let match = resolvedMatches[process.identity]
            matchesByProcess[process.identity] = match
            let observation = match.flatMap { self.observation(at: $0.rollout) }
                ?? CodexSessionObservation(status: nil, changedAt: nil)
            let identified = Self.identifying(
                observation, process: process.identity,
                requiresRuntimeStatus: match?.requiresRuntimeStatus ?? false
            )
            observations[process.tty] = identified
            ttyByProcess[process.identity] = process.tty
            observationByProcess[process.identity] = identified
        }

        for (identity, previous) in previousObservations where !identities.contains(identity) {
            guard let tty = previousTTYs[identity], ttys.contains(tty), observations[tty] == nil else {
                continue
            }
            if processProvider == nil, let info = processInfo(identity.pid),
               Self.identity(of: info) == identity, info.pbi_status == SSTOP {
                let suspended = Self.identifying(previous, process: identity)
                observations[tty] = suspended
                observationByProcess[identity] = suspended
                retainedIdentities.insert(identity)
                missedScansByProcess[identity] = nil
                continue
            }
            let final = matchesByProcess[identity].flatMap { observation(at: $0.rollout) } ?? previous
            let identified = Self.identifying(
                final, process: identity, isProcessAlive: false,
                requiresRuntimeStatus: previous.requiresRuntimeStatus
            )
            let missedScans = missedScansByProcess[identity, default: 0] + 1
            missedScansByProcess[identity] = missedScans
            observations[tty] = Self.observationAfterMissingScan(identified, missedScans: missedScans)
            observationByProcess[identity] = identified
            if missedScans <= 2 { retainedIdentities.insert(identity) }
        }

        retain(identities: retainedIdentities)
        return observations
    }

    func reset(ttys: Set<String>? = nil) {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        let retained = Set(ttyByProcess.compactMap { identity, tty in
            ttys.map { $0.contains(tty) } == false ? identity : nil
        })
        retain(identities: retained)
    }

    /// Rechecks the foreground CLI generation before applying an asynchronous daemon result.
    func isCurrentProcess(_ identity: ProcessIdentity, on tty: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let processes = processProvider?([tty]) ?? codexProcess(on: tty).map { [$0] } ?? []
        return processes.contains { $0.tty == tty && $0.identity == identity }
    }

    /// Reads visible messages only from the daemon's path for an explicitly bound thread.
    func titleExcerpt(at path: String, threadID: String, process: ProcessIdentity) -> String? {
        lock.lock()
        defer { lock.unlock() }
        boundRolloutByProcess[process] = nil
        guard observationByProcess[process] != nil,
              let expectedID = UUID(uuidString: threadID),
              path.hasPrefix("/"), !path.utf8.contains(0), path.utf8.count < Int(MAXPATHLEN) else { return nil }
        let url = URL(fileURLWithPath: path)
        guard url.lastPathComponent.hasPrefix("rollout-"), url.pathExtension == "jsonl" else { return nil }
        var attributes = stat()
        guard lstat(path, &attributes) == 0,
              attributes.st_mode & S_IFMT == S_IFREG, attributes.st_uid == geteuid() else { return nil }
        let rollout = Rollout(url: url, identity: FileIdentity(attributes))
        guard let metadata = sessionMetadata(at: rollout), metadata.type == "session_meta",
              metadata.payload.source == .root,
              UUID(uuidString: metadata.payload.id) == expectedID else { return nil }
        boundRolloutByProcess[process] = rollout
        guard let observation = observation(at: rollout),
              observation.sessionID.flatMap(UUID.init(uuidString:)) == expectedID else { return nil }
        return observation.titleExcerpt
    }

    private func retain(identities: Set<ProcessIdentity>) {
        matchesByProcess = matchesByProcess.filter { identities.contains($0.key) }
        boundRolloutByProcess = boundRolloutByProcess.filter { identities.contains($0.key) }
        retries = retries.filter { identities.contains($0.key) }
        observationByProcess = observationByProcess.filter { identities.contains($0.key) }
        missedScansByProcess = missedScansByProcess.filter { identities.contains($0.key) }
        ttyByProcess = ttyByProcess.filter { identities.contains($0.key) }
        terminalPrefixesByProcess = terminalPrefixesByProcess.filter { identities.contains($0.key) }
        let rollouts = Set(matchesByProcess.values.map(\.rollout)).union(boundRolloutByProcess.values)
        readers = readers.filter { rollouts.contains($0.key) }
        metadataByRollout = metadataByRollout.filter { rollouts.contains($0.key) }
    }

    private static func identifying(
        _ observation: CodexSessionObservation,
        process: ProcessIdentity,
        isProcessAlive: Bool = true,
        requiresRuntimeStatus: Bool? = nil
    ) -> CodexSessionObservation {
        CodexSessionObservation(
            status: observation.status,
            changedAt: observation.changedAt,
            processIdentity: process,
            titleExcerpt: observation.titleExcerpt,
            sessionID: observation.sessionID,
            latestCompletion: observation.latestCompletion,
            recentCompletions: observation.recentCompletions,
            completionInProgressID: observation.completionInProgressID,
            isProcessAlive: isProcessAlive,
            requiresRuntimeStatus: requiresRuntimeStatus ?? observation.requiresRuntimeStatus
        )
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

    private func resolveMatches(
        for processes: [CodexProcess],
        terminalThreadPrefixes: [String: String]
    ) -> [ProcessIdentity: Match] {
        rolloutURLsForScan = nil
        var proposed: [ProcessIdentity: Match] = [:]
        var attempted: Set<ProcessIdentity> = []
        var conflicted: Set<ProcessIdentity> = []
        for process in processes {
            let prefix = terminalThreadPrefixes[process.tty]
            let prefixChanged = prefix != terminalPrefixesByProcess[process.identity]
            terminalPrefixesByProcess[process.identity] = prefix
            guard matchesByProcess[process.identity] != nil
                || prefixChanged || scanNumber >= (retries[process.identity]?.nextScan ?? 0) else { continue }
            attempted.insert(process.identity)
            proposed[process.identity] = resolveMatch(for: process, terminalThreadPrefix: prefix)
        }
        let groups = proposed.reduce(into: [String: [ProcessIdentity]]()) { groups, entry in
            groups[entry.value.sessionID, default: []].append(entry.key)
        }
        for identities in groups.values where identities.count > 1 {
            for identity in identities {
                proposed[identity] = nil
                conflicted.insert(identity)
            }
        }
        for identity in attempted {
            if conflicted.contains(identity) {
                // A backoff must not hide an existing claim and let a weaker process take its thread.
                retries[identity] = Retry(attempts: 0, nextScan: scanNumber + 1)
            } else if proposed[identity] == nil {
                let attempts = min((retries[identity]?.attempts ?? 0) + 1, 4)
                retries[identity] = Retry(attempts: attempts, nextScan: scanNumber + UInt64(1 << (attempts - 1)))
            } else {
                retries[identity] = nil
            }
        }
        return proposed
    }

    private func resolveMatch(for process: CodexProcess, terminalThreadPrefix: String?) -> Match? {
        guard let prefix = terminalThreadPrefix, CodexAppServerClient.isValidThreadPrefix(prefix) else { return nil }
        // Files provide optional lifecycle/title evidence, never the authority for automatic identity.
        let rollouts = sessionsDirectory.map { rolloutFiles(in: $0, sessionID: prefix) }
            ?? (rolloutProvider?(process) ?? []).compactMap(rollout(at:))
        let candidates = Set(rollouts).compactMap { match(rollout: $0) }
            .filter { $0.sessionID.hasPrefix(prefix) }
        return candidates.count == 1 ? candidates.first : nil
    }

    private func match(rollout: Rollout) -> Match? {
        guard let metadata = sessionMetadata(at: rollout),
              metadata.type == "session_meta", metadata.payload.source == .root,
              let sessionID = UUID(uuidString: metadata.payload.id) else { return nil }
        metadataByRollout[rollout] = metadata
        return Match(rollout: rollout, sessionID: sessionID.uuidString.lowercased())
    }

    private func rollout(at url: URL) -> Rollout? {
        guard url.lastPathComponent.hasPrefix("rollout-"), url.pathExtension == "jsonl" else { return nil }
        var attributes = stat()
        guard lstat(url.path, &attributes) == 0,
              attributes.st_mode & S_IFMT == S_IFREG, attributes.st_uid == geteuid() else { return nil }
        return Rollout(url: url, identity: FileIdentity(attributes))
    }

    private func rolloutFiles(in directory: URL, sessionID: String) -> [Rollout] {
        if rolloutURLsForScan == nil {
            guard let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { return [] }
            rolloutURLsForScan = enumerator.compactMap { item -> URL? in
                guard let url = item as? URL,
                      url.lastPathComponent.hasPrefix("rollout-"), url.pathExtension == "jsonl" else { return nil }
                return url
            }
        }
        return (rolloutURLsForScan ?? []).compactMap { url -> Rollout? in
            guard url.lastPathComponent.lowercased().contains(sessionID.lowercased()) else { return nil }
            return rollout(at: url)
        }
    }

    private func observation(at rollout: Rollout) -> CodexSessionObservation? {
        guard let handle = try? FileHandle(forReadingFrom: rollout.url) else { return nil }
        defer { try? handle.close() }
        var attributes = stat()
        guard fstat(handle.fileDescriptor, &attributes) == 0,
              FileIdentity(attributes) == rollout.identity, attributes.st_size >= 0 else { return nil }
        let length = UInt64(attributes.st_size)
        var reader = readers[rollout]
        if let existing = reader, let metadata = metadataByRollout[rollout],
           existing.parser.sessionID != metadata.payload.id {
            reader = nil
        }
        if let existing = reader, existing.offset == length,
           existing.modifiedAt?.tv_sec == attributes.st_mtimespec.tv_sec,
           existing.modifiedAt?.tv_nsec == attributes.st_mtimespec.tv_nsec {
            return existing.parser.observation
        }
        if let existing = reader {
            if length < existing.offset {
                reader = nil
            } else if !existing.anchor.isEmpty {
                try? handle.seek(toOffset: existing.offset - UInt64(existing.anchor.count))
                if (try? handle.read(upToCount: existing.anchor.count)) != existing.anchor { reader = nil }
            }
        }
        if reader == nil {
            guard let metadata = sessionMetadata(at: rollout), metadata.payload.source == .root else {
                metadataByRollout[rollout] = nil
                return nil
            }
            metadataByRollout[rollout] = metadata
            let offset = length > 1_048_576 ? length - 1_048_576 : 0
            var skipsPartialLine = false
            if offset > 0 {
                try? handle.seek(toOffset: offset - 1)
                skipsPartialLine = (try? handle.read(upToCount: 1)) != Data([0x0A])
            }
            reader = Reader(
                offset: offset,
                skipsPartialLine: skipsPartialLine,
                parser: Parser(sessionID: metadata.payload.id,
                               supportsCompletionOutcomes: Self.supportsCompletionOutcomes(metadata.payload.cli_version))
            )
        }
        guard var current = reader else { return nil }
        do {
            try handle.seek(toOffset: current.offset)
            var budget = 8_388_608
            while current.offset < length, budget > 0 {
                let count = min(65_536, budget, Int(min(length - current.offset, UInt64(Int.max))))
                guard let data = try handle.read(upToCount: count), !data.isEmpty else { break }
                current.offset += UInt64(data.count)
                budget -= data.count
                current.pending.append(data)
                while let newline = current.pending.firstIndex(of: 0x0A) {
                    let line = Data(current.pending[..<newline])
                    current.pending.removeSubrange(...newline)
                    if current.skipsPartialLine {
                        current.skipsPartialLine = false
                    } else if line.count <= Self.maximumLineBytes {
                        current.parser.consume(line)
                    }
                }
                if current.pending.count > Self.maximumLineBytes {
                    current.pending.removeAll(keepingCapacity: false)
                    current.skipsPartialLine = true
                }
            }
            let anchorLength = Int(min(current.offset, 64))
            try handle.seek(toOffset: current.offset - UInt64(anchorLength))
            current.anchor = try handle.read(upToCount: anchorLength) ?? Data()
            current.modifiedAt = attributes.st_mtimespec
            readers[rollout] = current
            // Do not present an intermediate historical state while catching up with a large append.
            guard current.offset == length else {
                return CodexSessionObservation(status: nil, changedAt: nil, sessionID: current.parser.sessionID)
            }
            return current.parser.observation
        } catch {
            return nil
        }
    }

    private func sessionMetadata(at rollout: Rollout) -> SessionMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: rollout.url) else { return nil }
        defer { try? handle.close() }
        var attributes = stat()
        guard fstat(handle.fileDescriptor, &attributes) == 0,
              FileIdentity(attributes) == rollout.identity else { return nil }
        var line = Data()
        while line.count <= Self.maximumLineBytes {
            guard let chunk = try? handle.read(upToCount: 65_536), !chunk.isEmpty else { return nil }
            if let newline = chunk.firstIndex(of: 0x0A) {
                line.append(contentsOf: chunk[..<newline])
                guard line.count <= Self.maximumLineBytes else { return nil }
                return try? JSONDecoder().decode(SessionMetadata.self, from: line)
            }
            line.append(chunk)
        }
        return nil
    }

    static func parseObservation(_ text: String) -> CodexSessionObservation {
        var parser = Parser()
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            parser.consume(Data(line.utf8))
        }
        return parser.observation
    }

    private static func supportsCompletionOutcomes(_ version: String?) -> Bool {
        guard let parts = version?.split(separator: "."), parts.count >= 2,
              let major = Int(parts[0]), let minor = Int(parts[1]) else { return false }
        return major > 0 || (major == 0 && minor >= 163)
    }

    static func observationAfterMissingScan(
        _ observation: CodexSessionObservation,
        missedScans: Int
    ) -> CodexSessionObservation {
        guard missedScans > 2,
              observation.status == .running || observation.status == .awaitingInput else { return observation }
        return CodexSessionObservation(
            status: .interrupted,
            changedAt: Date().timeIntervalSince1970,
            processIdentity: observation.processIdentity,
            titleExcerpt: observation.titleExcerpt,
            sessionID: observation.sessionID,
            latestCompletion: observation.latestCompletion,
            recentCompletions: observation.recentCompletions,
            isProcessAlive: observation.isProcessAlive,
            requiresRuntimeStatus: observation.requiresRuntimeStatus
        )
    }

    private static func identity(of info: proc_bsdinfo) -> ProcessIdentity {
        ProcessIdentity(
            pid: pid_t(info.pbi_pid),
            startedAt: TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000
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

    private static func isCodexCLI(_ arguments: [String]) -> Bool {
        guard let executable = arguments.first,
              URL(fileURLWithPath: executable).lastPathComponent == "codex" else { return false }
        return !arguments.dropFirst().contains { ["app-server", "exec", "mcp-server"].contains($0) }
    }

    private static func timestamp(_ value: String?) -> TimeInterval? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return (fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value))?
            .timeIntervalSince1970
    }

    private func terminalDevice(for tty: String) -> UInt32? {
        guard tty.count > "/dev/tty".count, tty.count <= 128,
              tty.hasPrefix("/dev/tty"), !tty.dropFirst("/dev/".count).contains("/") else { return nil }
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
              info.pbi_status != SZOMB else { return nil }
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
