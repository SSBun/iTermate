import AppKit
import Darwin
import Foundation
import Network
import OSLog

private let bridgeSnapshotLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.caishilin.iTermate",
    category: "BridgeSnapshot"
)

enum TerminalApp: Equatable {
    case iTerm2
    case ghostty

    init?(bundleIdentifier: String) {
        switch bundleIdentifier {
        case "com.googlecode.iterm2":
            self = .iTerm2
        case "com.mitchellh.ghostty":
            self = .ghostty
        default:
            return nil
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .iTerm2:
            "com.googlecode.iterm2"
        case .ghostty:
            "com.mitchellh.ghostty"
        }
    }

    var displayName: String {
        switch self {
        case .iTerm2:
            "iTerm2"
        case .ghostty:
            "Ghostty"
        }
    }
}

enum TerminalSessionStatus: String, Codable, Equatable {
    case idle
    case running
    case finished

    func label(
        changedAt: TimeInterval?,
        now: Date,
        format: SessionTimeFormat
    ) -> String {
        guard self != .idle else { return "Idle" }
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

enum SessionActivityKind: String, Codable, Equatable {
    case agent
    case command
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
    let tty: String?
    let windowId: String?
    let tabId: String?
    let isActive: Bool
    let isMinimized: Bool?
    let status: TerminalSessionStatus?
    let activityKind: SessionActivityKind?
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

enum SectionTitleStyle: String, CaseIterable, Identifiable {
    case fullPath
    case folderName

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullPath:
            "Full path"
        case .folderName:
            "Folder name"
        }
    }

    func title(for path: String) -> String {
        guard self == .folderName else { return path }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedPath.isEmpty else { return path }
        return (trimmedPath as NSString).lastPathComponent
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
        style: SessionListStyle,
        pinnedProjectPaths: Set<String> = []
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
            return grouped.keys.sorted { first, second in
                let firstIsPinned = pinnedProjectPaths.contains(first)
                let secondIsPinned = pinnedProjectPaths.contains(second)
                if firstIsPinned != secondIsPinned {
                    return firstIsPinned
                }
                return pathComesBefore(first, second)
            }.map { path in
                SessionListGroup(
                    id: "path:\(path)",
                    title: path.isEmpty ? "Unknown Path" : path,
                    sessions: clusteredByTab(grouped[path] ?? [])
                )
            }
        }
    }

    /// Keeps same-tab sessions contiguous in first-appearance order so tab
    /// subgroups can render under a project path section.
    private static func clusteredByTab(_ items: [SessionListItem]) -> [SessionListItem] {
        var order: [String] = []
        var buckets: [String: [SessionListItem]] = [:]
        for item in items {
            if buckets[item.tabID] == nil { order.append(item.tabID) }
            buckets[item.tabID, default: []].append(item)
        }
        return order.flatMap { buckets[$0] ?? [] }
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
    @Published private(set) var terminalApp: TerminalApp?
    @Published private(set) var connectionState: BridgeConnectionState = .connecting
    @Published private(set) var windows: [TerminalWindowSnapshot] = []
    @Published private(set) var actionError: String?

    private lazy var iTermClient = ItermBridgeClient(
        onMessage: { [weak self] message in self?.apply(message) },
        onStateChange: { [weak self] state in self?.updateConnectionState(state) }
    )
    private lazy var ghosttyClient = GhosttyClient(
        onSnapshot: { [weak self] windows in self?.applyGhosttySnapshot(windows) },
        onStateChange: { [weak self] state in self?.updateGhosttyConnectionState(state) },
        onActionError: { [weak self] error in self?.updateGhosttyActionError(error) }
    )
    private lazy var terminalStatusServer = TerminalStatusServer(
        onReport: { [weak self] report in self?.applyTerminalStatus(report) },
        onReset: { [weak self] in self?.resetTerminalStatusTransport() }
    )
    private var latestSequence = 0
    private var bridgeIsCompatible = false
    private var lastLoggedSnapshotCounts: [Int]?
    private var isStarted = false
    private var iTermClientIsStarted = false
    private var lastGhosttyRefresh = Date.distantPast
    private var ghosttyRefreshIsPending = false
    private var iTermConnectionState: BridgeConnectionState = .connecting
    private var iTermWindows: [TerminalWindowSnapshot] = []
    private var ghosttyConnectionState: BridgeConnectionState = .connecting
    private var ghosttySourceWindows: [TerminalWindowSnapshot] = []
    private var ghosttyWindows: [TerminalWindowSnapshot] = []
    private var terminalStatusRegistry = TerminalStatusRegistry()
    private var statusExpiryTimer: Timer?
    private var lastActiveGhosttyTerminalID: String?

    func start() {
        guard !isStarted else { return }
        isStarted = true
        terminalStatusServer.start()
        let statusExpiryTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.expireTerminalStatuses()
        }
        RunLoop.main.add(statusExpiryTimer, forMode: .common)
        self.statusExpiryTimer = statusExpiryTimer
        if !NSRunningApplication.runningApplications(
            withBundleIdentifier: TerminalApp.iTerm2.bundleIdentifier
        ).isEmpty {
            startClient(for: .iTerm2)
        }
        if terminalApp == .ghostty {
            startClient(for: .ghostty)
        }
    }

    func stop() {
        isStarted = false
        statusExpiryTimer?.invalidate()
        statusExpiryTimer = nil
        terminalStatusServer.stop()
        if iTermClientIsStarted {
            iTermClient.stop()
            iTermClientIsStarted = false
        }
    }

    func setActiveTerminalApp(_ terminalApp: TerminalApp) {
        if self.terminalApp != terminalApp {
            self.terminalApp = terminalApp
            actionError = nil
            switch terminalApp {
            case .iTerm2:
                connectionState = iTermConnectionState
                windows = iTermWindows
            case .ghostty:
                connectionState = ghosttyConnectionState
                windows = ghosttyWindows
            }
        }
        if isStarted {
            startClient(for: terminalApp)
        }
    }

    func reconnectAfterWake() {
        if terminalStatusRegistry.clearRunning() {
            publishGhosttyWindows()
        }
        if iTermClientIsStarted {
            iTermClient.reconnectAfterWake()
        }
        if terminalApp == .ghostty {
            refreshGhostty(force: true)
        }
    }

    func activate(sessionID: String) {
        switch terminalApp ?? .iTerm2 {
        case .iTerm2:
            iTermClient.activate(sessionID: sessionID)
        case .ghostty:
            if
                let tty = ghosttySourceWindows
                    .flatMap(\.tabs)
                    .flatMap(\.sessions)
                    .first(where: { $0.id == sessionID })?.tty,
                let tty = TerminalStatusRegistry.normalizedTTY(tty),
                terminalStatusRegistry.activate(tty: tty)
            {
                publishGhosttyWindows()
            }
            ghosttyClient.activate(terminalID: sessionID)
        }
    }

    func close(sessionID: String) {
        switch terminalApp ?? .iTerm2 {
        case .iTerm2:
            iTermClient.close(sessionID: sessionID)
        case .ghostty:
            ghosttyClient.close(terminalID: sessionID)
        }
    }

    func refreshSessions() {
        switch terminalApp ?? .iTerm2 {
        case .iTerm2:
            iTermClient.resetSessionStatuses()
        case .ghostty:
            refreshGhostty(force: true)
        }
    }

    func apply(_ message: BridgeMessage) {
        switch message.type {
        case "hello":
            bridgeIsCompatible = true
            iTermConnectionState = .connected
            if terminalApp != .ghostty {
                connectionState = .connected
            }
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
            iTermWindows = windows
            let sessions = windows.flatMap(\.tabs).flatMap(\.sessions)
            let runningCount = sessions.lazy.filter { $0.status == .running }.count
            let finishedCount = sessions.lazy.filter { $0.status == .finished }.count
            let snapshotCounts = [
                windows.count,
                sessions.count,
                runningCount,
                finishedCount,
            ]
            if snapshotCounts != lastLoggedSnapshotCounts {
                bridgeSnapshotLogger.notice(
                    "Applied snapshot sequence=\(sequence, privacy: .public) windows=\(windows.count, privacy: .public) sessions=\(sessions.count, privacy: .public) running=\(runningCount, privacy: .public) finished=\(finishedCount, privacy: .public) idle=\(sessions.count - runningCount - finishedCount, privacy: .public)"
                )
                lastLoggedSnapshotCounts = snapshotCounts
            }
            iTermConnectionState = .connected
            if terminalApp != .ghostty {
                self.windows = windows
                actionError = nil
                connectionState = .connected
            }
        case "actionResult":
            if message.ok == false, terminalApp != .ghostty {
                actionError = message.error ?? "iTerm action failed"
            }
        default:
            break
        }
    }

    func updateConnectionState(_ state: BridgeConnectionState) {
        iTermConnectionState = state
        if state != .connected {
            bridgeIsCompatible = false
            latestSequence = 0
            lastLoggedSnapshotCounts = nil
            iTermWindows = []
        }
        if terminalApp != .ghostty {
            connectionState = state
            windows = iTermWindows
        }
    }

    private func startClient(for terminalApp: TerminalApp) {
        switch terminalApp {
        case .iTerm2 where !iTermClientIsStarted:
            iTermClientIsStarted = true
            iTermClient.start()
        case .ghostty:
            refreshGhostty(force: false)
        default:
            break
        }
    }

    private func refreshGhostty(force: Bool) {
        // ponytail: poll once per second until Ghostty exposes change events.
        guard
            !ghosttyRefreshIsPending,
            force || Date().timeIntervalSince(lastGhosttyRefresh) >= 1
        else {
            return
        }
        lastGhosttyRefresh = Date()
        ghosttyRefreshIsPending = true
        ghosttyClient.refresh()
    }

    private func applyGhosttySnapshot(_ windows: [TerminalWindowSnapshot]) {
        ghosttyRefreshIsPending = false
        ghosttySourceWindows = windows

        let sessions = windows.flatMap(\.tabs).flatMap(\.sessions)
        let sessionsByTTY = Dictionary(
            grouping: sessions.compactMap { session -> TerminalSessionSnapshot? in
                guard
                    let tty = session.tty,
                    TerminalStatusRegistry.normalizedTTY(tty) != nil
                else {
                    return nil
                }
                return session
            },
            by: { $0.tty ?? "" }
        )
        let terminalIDsByTTY = sessionsByTTY.compactMapValues { sessions in
            sessions.count == 1 ? sessions[0].id : nil
        }
        terminalStatusRegistry.reconcile(terminals: terminalIDsByTTY)

        let activeSession = windows.first(where: \.isActive)?
            .tabs.first(where: \.isSelected)?
            .sessions.first(where: \.isActive)
        if
            let previousID = lastActiveGhosttyTerminalID,
            activeSession?.id != previousID,
            let tty = activeSession?.tty,
            let tty = TerminalStatusRegistry.normalizedTTY(tty)
        {
            terminalStatusRegistry.activate(tty: tty)
        }
        lastActiveGhosttyTerminalID = activeSession?.id

        ghosttyConnectionState = .connected
        publishGhosttyWindows()
        guard terminalApp == .ghostty else { return }
        actionError = nil
        connectionState = .connected
    }

    private func applyTerminalStatus(_ report: TerminalStatusReport) {
        guard terminalStatusRegistry.apply(report) else { return }
        publishGhosttyWindows()
    }

    private func expireTerminalStatuses() {
        guard terminalStatusRegistry.expireStaleAgentHeartbeats() else { return }
        publishGhosttyWindows()
    }

    private func resetTerminalStatusTransport() {
        guard terminalStatusRegistry.clearRunning() else { return }
        publishGhosttyWindows()
    }

    private func publishGhosttyWindows() {
        ghosttyWindows = ghosttySourceWindows.map { window in
            TerminalWindowSnapshot(
                id: window.id,
                number: window.number,
                isActive: window.isActive,
                tabs: window.tabs.map { tab in
                    TerminalTabSnapshot(
                        id: tab.id,
                        title: tab.title,
                        isSelected: tab.isSelected,
                        sessions: tab.sessions.map(mergingTerminalStatus)
                    )
                }
            )
        }
        guard terminalApp == .ghostty else { return }
        windows = ghosttyWindows
    }

    private func mergingTerminalStatus(
        into session: TerminalSessionSnapshot
    ) -> TerminalSessionSnapshot {
        guard
            let tty = session.tty,
            let status = terminalStatusRegistry.visibleStatus(for: tty)
        else {
            return session
        }
        return TerminalSessionSnapshot(
            id: session.id,
            name: session.name,
            path: session.path,
            tty: session.tty,
            windowId: session.windowId,
            tabId: session.tabId,
            isActive: session.isActive,
            isMinimized: session.isMinimized,
            status: status.status,
            activityKind: status.activityKind,
            exitStatus: status.exitStatus,
            statusChangedAt: status.changedAt
        )
    }

    private func updateGhosttyConnectionState(_ state: BridgeConnectionState) {
        ghosttyRefreshIsPending = false
        ghosttyConnectionState = state
        if state != .connected {
            ghosttySourceWindows = []
            ghosttyWindows = []
            lastActiveGhosttyTerminalID = nil
            terminalStatusRegistry.reconcile(terminals: [:])
        }
        guard terminalApp == .ghostty else { return }
        connectionState = state
        windows = ghosttyWindows
    }

    private func updateGhosttyActionError(_ error: String?) {
        guard terminalApp == .ghostty else { return }
        actionError = error
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

    func reconnectAfterWake() {
        queue.async { [weak self] in
            self?.scheduleReconnect(after: nil)
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

    func resetSessionStatuses() {
        queue.async { [weak self] in
            guard let self else { return }
            BridgeInstaller.stopRunningBridge()
            self.lastLaunchDate = .distantPast
            self.scheduleReconnect(after: nil)
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
                withBundleIdentifier: TerminalApp.iTerm2.bundleIdentifier
            ).isEmpty,
            let iTermURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: TerminalApp.iTerm2.bundleIdentifier
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

final class GhosttyClient {
    private enum Action: String {
        case activate = "focus"
        case close
    }

    private let queue = DispatchQueue(label: "com.caishilin.iTermate.ghostty")
    private let onSnapshot: ([TerminalWindowSnapshot]) -> Void
    private let onStateChange: (BridgeConnectionState) -> Void
    private let onActionError: (String?) -> Void

    init(
        onSnapshot: @escaping ([TerminalWindowSnapshot]) -> Void,
        onStateChange: @escaping (BridgeConnectionState) -> Void,
        onActionError: @escaping (String?) -> Void
    ) {
        self.onSnapshot = onSnapshot
        self.onStateChange = onStateChange
        self.onActionError = onActionError
    }

    func refresh() {
        queue.async { [weak self] in
            self?.loadSnapshot()
        }
    }

    func activate(terminalID: String) {
        perform(.activate, terminalID: terminalID)
    }

    func close(terminalID: String) {
        perform(.close, terminalID: terminalID)
    }

    private func loadSnapshot() {
        do {
            guard Self.isGhosttyRunning else {
                throw GhosttyScriptError("Ghostty is not running")
            }
            let data = try Self.runScript(
                language: "JavaScript",
                script: Self.snapshotScript
            )
            let windows = try JSONDecoder().decode(
                [TerminalWindowSnapshot].self,
                from: data
            )
            DispatchQueue.main.async { [onSnapshot] in onSnapshot(windows) }
        } catch {
            publish(
                state: .disconnected(
                    "Ghostty connection failed: \(error.localizedDescription)"
                )
            )
        }
    }

    private func perform(_ action: Action, terminalID: String) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                guard Self.isGhosttyRunning else {
                    throw GhosttyScriptError("Ghostty is not running")
                }
                _ = try Self.runScript(
                    script: Self.actionScript,
                    arguments: [action.rawValue, terminalID]
                )
                DispatchQueue.main.async { [onActionError] in onActionError(nil) }
                loadSnapshot()
            } catch {
                DispatchQueue.main.async { [onActionError] in
                    onActionError("Ghostty action failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func publish(state: BridgeConnectionState) {
        DispatchQueue.main.async { [onStateChange] in onStateChange(state) }
    }

    private static var isGhosttyRunning: Bool {
        let workspace = NSWorkspace.shared
        let bundleIdentifier = TerminalApp.ghostty.bundleIdentifier
        return workspace.frontmostApplication?.bundleIdentifier == bundleIdentifier
            || workspace.runningApplications.contains {
                $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
            }
    }

    private static func runScript(
        language: String? = nil,
        script: String,
        arguments: [String] = []
    ) throws -> Data {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        var processArguments = language.map { ["-l", $0] } ?? []
        processArguments.append(contentsOf: ["-e", script])
        if !arguments.isEmpty {
            processArguments.append("--")
            processArguments.append(contentsOf: arguments)
        }
        process.arguments = processArguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw GhosttyScriptError(
                message.flatMap { $0.isEmpty ? nil : $0 } ?? "AppleScript failed"
            )
        }
        return output
    }

    private static let snapshotScript = #"""
    function optional(getter, fallback) {
        try {
            var value = getter();
            return value === null || value === undefined ? fallback : value;
        } catch (_) {
            return fallback;
        }
    }

    var ghostty = Application("Ghostty");
    var frontWindowID = optional(function() {
        return String(ghostty.frontWindow().id());
    }, null);
    var result = ghostty.windows().map(function(sourceWindow, windowIndex) {
        var windowID = String(sourceWindow.id());
        var selectedTabID = optional(function() {
            return String(sourceWindow.selectedTab().id());
        }, null);
        var tabs = sourceWindow.tabs().map(function(sourceTab, tabIndex) {
            var tabID = String(sourceTab.id());
            var focusedTerminalID = optional(function() {
                return String(sourceTab.focusedTerminal().id());
            }, null);
            var sessions = sourceTab.terminals().map(function(sourceTerminal) {
                var terminalID = String(sourceTerminal.id());
                var path = String(optional(function() {
                    return sourceTerminal.workingDirectory();
                }, ""));
                return {
                    id: terminalID,
                    name: String(optional(function() {
                        return sourceTerminal.name();
                    }, "Terminal")),
                    path: path || null,
                    tty: optional(function() {
                        return String(sourceTerminal.tty());
                    }, null),
                    isActive: terminalID === focusedTerminalID
                };
            });
            return {
                id: tabID,
                title: String(optional(function() {
                    return sourceTab.name();
                }, "Tab " + (tabIndex + 1))),
                isSelected: tabID === selectedTabID,
                sessions: sessions
            };
        });
        return {
            id: windowID,
            number: windowIndex + 1,
            isActive: windowID === frontWindowID,
            tabs: tabs
        };
    });

    JSON.stringify(result);
    """#

    private static let actionScript = #"""
    on run argv
        if (count of argv) is not 2 then error "Invalid Ghostty action"
        set actionName to item 1 of argv
        set terminalID to item 2 of argv

        tell application "Ghostty"
            set matchingTerminals to every terminal whose id is terminalID
            if (count of matchingTerminals) is 0 then error "Terminal not found"
            set targetTerminal to item 1 of matchingTerminals

            if actionName is "focus" then
                focus targetTerminal
            else if actionName is "close" then
                close targetTerminal
            else
                error "Unsupported Ghostty action"
            end if
        end tell
    end run
    """#
}

private struct GhosttyScriptError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
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
