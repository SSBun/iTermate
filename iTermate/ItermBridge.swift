import AppKit
import Darwin
import Foundation
import Network

enum TerminalSessionStatus: String, Codable, Equatable {
    case running
    case finished

    func label(
        changedAt: TimeInterval?,
        now: Date,
        format: SessionTimeFormat
    ) -> String {
        let title = self == .running ? "Running" : "Finished"
        guard let changedAt else { return title }

        let formatter = format == .compact
            ? Self.compactElapsedFormatter
            : Self.detailedElapsedFormatter
        let elapsed = formatter.string(
            from: max(0, now.timeIntervalSince1970 - changedAt)
        ) ?? (format == .compact ? "0m" : "0s")
        return self == .running
            ? "\(title) · \(elapsed)"
            : "\(title) · \(elapsed) ago"
    }

    private static let compactElapsedFormatter = elapsedFormatter(
        allowedUnits: [.day, .hour, .minute]
    )
    private static let detailedElapsedFormatter = elapsedFormatter(
        allowedUnits: [.day, .hour, .minute, .second]
    )

    private static func elapsedFormatter(
        allowedUnits: NSCalendar.Unit
    ) -> DateComponentsFormatter {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.allowedUnits = allowedUnits
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }
}

enum SessionTimeFormat: String, CaseIterable, Identifiable {
    case compact
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact:
            "Compact (4m)"
        case .detailed:
            "Detailed (4m 32s)"
        }
    }

    var refreshInterval: TimeInterval {
        self == .compact ? 60 : 1
    }
}

struct TerminalSessionSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let path: String?
    let windowId: String?
    let tabId: String?
    let isActive: Bool
    let isMinimized: Bool?
    let status: TerminalSessionStatus?
    let exitStatus: Int?
    let statusChangedAt: TimeInterval?
}

struct TerminalTabSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let isSelected: Bool
    let sessions: [TerminalSessionSnapshot]
}

struct TerminalWindowSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let number: Int
    let isActive: Bool
    let tabs: [TerminalTabSnapshot]
}

enum SessionListStyle: String, CaseIterable, Identifiable {
    case window
    case projectPath

    var id: String { rawValue }

    var title: String {
        switch self {
        case .window:
            "Window"
        case .projectPath:
            "Project Path"
        }
    }

    var systemImage: String {
        switch self {
        case .window:
            "macwindow"
        case .projectPath:
            "folder"
        }
    }
}

struct SessionListItem: Equatable, Identifiable {
    let session: TerminalSessionSnapshot
    let tabID: String
    let tabTitle: String
    let isFocused: Bool

    var id: String { session.id }
}

struct SessionListGroup: Equatable, Identifiable {
    let id: String
    let title: String
    let sessions: [SessionListItem]

    func startsTab(at index: Int) -> Bool {
        index == 0 || sessions[index - 1].tabID != sessions[index].tabID
    }

    func sessions(inTab tabID: String) -> [SessionListItem] {
        sessions.filter { $0.tabID == tabID }
    }
}

enum SessionGrouping {
    static func groups(
        from windows: [TerminalWindowSnapshot],
        style: SessionListStyle
    ) -> [SessionListGroup] {
        switch style {
        case .window:
            return windows.compactMap { window in
                let sessions = items(in: window)
                guard !sessions.isEmpty else { return nil }
                let title = window.number > 0 ? "Window \(window.number)" : "Window"
                return SessionListGroup(
                    id: "window:\(window.id)",
                    title: title,
                    sessions: sessions
                )
            }
        case .projectPath:
            let grouped = Dictionary(
                grouping: windows.flatMap(items(in:)),
                by: { $0.session.path ?? "" }
            )
            return grouped.keys.sorted(by: pathComesBefore).map { path in
                SessionListGroup(
                    id: "path:\(path)",
                    title: path.isEmpty ? "Unknown Path" : path,
                    sessions: grouped[path] ?? []
                )
            }
        }
    }

    private static func items(in window: TerminalWindowSnapshot) -> [SessionListItem] {
        window.tabs.flatMap { tab in
            tab.sessions.map {
                SessionListItem(
                    session: $0,
                    tabID: tab.id,
                    tabTitle: tab.title,
                    isFocused: window.isActive && tab.isSelected && $0.isActive
                )
            }
        }
    }

    private static func pathComesBefore(_ first: String, _ second: String) -> Bool {
        if first.isEmpty != second.isEmpty {
            return !first.isEmpty
        }
        return first.localizedStandardCompare(second) == .orderedAscending
    }
}

enum BridgeConnectionState: Equatable {
    case connecting
    case connected
    case disconnected(String)
}

struct BridgeMessage: Decodable {
    let type: String
    let sequence: Int?
    let windows: [TerminalWindowSnapshot]?
    let requestId: String?
    let ok: Bool?
    let error: String?
}

final class ItermStore: ObservableObject {
    @Published private(set) var connectionState: BridgeConnectionState = .connecting
    @Published private(set) var windows: [TerminalWindowSnapshot] = []
    @Published private(set) var actionError: String?

    private lazy var client = ItermBridgeClient(
        onMessage: { [weak self] message in self?.apply(message) },
        onStateChange: { [weak self] state in self?.updateConnectionState(state) }
    )
    private var latestSequence = 0
    private var bridgeIsCompatible = false

    func start() {
        client.start()
    }

    func stop() {
        client.stop()
    }

    func activate(sessionID: String) {
        client.activate(sessionID: sessionID)
    }

    func close(sessionID: String) {
        client.close(sessionID: sessionID)
    }

    func apply(_ message: BridgeMessage) {
        switch message.type {
        case "hello":
            bridgeIsCompatible = true
            connectionState = .connected
        case "snapshot":
            guard
                bridgeIsCompatible,
                let sequence = message.sequence,
                sequence > latestSequence,
                let windows = message.windows
            else {
                return
            }
            latestSequence = sequence
            self.windows = windows
            actionError = nil
            connectionState = .connected
        case "actionResult":
            if message.ok == false {
                actionError = message.error ?? "iTerm action failed"
            }
        default:
            break
        }
    }

    private func updateConnectionState(_ state: BridgeConnectionState) {
        connectionState = state
        if state != .connected {
            bridgeIsCompatible = false
            latestSequence = 0
        }
    }
}

final class ItermBridgeClient {
    private let queue = DispatchQueue(label: "com.caishilin.iTermate.bridge")
    private let onMessage: (BridgeMessage) -> Void
    private let onStateChange: (BridgeConnectionState) -> Void
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private var reconnectWorkItem: DispatchWorkItem?
    private var installedBridgeURL: URL?
    private var lastLaunchDate = Date.distantPast
    private var isReady = false

    init(
        onMessage: @escaping (BridgeMessage) -> Void,
        onStateChange: @escaping (BridgeConnectionState) -> Void
    ) {
        self.onMessage = onMessage
        self.onStateChange = onStateChange
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                self.installedBridgeURL = try BridgeInstaller.install()
                BridgeInstaller.stopRunningBridge()
                self.connect()
            } catch {
                self.publish(state: .disconnected(error.localizedDescription))
            }
        }
    }

    func stop() {
        queue.sync {
            reconnectWorkItem?.cancel()
            reconnectWorkItem = nil
            isReady = false
            connection?.stateUpdateHandler = nil
            connection?.cancel()
            connection = nil
            BridgeInstaller.stopRunningBridge()
        }
    }

    func activate(sessionID: String) {
        queue.async { [weak self] in
            self?.send(
                SessionActionRequest(
                    type: "activateSession",
                    requestId: UUID().uuidString,
                    sessionId: sessionID
                )
            )
        }
    }

    func close(sessionID: String) {
        queue.async { [weak self] in
            self?.send(
                SessionActionRequest(
                    type: "closeSession",
                    requestId: UUID().uuidString,
                    sessionId: sessionID
                )
            )
        }
    }

    private func connect() {
        publish(state: .connecting)
        launchBridgeIfNeeded()
        receiveBuffer.removeAll(keepingCapacity: true)
        isReady = false

        let connection = NWConnection(
            to: .unix(path: BridgeInstaller.socketPath),
            using: .tcp
        )
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection, self.connection === connection else {
                return
            }

            switch state {
            case .ready:
                self.isReady = true
                self.reconnectWorkItem?.cancel()
                self.receive(on: connection)
            case .failed(let error):
                self.scheduleReconnect(after: error)
            case .waiting(let error):
                self.scheduleReconnect(after: error)
            case .cancelled:
                if self.connection === connection {
                    self.scheduleReconnect(after: nil)
                }
            case .setup, .preparing:
                break
            @unknown default:
                self.scheduleReconnect(after: nil)
            }
        }
        connection.start(queue: queue)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 64 * 1_024
        ) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection, self.connection === connection else {
                return
            }

            if let data, !data.isEmpty {
                self.receiveBuffer.append(data)
                self.decodeMessages()
            }

            if isComplete || error != nil {
                self.scheduleReconnect(after: error)
            } else {
                self.receive(on: connection)
            }
        }
    }

    private func decodeMessages() {
        while let newline = receiveBuffer.firstIndex(of: 0x0A) {
            let line = receiveBuffer[..<newline]
            receiveBuffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }

            do {
                let message = try JSONDecoder().decode(BridgeMessage.self, from: Data(line))
                DispatchQueue.main.async { [onMessage] in onMessage(message) }
            } catch {
                publish(state: .disconnected("Invalid Bridge response"))
            }
        }

        if receiveBuffer.count > 1_048_576 {
            receiveBuffer.removeAll()
            publish(state: .disconnected("Bridge response is too large"))
        }
    }

    private func send<T: Encodable>(_ value: T) {
        guard isReady, let connection else { return }

        do {
            var data = try JSONEncoder().encode(value)
            data.append(0x0A)
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error { self?.scheduleReconnect(after: error) }
            })
        } catch {
            publish(state: .disconnected("Could not encode Bridge request"))
        }
    }

    private func scheduleReconnect(after _: NWError?) {
        isReady = false
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        publish(
            state: .disconnected(
                "Waiting for iTerm2 Bridge. Allow Automation access or restart iTerm2."
            )
        )

        reconnectWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.connect() }
        reconnectWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    private func launchBridgeIfNeeded() {
        guard
            Date().timeIntervalSince(lastLaunchDate) >= 5,
            let installedBridgeURL,
            !NSRunningApplication.runningApplications(
                withBundleIdentifier: ItermWindow.bundleIdentifier
            ).isEmpty,
            let iTermURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: ItermWindow.bundleIdentifier
            )
        else {
            return
        }

        let launcherURL = iTermURL.appendingPathComponent("Contents/Resources/it2run")
        guard FileManager.default.isExecutableFile(atPath: launcherURL.path) else {
            return
        }

        lastLaunchDate = Date()
        let process = Process()
        process.executableURL = launcherURL
        process.arguments = [installedBridgeURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    private func publish(state: BridgeConnectionState) {
        DispatchQueue.main.async { [onStateChange] in onStateChange(state) }
    }
}

private struct SessionActionRequest: Encodable {
    let type: String
    let requestId: String
    let sessionId: String
}

enum BridgeInstaller {
    static let socketPath = NSString(
        string: "~/Library/Application Support/iTermate/bridge.sock"
    ).expandingTildeInPath

    static func install(bundle: Bundle = .main) throws -> URL {
        guard let resourceURL = bundle.url(
            forResource: "iTermateBridge",
            withExtension: "py"
        ) else {
            throw BridgeInstallerError.missingResource
        }

        let fileManager = FileManager.default
        let autoLaunchDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/iTerm2/Scripts/AutoLaunch")
        try fileManager.createDirectory(
            at: autoLaunchDirectory,
            withIntermediateDirectories: true
        )

        let destinationURL = autoLaunchDirectory
            .appendingPathComponent("iTermateBridge.py")
        let resourceData = try Data(contentsOf: resourceURL)
        let installedData = try? Data(contentsOf: destinationURL)
        if installedData != resourceData {
            try resourceData.write(to: destinationURL, options: .atomic)
        }
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: destinationURL.path
        )
        return destinationURL
    }

    static func stopRunningBridge() {
        if let pid = processIDOwningSocket() {
            terminate(pid: pid)
        }
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    private static func processIDOwningSocket() -> pid_t? {
        let lsofURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        guard FileManager.default.isExecutableFile(atPath: lsofURL.path) else {
            return nil
        }

        let output = Pipe()
        let process = Process()
        process.executableURL = lsofURL
        process.arguments = ["-t", socketPath]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard
            let text = String(data: data, encoding: .utf8),
            let pidText = text.split(whereSeparator: \.isWhitespace).first,
            let pid = Int32(pidText)
        else {
            return nil
        }
        return pid
    }

    private static func terminate(pid: pid_t) {
        guard pid > 0, pid != getpid() else { return }
        guard kill(pid, SIGTERM) == 0 || errno == ESRCH else { return }

        for _ in 0..<20 {
            if kill(pid, 0) != 0, errno == ESRCH { return }
            usleep(50_000)
        }
        _ = kill(pid, SIGKILL)
    }
}

enum BridgeInstallerError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        "iTerm Bridge resource is missing"
    }
}
