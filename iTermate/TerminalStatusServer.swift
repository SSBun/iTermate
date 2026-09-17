import Darwin
import Foundation
import Network
import OSLog

private let terminalStatusLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.caishilin.iTermate",
    category: "TerminalStatus"
)

struct TerminalStatusReport {
    enum State: String, Decodable {
        case idle
        case running
        /// An Agent is explicitly waiting for a user response.
        case awaitingInput
        case finished
        case detached
    }

    let tty: String
    let source: SessionActivityKind
    let reporterID: String
    let sequence: Int
    let state: State
    let exitStatus: Int?
    let heartbeat: Bool
}

struct VisibleTerminalStatus {
    let status: TerminalSessionStatus
    let activityKind: SessionActivityKind
    let exitStatus: Int?
    let changedAt: TimeInterval
}

struct TerminalStatusRegistry {
    private struct Channel {
        let reporterID: String
        let sequence: Int
        let status: TerminalSessionStatus?
        let exitStatus: Int?
        let changedAt: TimeInterval
        let heartbeatAt: TimeInterval?
    }

    private struct TTYState {
        var agent: Channel?
        var shell: Channel?
    }

    private static let heartbeatTimeout: TimeInterval = 8

    private var states: [String: TTYState] = [:]
    private var terminalIDsByTTY: [String: String] = [:]

    static func normalizedTTY(_ value: String) -> String? {
        guard
            value.count > "/dev/tty".count,
            value.count <= 128,
            value.hasPrefix("/dev/tty"),
            !value.dropFirst("/dev/".count).contains("/")
        else {
            return nil
        }
        return value
    }

    @discardableResult
    mutating func apply(
        _ report: TerminalStatusReport,
        now: TimeInterval = Date().timeIntervalSince1970,
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Bool {
        guard terminalIDsByTTY[report.tty] != nil else { return false }
        guard report.state != .awaitingInput || report.source == .agent else {
            return false
        }
        var ttyState = states[report.tty] ?? TTYState()
        let current = report.source == .agent ? ttyState.agent : ttyState.shell

        if let current {
            if current.reporterID == report.reporterID {
                guard report.sequence > current.sequence else { return false }
                if report.heartbeat,
                   current.status != nil,
                   current.status?.rawValue != report.state.rawValue {
                    return false
                }
            } else {
                guard !report.heartbeat else { return false }
                if report.state == .finished, current.status != nil {
                    return false
                }
            }
        }

        let status = TerminalSessionStatus(rawValue: report.state.rawValue)
        let changedAt = current?.reporterID == report.reporterID
            && current?.status == status
            ? current?.changedAt ?? now
            : now
        let channel = Channel(
            reporterID: report.reporterID,
            sequence: report.sequence,
            status: status,
            exitStatus: status == .finished ? report.exitStatus : nil,
            changedAt: changedAt,
            heartbeatAt: report.source == .agent
                && (status == .running || status == .awaitingInput)
                ? uptime
                : nil
        )

        if report.source == .agent {
            ttyState.agent = channel
        } else {
            ttyState.shell = channel
        }
        states[report.tty] = ttyState
        return true
    }

    @discardableResult
    mutating func expireStaleAgentHeartbeats(
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Bool {
        var changed = false
        for tty in Array(states.keys) {
            guard
                var ttyState = states[tty],
                let agent = ttyState.agent,
                (agent.status == .running || agent.status == .awaitingInput),
                let heartbeatAt = agent.heartbeatAt,
                uptime - heartbeatAt > Self.heartbeatTimeout
            else {
                continue
            }
            ttyState.agent = Channel(
                reporterID: agent.reporterID,
                sequence: agent.sequence,
                status: nil,
                exitStatus: nil,
                changedAt: agent.changedAt,
                heartbeatAt: nil
            )
            states[tty] = ttyState
            changed = true
        }
        return changed
    }

    @discardableResult
    mutating func clearRunning() -> Bool {
        var changed = false
        for tty in Array(states.keys) {
            guard var ttyState = states[tty] else { continue }
            if let agent = ttyState.agent,
               agent.status == .running || agent.status == .awaitingInput {
                ttyState.agent = cleared(agent)
                changed = true
            }
            if let shell = ttyState.shell, shell.status == .running {
                ttyState.shell = cleared(shell)
                changed = true
            }
            states[tty] = ttyState
        }
        return changed
    }

    mutating func reconcile(terminals: [String: String]) {
        for (tty, terminalID) in terminalIDsByTTY
        where terminals[tty] != terminalID {
            states.removeValue(forKey: tty)
        }
        terminalIDsByTTY = terminals
    }

    @discardableResult
    mutating func activate(
        tty: String,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> Bool {
        guard var ttyState = states[tty] else { return false }
        var changed = false

        if let agent = ttyState.agent, agent.status == .finished {
            ttyState.agent = Channel(
                reporterID: agent.reporterID,
                sequence: agent.sequence,
                status: .idle,
                exitStatus: nil,
                changedAt: now,
                heartbeatAt: nil
            )
            changed = true
        }
        if let shell = ttyState.shell, shell.status == .finished {
            ttyState.shell = cleared(shell)
            changed = true
        }
        states[tty] = ttyState
        return changed
    }

    func visibleStatus(for tty: String) -> VisibleTerminalStatus? {
        guard terminalIDsByTTY[tty] != nil, let ttyState = states[tty] else {
            return nil
        }
        if let agent = ttyState.agent, let status = agent.status {
            return VisibleTerminalStatus(
                status: status,
                activityKind: .agent,
                exitStatus: agent.exitStatus,
                changedAt: agent.changedAt
            )
        }
        if let shell = ttyState.shell, let status = shell.status {
            return VisibleTerminalStatus(
                status: status,
                activityKind: .command,
                exitStatus: shell.exitStatus,
                changedAt: shell.changedAt
            )
        }
        return nil
    }

    private func cleared(_ channel: Channel) -> Channel {
        Channel(
            reporterID: channel.reporterID,
            sequence: channel.sequence,
            status: nil,
            exitStatus: nil,
            changedAt: channel.changedAt,
            heartbeatAt: nil
        )
    }
}

final class TerminalStatusServer {
    static let socketPath = NSString(
        string: "~/Library/Application Support/iTermate/status.sock"
    ).expandingTildeInPath

    private static let maximumRequestSize = 16 * 1_024

    private let queue = DispatchQueue(label: "com.caishilin.iTermate.terminal-status")
    private let onReport: (TerminalStatusReport) -> Bool
    private let onReset: () -> Void
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var buffers: [ObjectIdentifier: Data] = [:]
    private var restartWorkItem: DispatchWorkItem?
    private var lockFileDescriptor: Int32 = -1
    private var isStarted = false

    init(
        onReport: @escaping (TerminalStatusReport) -> Bool,
        onReset: @escaping () -> Void
    ) {
        self.onReport = onReport
        self.onReset = onReset
    }

    func start() {
        queue.async { [weak self] in
            guard let self, !isStarted else { return }
            isStarted = true
            do {
                try prepareSupportDirectory()
                try acquireLock()
                try startListener()
            } catch {
                terminalStatusLogger.error("Could not start terminal status listener")
                stopLocked()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }

    private func prepareSupportDirectory() throws {
        let directory = URL(fileURLWithPath: Self.socketPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
    }

    private func acquireLock() throws {
        let lockPath = URL(fileURLWithPath: Self.socketPath)
            .deletingPathExtension()
            .appendingPathExtension("lock")
            .path
        let descriptor = open(lockPath, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw TerminalStatusServerError.lockUnavailable }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw TerminalStatusServerError.lockUnavailable
        }
        lockFileDescriptor = descriptor
    }

    private func startListener() throws {
        try? FileManager.default.removeItem(atPath: Self.socketPath)
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .unix(path: Self.socketPath)
        let listener = try NWListener(using: parameters)
        listener.newConnectionLimit = 64
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, self.listener === listener else { return }
            switch state {
            case .ready:
                do {
                    try FileManager.default.setAttributes(
                        [.posixPermissions: 0o600],
                        ofItemAtPath: Self.socketPath
                    )
                } catch {
                    terminalStatusLogger.error("Could not secure terminal status socket")
                    restartListener()
                }
            case .failed:
                terminalStatusLogger.error("Terminal status listener failed")
                restartListener()
            case .setup, .waiting, .cancelled:
                break
            @unknown default:
                restartListener()
            }
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    private func restartListener() {
        listener?.stateUpdateHandler = nil
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        buffers.removeAll()
        try? FileManager.default.removeItem(atPath: Self.socketPath)
        DispatchQueue.main.async { [onReset] in onReset() }

        guard isStarted else { return }
        restartWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, isStarted else { return }
            do {
                try startListener()
            } catch {
                terminalStatusLogger.error("Could not restart terminal status listener")
                restartListener()
            }
        }
        restartWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        buffers[id] = Data()
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                receive(from: connection)
            case .failed, .cancelled:
                remove(connection)
            case .setup, .preparing, .waiting:
                break
            @unknown default:
                remove(connection)
            }
        }
        connection.start(queue: queue)
    }

    private func receive(from connection: NWConnection) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: Self.maximumRequestSize + 1
        ) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            let id = ObjectIdentifier(connection)
            if let data, !data.isEmpty {
                buffers[id, default: Data()].append(data)
            }

            if
                let buffer = buffers[id],
                let newline = buffer.firstIndex(of: 0x0A)
            {
                let line = Data(buffer[..<newline])
                handle(line, on: connection)
                return
            }
            if buffers[id, default: Data()].count > Self.maximumRequestSize {
                sendResult(nil, succeeded: false, on: connection)
                return
            }
            if isComplete || error != nil {
                remove(connection)
                return
            }
            receive(from: connection)
        }
    }

    private func handle(_ data: Data, on connection: NWConnection) {
        do {
            let request = try JSONDecoder().decode(TerminalStatusRequest.self, from: data)
            let report = try request.validatedReport()
            DispatchQueue.main.async { [weak self, onReport] in
                let accepted = onReport(report)
                self?.queue.async { [weak self] in
                    self?.sendResult(request.requestId, succeeded: accepted, on: connection)
                }
            }
        } catch {
            sendResult(nil, succeeded: false, on: connection)
        }
    }

    private func sendResult(
        _ requestID: String?,
        succeeded: Bool,
        on connection: NWConnection
    ) {
        var response: [String: Any] = [
            "type": "actionResult",
            "ok": succeeded,
        ]
        if let requestID { response["requestId"] = requestID }
        guard var data = try? JSONSerialization.data(withJSONObject: response) else {
            remove(connection)
            return
        }
        data.append(0x0A)
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            self?.remove(connection)
        })
    }

    private func remove(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = nil
        buffers[id] = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
    }

    private func stopLocked() {
        isStarted = false
        restartWorkItem?.cancel()
        restartWorkItem = nil
        listener?.stateUpdateHandler = nil
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        buffers.removeAll()
        if lockFileDescriptor >= 0 {
            try? FileManager.default.removeItem(atPath: Self.socketPath)
            flock(lockFileDescriptor, LOCK_UN)
            close(lockFileDescriptor)
            lockFileDescriptor = -1
        }
    }
}

private struct TerminalStatusRequest: Decodable {
    let version: Int
    let type: String
    let requestId: String?
    let tty: String
    let source: SessionActivityKind
    let reporterId: String
    let sequence: Int
    let status: TerminalStatusReport.State
    let exitStatus: Int?
    let heartbeat: Bool?

    func validatedReport() throws -> TerminalStatusReport {
        guard
            version == 1,
            type == "setTerminalStatus",
            requestId.map({ !$0.isEmpty && $0.count <= 128 }) ?? true,
            let tty = TerminalStatusRegistry.normalizedTTY(tty),
            !reporterId.isEmpty,
            reporterId.count <= 128,
            sequence > 0
        else {
            throw TerminalStatusServerError.invalidRequest
        }

        let heartbeat = heartbeat ?? false
        guard status != .awaitingInput || source == .agent else {
            throw TerminalStatusServerError.invalidRequest
        }
        guard !heartbeat || (source == .agent
            && (status == .running || status == .awaitingInput)) else {
            throw TerminalStatusServerError.invalidRequest
        }
        if status == .finished {
            guard let exitStatus, (0...255).contains(exitStatus) else {
                throw TerminalStatusServerError.invalidRequest
            }
        } else if exitStatus != nil {
            throw TerminalStatusServerError.invalidRequest
        }

        return TerminalStatusReport(
            tty: tty,
            source: source,
            reporterID: reporterId,
            sequence: sequence,
            state: status,
            exitStatus: exitStatus,
            heartbeat: heartbeat
        )
    }
}

private enum TerminalStatusServerError: Error {
    case invalidRequest
    case lockUnavailable
}
