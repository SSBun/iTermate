import AppKit
import CryptoKit
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

    init?(bundleIdentifier: String) {
        guard bundleIdentifier == "com.googlecode.iterm2" else { return nil }
        self = .iTerm2
    }

    var bundleIdentifier: String { "com.googlecode.iterm2" }
    var displayName: String { "iTerm2" }
}

enum TerminalSessionStatus: String, Codable, Equatable {
    case idle
    case running
    /// An Agent has requested a user response instead of completing its work.
    case awaitingInput
    case interrupted
    case finished

    func label(
        changedAt: TimeInterval?,
        now: Date,
        format: SessionTimeFormat
    ) -> String {
        let title: String
        switch self {
        case .idle: return "Idle"
        case .awaitingInput: return "Waiting for your reply"
        case .running: title = "Running"
        case .interrupted: title = "Interrupted"
        case .finished: title = "Finished"
        }
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

/// The explicitly observed Agent identity, independent of its working state.
enum SessionAgentKind: String, Codable, Equatable {
    /// A Pi session identified by its integration.
    case pi
    /// A Codex session identified by its reporter.
    case codex
    /// An Agent whose integration has not supplied its identity.
    case unknown

    /// The UI environment name; unidentified Agents default to Pi without changing their recorded identity.
    var displayName: String {
        switch self {
        case .pi, .unknown: "Pi"
        case .codex: "Codex"
        }
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

/// Identifies an observed completion independently of the current display state.
struct SessionCompletion: Codable, Equatable {
    let id: String
    let completedAt: TimeInterval
    let exitStatus: Int?

    var isValid: Bool {
        !id.isEmpty && id.utf8.count <= 512 && completedAt.isFinite && completedAt > 0
            && (exitStatus.map { (0...255).contains($0) } ?? true)
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
    /// A short-lived estimate, never used for lifecycle notifications or completion counts.
    /// Confirmed Pi child activity; absent for integrations without this signal.
    var hasRunningSubagents: Bool? = nil
    /// Retained when a working-state lease expires; cleared on Agent detachment.
    var agentKind: SessionAgentKind? = nil
    /// Retained across new turns and temporary unknown states for completion delivery.
    var latestCompletion: SessionCompletion? = nil
    var recentCompletions: [SessionCompletion]? = nil
    var completionInProgressID: String? = nil
    /// Native Codex terminal-title identity; an empty value means a title without a thread yet.
    var codexThreadIDPrefix: String? = nil

    /// A legacy Agent without identity must not be presented as a Shell.
    var environmentAgentKind: SessionAgentKind? {
        agentKind ?? (activityKind == .agent ? .unknown : nil)
    }

    /// The final component of the current working directory.
    ///
    /// - Complexity: O(n), where n is the path length.
    var workingDirectoryName: String? {
        guard let path, !path.isEmpty else { return nil }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? path : name
    }
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

struct SessionListBlock: Identifiable {
    let id: String
    let tabID: String
    var sessions: [SessionListItem]
}

struct SessionListGroup: Equatable, Identifiable {
    let id: String
    let title: String
    let sessions: [SessionListItem]

    var tabIDs: [String] {
        var seen: Set<String> = []
        return sessions.map(\.tabID).filter { seen.insert($0).inserted }
    }

    func sessions(inTab tabID: String) -> [SessionListItem] {
        sessions.filter { $0.tabID == tabID }
    }

    func blocks(groupedByPath: Bool = false) -> [SessionListBlock] {
        var blocks: [SessionListBlock] = []
        var indexByID: [String: Int] = [:]
        for item in sessions {
            let id = groupedByPath
                ? "\(item.session.path ?? "")\u{0}\(item.tabID)"
                : item.tabID
            if let index = indexByID[id] {
                blocks[index].sessions.append(item)
            } else {
                indexByID[id] = blocks.count
                blocks.append(SessionListBlock(id: id, tabID: item.tabID, sessions: [item]))
            }
        }
        return blocks
    }
}

enum SessionGrouping {
    static let commandGroupID = "commands"

    static func groups(
        from windows: [TerminalWindowSnapshot],
        style: SessionListStyle,
        pinnedProjectPaths: Set<String> = [],
        separatesCommandSessions: Bool = false
    ) -> [SessionListGroup] {
        var groups: [SessionListGroup]
        switch style {
        case .window:
            groups = windows.compactMap { window in
                let sessions = items(in: window).filter {
                    !separatesCommandSessions || $0.session.environmentAgentKind != nil
                }
                guard !sessions.isEmpty else { return nil }
                let title = window.number > 0 ? "Window \(window.number)" : "Window"
                return SessionListGroup(
                    id: "window:\(window.id)",
                    title: title,
                    sessions: sessions
                )
            }
        case .projectPath:
            let items = windows.flatMap(items(in:)).filter {
                !separatesCommandSessions || $0.session.environmentAgentKind != nil
            }
            let grouped = Dictionary(
                grouping: items,
                by: { $0.session.path ?? "" }
            )
            groups = grouped.keys.sorted { first, second in
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

        guard separatesCommandSessions else { return groups }
        let commandSessions = windows.flatMap(items(in:)).filter {
            $0.session.environmentAgentKind == nil
        }
        guard !commandSessions.isEmpty else { return groups }
        groups.append(SessionListGroup(
            id: commandGroupID,
            title: "Commands",
            sessions: sortedCommandSessions(commandSessions)
        ))
        return groups
    }

    private static func sortedCommandSessions(_ items: [SessionListItem]) -> [SessionListItem] {
        items.enumerated().sorted { first, second in
            let firstPath = first.element.session.path ?? ""
            let secondPath = second.element.session.path ?? ""
            if firstPath.isEmpty != secondPath.isEmpty { return !firstPath.isEmpty }

            let firstName = first.element.session.workingDirectoryName ?? ""
            let secondName = second.element.session.workingDirectoryName ?? ""
            let nameOrder = firstName.localizedCaseInsensitiveCompare(secondName)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }

            let pathOrder = firstPath.localizedCaseInsensitiveCompare(secondPath)
            if pathOrder != .orderedSame { return pathOrder == .orderedAscending }
            return first.offset < second.offset
        }.map(\.element)
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

struct AgentCompletionStatistics: Equatable {
    let total: Int
    let month: Int
    let week: Int
    let day: Int
}

/// Bounded round-robin reservations; a saturated tick must not skip waiting candidates.
struct PiStatusRecoveryScheduler {
    private(set) var inFlight: Set<String> = []
    private var cursor = 0

    mutating func reserve(from candidates: [String]) -> [Int] {
        guard !candidates.isEmpty, inFlight.count < 4 else { return [] }
        let start = cursor % candidates.count
        var selected: [Int] = []
        for offset in 0..<candidates.count {
            guard inFlight.count < 4 else { break }
            let index = (start + offset) % candidates.count
            guard inFlight.insert(candidates[index]).inserted else { continue }
            selected.append(index)
            cursor = (index + 1) % candidates.count
        }
        return selected
    }

    mutating func complete(_ key: String) {
        inFlight.remove(key)
    }
}

final class ItermStore: ObservableObject {
    /// Identifies one viewed completion without changing its rollout observation.
    struct CodexCompletionAcknowledgement: Equatable {
        let sessionID: String
        let processIdentity: CodexSessionMonitor.ProcessIdentity
        let changedAt: TimeInterval
        let codexSessionID: String?
        let completionID: String?

        init?(observation: CodexSessionObservation, sessionID: String) {
            guard observation.status == .finished,
                  let processIdentity = observation.processIdentity,
                  let changedAt = observation.changedAt else { return nil }
            self.sessionID = sessionID
            self.processIdentity = processIdentity
            self.changedAt = changedAt
            codexSessionID = observation.sessionID
            completionID = observation.latestCompletion?.id
        }
    }

    struct CodexThreadBinding: Equatable {
        let terminalSessionID: String
        let processIdentity: CodexSessionMonitor.ProcessIdentity
        let threadID: String
        var isManual = true
    }

    struct CodexRuntimeOverlay {
        let observation: CodexSessionObservation
        let sampledFrom: CodexSessionObservation
    }

    /// Pins a manual display override to one observed lifecycle and terminal identity.
    private struct SessionStatusIdentity: Equatable {
        let tty: String?
        let activityKind: SessionActivityKind?
        let agentKind: SessionAgentKind?
        let status: TerminalSessionStatus?
        let changedAt: TimeInterval?
        let exitStatus: Int?
        let hasRunningSubagents: Bool?
        let latestCompletion: SessionCompletion?
        let completionInProgressID: String?
        let codexThreadIDPrefix: String?
        let codexProcess: CodexSessionMonitor.ProcessIdentity?
        let codexSessionID: String?
    }

    private struct CodexTitleState {
        let terminalSessionID: String
        let processIdentity: CodexSessionMonitor.ProcessIdentity
        let codexSessionID: String?
        var attemptedExcerpt: String
        var attempts: Int
        var completedExcerpt: String?
        var title: String?
        var requestID: UUID?
    }

    private struct CachedCodexTitle: Codable {
        let terminalSessionID: String
        let pid: Int32
        let startedAt: TimeInterval
        let codexSessionID: String?
        let excerptDigest: String
        let title: String
    }

    private static let codexTitleCacheKey = "codexSessionTitles"
    private let titleDefaults: UserDefaults
    private let fillsMissingTitles: () -> Bool

    let piArchives = PiSessionArchives()
    @Published private(set) var terminalApp: TerminalApp?
    @Published private(set) var connectionState: BridgeConnectionState = .connecting
    @Published private(set) var windows: [TerminalWindowSnapshot] = []
    /// Observed lifecycle state, unaffected by manual display acknowledgements.
    @Published private(set) var lifecycleWindows: [TerminalWindowSnapshot] = []
    @Published private(set) var actionError: String?
    @Published private(set) var statusMenuConnectionState: BridgeConnectionState = .connecting
    @Published private(set) var runningAgentSessionCount: Int?
    @Published private(set) var agentCompletionStatistics: AgentCompletionStatistics
    @Published private var venomDebugMonitoringSessions: [String: TerminalSessionSnapshot] = [:]

    var completedAgentTurnsToday: Int { agentCompletionStatistics.day }

    private static let completionCountsByDayKey = "agentCompletionCountsByDay"
    private static let legacyCompletionDayKey = "agentCompletionDayStart"
    private static let legacyCompletionCountKey = "agentCompletionCount"

    private lazy var iTermClient = ItermBridgeClient(
        onMessage: { [weak self] message in self?.apply(message) },
        onStateChange: { [weak self] state in self?.updateConnectionState(state) }
    )
    private var latestSequence = 0
    private var bridgeIsCompatible = false
    private var lastLoggedSnapshotCounts: [Int]?
    private var isStarted = false
    private var iTermClientIsStarted = false
    private var iTermConnectionState: BridgeConnectionState = .connecting
    private var iTermWindows: [TerminalWindowSnapshot] = []
    private var manualIdleStatuses: [String: SessionStatusIdentity] = [:]
    private var statusExpiryTimer: Timer?
    private let codexSessionMonitor = CodexSessionMonitor()
    private let codexMonitorQueue = DispatchQueue(label: "com.caishilin.iTermate.codex-monitor", qos: .utility)
    private var codexThreadBindings: [String: CodexThreadBinding] = [:]
    private var codexRuntimeObservations: [String: CodexRuntimeOverlay] = [:]
    private var codexNativeObservations: [String: CodexSessionObservation] = [:]
    private var codexNativeThreadPrefixes: [String: String] = [:]
    private var codexRuntimeTasks: [String: Task<Void, Never>] = [:]
    private var codexFinalReadTTYs: Set<String> = []
    private var codexMonitorScanID: UUID?
    private var codexObservations: [String: CodexSessionObservation] = [:]
    private var codexObservationSessionIdentityByTTY: [String: String] = [:]
    private var codexAcknowledgedCompletions: [String: CodexCompletionAcknowledgement] = [:]
    private var codexFocusedSessionIDs: [String: String] = [:]
    private var terminalDeactivationObserver: NSObjectProtocol?
    private var codexTitleStates: [String: CodexTitleState] = [:]
    private var codexTitleTasks: [String: (requestID: UUID, task: Task<Void, Never>)] = [:]
    private let generateCodexTitle: (@MainActor (String) async throws -> String)?
    private var venomMonitorScanID: UUID?
    private var piRecoveryGeneration = 0
    private var piRecoveryScheduler = PiStatusRecoveryScheduler()
    private var iTermAgentCompletionTracker = SessionCompletionTracker()
    private var iTermSnapshotIsReady = false
    private let completionDefaults: UserDefaults
    private var completionCountsByDay: [String: Int]

    init(
        titleDefaults: UserDefaults = .standard,
        fillsMissingTitles: @escaping () -> Bool = { LocalLLMService.fillsMissingTitles() },
        generateCodexTitle: (@MainActor (String) async throws -> String)? = nil
    ) {
        let defaults = UserDefaults.standard
        let counts = Self.loadCompletionCounts(from: defaults)
        self.generateCodexTitle = generateCodexTitle
        self.titleDefaults = titleDefaults
        self.fillsMissingTitles = fillsMissingTitles
        completionDefaults = defaults
        completionCountsByDay = counts
        agentCompletionStatistics = Self.statistics(from: counts)
        updateStatusMenuSummary()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        terminalDeactivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication, let bundleID = application.bundleIdentifier else { return }
            self?.codexFocusedSessionIDs[bundleID] = nil
        }
        piArchives.start()
        let statusExpiryTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshCodexMonitoring()
            self?.refreshVenomDebugMonitoring()
            self?.recoverUnknownPiStatuses()
        }
        RunLoop.main.add(statusExpiryTimer, forMode: .common)
        self.statusExpiryTimer = statusExpiryTimer
        if Self.isRunning(.iTerm2) {
            startClient(for: .iTerm2)
        }
    }

    func stop() {
        isStarted = false
        statusExpiryTimer?.invalidate()
        statusExpiryTimer = nil
        codexMonitorScanID = nil
        codexObservations = [:]
        codexObservationSessionIdentityByTTY = [:]
        codexAcknowledgedCompletions = [:]
        codexFocusedSessionIDs = [:]
        manualIdleStatuses = [:]
        if let terminalDeactivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminalDeactivationObserver)
            self.terminalDeactivationObserver = nil
        }
        codexTitleTasks.values.forEach { $0.task.cancel() }
        codexTitleTasks = [:]
        codexTitleStates = [:]
        codexRuntimeTasks.values.forEach { $0.cancel() }
        codexRuntimeTasks = [:]
        codexFinalReadTTYs = []
        codexRuntimeObservations = [:]
        codexNativeObservations = [:]
        codexNativeThreadPrefixes = [:]
        codexThreadBindings = [:]
        codexMonitorQueue.async { [codexSessionMonitor] in codexSessionMonitor.reset() }
        venomMonitorScanID = nil
        venomDebugMonitoringSessions = [:]
        invalidatePiStatusRecovery()
        piArchives.stop()
        if iTermClientIsStarted {
            iTermClient.stop()
            iTermClientIsStarted = false
        }
    }

    func setActiveTerminalApp(_ terminalApp: TerminalApp) {
        if self.terminalApp != terminalApp {
            self.terminalApp = terminalApp
            venomMonitorScanID = nil
            venomDebugMonitoringSessions = [:]
            actionError = nil
            connectionState = iTermConnectionState
            publishWindows(mergingCodexObservations(into: iTermWindows))
        }
        if isStarted {
            startClient(for: terminalApp)
        }
    }

    func reconnectAfterWake() {
        invalidatePiStatusRecovery()
        venomMonitorScanID = nil
        venomDebugMonitoringSessions = [:]
        if iTermClientIsStarted {
            iTermClient.reconnectAfterWake()
        }
    }

    func refreshCompletionStatistics() {
        updateCompletionStatistics()
    }

    func refreshStatusMenu() {
        updateCompletionStatistics()
        if Self.isRunning(.iTerm2) {
            startClient(for: .iTerm2)
        }
        updateStatusMenuSummary()
    }

    func isRefreshingCodexTitle(_ session: TerminalSessionSnapshot) -> Bool {
        guard let tty = session.tty,
              codexObservationSessionIdentityByTTY[tty] == session.id else { return false }
        return codexTitleTasks[tty] != nil
    }

    @MainActor
    func refreshCodexTitle(_ session: TerminalSessionSnapshot) {
        actionError = nil
        guard let tty = session.tty,
              codexObservationSessionIdentityByTTY[tty] == session.id,
              let observation = codexObservations[tty],
              let processIdentity = observation.processIdentity,
              observation.sessionID != nil, let excerpt = observation.titleExcerpt,
              generateCodexTitle != nil else {
            CodexTitleDiagnostics.shared.recordFailure(
                SessionTitleGenerationError(.sessionUnavailable), manual: true
            )
            actionError = "This Codex session has no conversation available for a title yet."
            return
        }
        codexTitleTasks.removeValue(forKey: tty)?.task.cancel()
        let requestID = UUID()
        let previousTitle = codexTitleStates[tty].flatMap { state in
            state.terminalSessionID == session.id && state.processIdentity == processIdentity
                && state.codexSessionID == observation.sessionID
                ? state.title : nil
        }
        codexTitleStates[tty] = CodexTitleState(
            terminalSessionID: session.id,
            processIdentity: processIdentity,
            codexSessionID: observation.sessionID,
            attemptedExcerpt: excerpt,
            attempts: 1,
            completedExcerpt: nil,
            title: previousTitle,
            requestID: requestID
        )
        startCodexTitleRequest(
            tty: tty,
            terminalSessionID: session.id,
            processIdentity: processIdentity,
            codexSessionID: observation.sessionID,
            excerpt: excerpt,
            requestID: requestID,
            requiresFinishedStatus: false,
            reportsFailure: true,
            attempt: 1
        )
    }

#if DEBUG
    func prepareCodexTitleRefreshForTesting(
        _ session: TerminalSessionSnapshot,
        observation: CodexSessionObservation
    ) {
        guard let tty = session.tty, observation.processIdentity != nil else {
            preconditionFailure("Codex title test fixture requires a TTY and process identity")
        }
        isStarted = true
        codexObservations[tty] = observation
        codexObservationSessionIdentityByTTY[tty] = session.id
        codexNativeThreadPrefixes[tty] = session.codexThreadIDPrefix
        replaceCodexTerminalSnapshotForTesting(session)
    }

    func replaceCodexTerminalSnapshotForTesting(_ session: TerminalSessionSnapshot) {
        iTermWindows = [TerminalWindowSnapshot(
            id: "test-window", number: 1, isActive: true,
            tabs: [TerminalTabSnapshot(id: "test-tab", title: "Codex", isSelected: true, sessions: [session])]
        )]
    }

    func scheduleCodexTitlesForTesting() {
        scheduleCodexTitles(observations: codexObservations,
                            terminalSessionIDs: codexObservationSessionIdentityByTTY)
    }

    func codexTitleForTesting(_ session: TerminalSessionSnapshot) -> String? {
        guard let tty = session.tty else { return nil }
        return codexTitleStates[tty]?.title
    }
#endif

    func openFavoriteProject(
        atPath path: String,
        completion: @escaping (String?) -> Void
    ) {
        let finish: (String?) -> Void = { [weak self] error in
            self?.actionError = error
            completion(error)
        }
        actionError = nil
        if Self.isRunning(.iTerm2) {
            startClient(for: .iTerm2)
            iTermClient.openProject(atPath: path, completion: finish)
            return
        }

        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            finish("Favorite project folder no longer exists")
            return
        }
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: TerminalApp.iTerm2.bundleIdentifier
        ) else {
            finish("iTerm2 is not installed")
            return
        }

        startClient(for: .iTerm2)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: configuration
        ) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    finish("Could not open iTerm2: \(error.localizedDescription)")
                } else {
                    self.iTermClient.openProject(atPath: path, completion: finish)
                }
            }
        }
    }

    /// Routes the global shortcut to iTerm2 regardless of the foreground terminal.
    func activateNextFinishedSession() {
        guard Self.isRunning(.iTerm2) else { return }
        startClient(for: .iTerm2)
        // Native Codex state exists only in the App overlay, not in Bridge lifecycle storage.
        let codexStatuses = Dictionary(uniqueKeysWithValues: mergingCodexObservations(into: iTermWindows)
            .flatMap(\.tabs)
            .flatMap(\.sessions)
            .filter { $0.agentKind == .codex && $0.activityKind == .agent }
            .map { ($0.id, $0.status) })
        iTermClient.activateNextFinishedSession(codexStatuses: codexStatuses) { [weak self] error in
            self?.actionError = error
        }
    }

    func activate(sessionID: String) {
        let session = windows.flatMap(\.tabs).flatMap(\.sessions).first { $0.id == sessionID }
        let completion = session.flatMap(codexCompletionAcknowledgement)
        iTermClient.activate(sessionID: sessionID) { [weak self] error in
            guard error == nil, let self,
                  acknowledgeCodexCompletion(completion, tty: session?.tty) else { return }
            publishItermWindows()
        }
    }

    /// Marks the current observation idle without changing or stopping the underlying work.
    func markSessionIdle(sessionID: String) {
        guard let session = mergingCodexObservations(into: iTermWindows)
            .flatMap(\.tabs).flatMap(\.sessions).first(where: { $0.id == sessionID }),
              session.status != .idle else { return }
        manualIdleStatuses[sessionID] = statusIdentity(for: session)
        publishItermWindows()
    }

    func archivePiSession(_ session: TerminalSessionSnapshot, in terminal: TerminalApp) {
        Task { @MainActor in
            do {
                let shellPID = try await piArchives.archive(session, terminal: terminal)
                guard Self.isRunning(terminal) else { return }
                let completion: (String?) -> Void = { [weak self] failure in
                    if let failure { self?.piArchives.error = "Archive saved, but terminal close failed: \(failure)" }
                }
                iTermClient.closeArchivedSession(sessionID: session.id, shellPID: shellPID, completion: completion)
            } catch {
                piArchives.error = error.localizedDescription
            }
        }
    }

    func resumePiArchive(_ record: PiArchiveRecord) {
        Task { @MainActor in
            guard !piArchives.isBusy else { return }
            do {
                let location = try await piArchives.prepareResume(record)
                let terminal = record.terminalApp
                let launch: @MainActor () -> Void = { [weak self] in
                    guard let self else { return }
                    let finish: (String?) -> Void = { [weak self] error in
                        guard let self else { return }
                        if let error { self.piArchives.finishResume(error: error); return }
                        Task { @MainActor in
                            do {
                                try await self.piArchives.waitForResume(location)
                                self.piArchives.finishResume(error: nil)
                            } catch { self.piArchives.finishResume(error: error.localizedDescription) }
                        }
                    }
                    self.startClient(for: .iTerm2)
                    self.iTermClient.resumePiSession(location, completion: finish)
                }
                if Self.isRunning(terminal) { launch(); return }
                guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleIdentifier) else {
                    piArchives.finishResume(error: "\(terminal.displayName) is not installed. The archive is unchanged.")
                    return
                }
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                let didOpen: @MainActor @Sendable (Error?) -> Void = { [weak self] error in
                    if let error { self?.piArchives.finishResume(error: error.localizedDescription) }
                    else { launch() }
                }
                NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
                    Task { @MainActor in didOpen(error) }
                }
            } catch {
                piArchives.finishResume(error: error.localizedDescription)
            }
        }
    }

    func close(sessionID: String) {
        iTermClient.close(sessionID: sessionID)
    }

    func refreshSessions() {
        iTermClient.resetSessionStatuses()
    }

    func apply(_ message: BridgeMessage) {
        switch message.type {
        case "hello":
            bridgeIsCompatible = true
            iTermConnectionState = .connected
            updateStatusMenuSummary()
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
            iTermWindows = windows
            reconcileCodexObservationSessions()
            acknowledgeFocusedCodexCompletion(in: windows, terminal: .iTerm2)
            iTermSnapshotIsReady = true
            let visibleWindows = mergingCodexObservations(into: windows)
            let completions = iTermAgentCompletionTracker.completions(
                in: visibleWindows,
                activityKind: .agent
            )
            recordSuccessfulAgentCompletions(completions)
            updateStatusMenuSummary()
            let sessions = visibleWindows.flatMap(\.tabs).flatMap(\.sessions)
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
            publishWindows(visibleWindows)
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

    func updateConnectionState(_ state: BridgeConnectionState) {
        iTermConnectionState = state
        if state != .connected {
            invalidatePiStatusRecovery()
            bridgeIsCompatible = false
            latestSequence = 0
            lastLoggedSnapshotCounts = nil
            iTermWindows = []
            reconcileCodexObservationSessions()
            iTermSnapshotIsReady = false
            _ = iTermAgentCompletionTracker.completions(
                in: [],
                activityKind: .agent
            )
        }
        updateStatusMenuSummary()
        connectionState = state
        publishWindows(mergingCodexObservations(into: iTermWindows))
    }

    private func recordSuccessfulAgentCompletions(
        _ completions: [TerminalSessionSnapshot]
    ) {
        let successful = completions.filter { $0.exitStatus == 0 }
        guard !successful.isEmpty else { return }
        for session in successful {
            let date = session.latestCompletion.map { Date(timeIntervalSince1970: $0.completedAt) } ?? Date()
            completionCountsByDay[Self.dayKey(for: date), default: 0] += 1
        }
        completionDefaults.set(
            completionCountsByDay,
            forKey: Self.completionCountsByDayKey
        )
        updateCompletionStatistics()
    }

    private func updateCompletionStatistics() {
        let statistics = Self.statistics(from: completionCountsByDay)
        if agentCompletionStatistics != statistics {
            agentCompletionStatistics = statistics
        }
    }

    private func updateStatusMenuSummary() {
        updateCompletionStatistics()
        let iTermIsRunning = Self.isRunning(.iTerm2)
        var sourceStates: [BridgeConnectionState] = []
        if iTermIsRunning {
            sourceStates.append(
                statusMenuSourceState(
                    connectionState: iTermConnectionState,
                    hasSnapshot: iTermSnapshotIsReady
                )
            )
        }

        let disconnectedMessage = sourceStates.compactMap { state -> String? in
            guard case .disconnected(let message) = state else { return nil }
            return message
        }.first
        let newState: BridgeConnectionState
        if let disconnectedMessage {
            newState = .disconnected(disconnectedMessage)
        } else if sourceStates.contains(.connecting) {
            newState = .connecting
        } else {
            newState = .connected
        }
        if statusMenuConnectionState != newState {
            statusMenuConnectionState = newState
        }

        let newCount: Int?
        if newState == .connected {
            newCount = (iTermIsRunning
                ? Self.runningAgentCount(in: mergingCodexObservations(into: iTermWindows))
                : 0)
        } else {
            newCount = nil
        }
        if runningAgentSessionCount != newCount {
            runningAgentSessionCount = newCount
        }
    }

    private func statusMenuSourceState(
        connectionState: BridgeConnectionState,
        hasSnapshot: Bool
    ) -> BridgeConnectionState {
        guard !hasSnapshot else { return connectionState }
        if case .disconnected = connectionState {
            return connectionState
        }
        return .connecting
    }

    static func runningAgentCount(in windows: [TerminalWindowSnapshot]) -> Int {
        windows
            .flatMap(\.tabs)
            .flatMap(\.sessions)
            .lazy
            .filter { $0.activityKind == .agent && $0.status == .running }
            .count
    }

    private static func isRunning(_ terminalApp: TerminalApp) -> Bool {
        NSRunningApplication.runningApplications(
            withBundleIdentifier: terminalApp.bundleIdentifier
        ).contains { !$0.isTerminated }
    }

    private static func dayKey(
        for date: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func date(
        forDayKey key: String,
        calendar: Calendar
    ) -> Date? {
        let values = key.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }
        return calendar.date(
            from: DateComponents(
                year: values[0],
                month: values[1],
                day: values[2],
                hour: 12
            )
        )
    }

    private static func statistics(
        from counts: [String: Int],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> AgentCompletionStatistics {
        let todayKey = dayKey(for: now, calendar: calendar)
        let month = calendar.dateInterval(of: .month, for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        var totalCount = 0
        var monthCount = 0
        var weekCount = 0
        var dayCount = 0

        for (key, storedCount) in counts {
            let count = max(0, storedCount)
            totalCount += count
            if key == todayKey {
                dayCount += count
            }
            guard let date = date(forDayKey: key, calendar: calendar) else {
                continue
            }
            if month?.contains(date) == true {
                monthCount += count
            }
            if week?.contains(date) == true {
                weekCount += count
            }
        }

        return AgentCompletionStatistics(
            total: totalCount,
            month: monthCount,
            week: weekCount,
            day: dayCount
        )
    }

    private static func loadCompletionCounts(
        from defaults: UserDefaults
    ) -> [String: Int] {
        if let storedCounts = defaults.dictionary(forKey: completionCountsByDayKey) {
            return storedCounts.reduce(into: [:]) { counts, entry in
                if let count = entry.value as? NSNumber, count.intValue > 0 {
                    counts[entry.key] = count.intValue
                }
            }
        }

        var counts: [String: Int] = [:]
        let legacyCount = max(0, defaults.integer(forKey: legacyCompletionCountKey))
        let legacyDay = defaults.double(forKey: legacyCompletionDayKey)
        if legacyCount > 0, legacyDay > 0 {
            counts[dayKey(for: Date(timeIntervalSince1970: legacyDay))] = legacyCount
        }
        defaults.set(counts, forKey: completionCountsByDayKey)
        defaults.removeObject(forKey: legacyCompletionDayKey)
        defaults.removeObject(forKey: legacyCompletionCountKey)
        return counts
    }

    private func startClient(for terminalApp: TerminalApp) {
        guard !iTermClientIsStarted else { return }
        iTermClientIsStarted = true
        iTermClient.start()
    }

    private func invalidatePiStatusRecovery() {
        piRecoveryGeneration += 1
        // Keep old requests counted until they finish, so reconnects cannot exceed the limit.
    }

    private func recoverUnknownPiStatuses() {
        guard isStarted else { return }
        let sources: [(TerminalApp, [TerminalWindowSnapshot])] = [
            (.iTerm2, iTermConnectionState == .connected ? iTermWindows : []),
        ]
        let candidates = sources.flatMap { terminal, windows in
            windows.flatMap(\.tabs).flatMap(\.sessions).compactMap { session -> (TerminalApp, TerminalSessionSnapshot)? in
                guard (session.activityKind != .agent || session.status == nil),
                      piArchives.canQueryStatus(session, terminal: terminal) else { return nil }
                return (terminal, session)
            }
        }
        let keys = candidates.map { "\($0.0.displayName):\($0.1.id)" }
        for index in piRecoveryScheduler.reserve(from: keys) {
            let (terminal, session) = candidates[index]
            let key = keys[index]
            let generation = piRecoveryGeneration
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { piRecoveryScheduler.complete(key) }
                guard isStarted, generation == piRecoveryGeneration else { return }
                guard let observation = try? await piArchives.queryStatus(session, terminal: terminal),
                      isStarted, generation == piRecoveryGeneration else { return }
                let currentWindows = iTermWindows
                guard let current = currentWindows.flatMap(\.tabs).flatMap(\.sessions).first(where: { $0.id == session.id }),
                      current.tty == session.tty, current.statusChangedAt == session.statusChangedAt,
                      current.status == session.status, current.activityKind == session.activityKind,
                      current.activityKind != .agent || current.status == nil else { return }
                iTermClient.recoverSessionStatus(sessionID: session.id, observation: observation)
            }
        }
    }

    /// A presentation-only refinement; Agent lifecycle and completion tracking remain authoritative.
    func isVenomDebugMonitoring(_ session: TerminalSessionSnapshot) -> Bool {
        guard session.status == .running, session.activityKind == .command,
              let observed = venomDebugMonitoringSessions[session.id] else { return false }
        return observed.tty == session.tty && observed.statusChangedAt == session.statusChangedAt
            && windows.flatMap(\.tabs).flatMap(\.sessions).filter { $0.tty == session.tty }.count == 1
    }

    private func refreshVenomDebugMonitoring() {
        guard isStarted, venomMonitorScanID == nil else { return }
        let sessions = windows.flatMap(\.tabs).flatMap(\.sessions)
        let ttyCounts = Dictionary(grouping: sessions.compactMap(\.tty), by: { $0 }).mapValues(\.count)
        let candidates = sessions.filter {
            $0.status == .running && $0.activityKind == .command
                && $0.tty.map { ttyCounts[$0] == 1 } == true
        }
        guard !candidates.isEmpty else {
            if !venomDebugMonitoringSessions.isEmpty { venomDebugMonitoringSessions = [:] }
            return
        }
        let scanID = UUID()
        venomMonitorScanID = scanID
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let monitoringTTYs = VenomDebugMonitor.monitoringTTYs(in: Set(candidates.compactMap(\.tty)))
            DispatchQueue.main.async { [weak self] in
                guard let self, isStarted, venomMonitorScanID == scanID else { return }
                venomMonitorScanID = nil
                let observed = candidates.filter { $0.tty.map(monitoringTTYs.contains) == true }
                let updated = Dictionary(uniqueKeysWithValues: observed.map { ($0.id, $0) })
                if venomDebugMonitoringSessions != updated {
                    venomDebugMonitoringSessions = updated
                }
            }
        }
    }

    private func mergingCodexObservations(
        into windows: [TerminalWindowSnapshot]
    ) -> [TerminalWindowSnapshot] {
        windows.map { window in
            TerminalWindowSnapshot(
                id: window.id,
                number: window.number,
                isActive: window.isActive,
                tabs: window.tabs.map { tab in
                    TerminalTabSnapshot(
                        id: tab.id,
                        title: tab.title,
                        isSelected: tab.isSelected,
                        sessions: tab.sessions.map(mergingCodexObservation)
                    )
                }
            )
        }
    }

    private func mergingCodexObservation(
        into session: TerminalSessionSnapshot
    ) -> TerminalSessionSnapshot {
        guard let tty = session.tty,
              codexObservationSessionIdentityByTTY[tty] == session.id,
              codexNativeThreadPrefixes[tty] == session.codexThreadIDPrefix,
              let observation = codexObservations[tty] else {
            return session
        }
        return Self.mergingCodexObservation(
            observation,
            acceptedSessionID: codexObservationSessionIdentityByTTY[tty],
            acknowledgement: codexAcknowledgedCompletions[tty],
            title: codexTitleStates[tty].flatMap { state in
                state.terminalSessionID == session.id
                    && state.processIdentity == observation.processIdentity
                    && state.codexSessionID == observation.sessionID ? state.title : nil
            },
            into: session
        )
    }

    static func mergingCodexObservation(
        _ observation: CodexSessionObservation,
        acceptedSessionID: String? = nil,
        acknowledgement: CodexCompletionAcknowledgement? = nil,
        title: String? = nil,
        into session: TerminalSessionSnapshot
    ) -> TerminalSessionSnapshot {
        guard acceptedSessionID == nil || acceptedSessionID == session.id else { return session }
        let wasViewed = acknowledgement != nil && acknowledgement == CodexCompletionAcknowledgement(
            observation: observation, sessionID: session.id
        )
        let status: TerminalSessionStatus? = wasViewed ? .idle : observation.status
        return TerminalSessionSnapshot(
            id: session.id,
            name: title ?? session.name,
            path: session.path,
            tty: session.tty,
            windowId: session.windowId,
            tabId: session.tabId,
            isActive: session.isActive,
            isMinimized: session.isMinimized,
            status: status,
            activityKind: .agent,
            exitStatus: status == .finished && observation.latestCompletion?.completedAt == observation.changedAt
                ? observation.latestCompletion?.exitStatus : nil,
            statusChangedAt: observation.changedAt,
            hasRunningSubagents: false,
            agentKind: .codex,
            latestCompletion: observation.latestCompletion,
            recentCompletions: observation.recentCompletions,
            completionInProgressID: observation.completionInProgressID,
            codexThreadIDPrefix: session.codexThreadIDPrefix
        )
    }

    /// Returns only the globally focused pane of the foreground terminal.
    static func focusedCodexSession(
        in windows: [TerminalWindowSnapshot],
        isFrontmost: Bool
    ) -> TerminalSessionSnapshot? {
        guard isFrontmost else { return nil }
        return windows.first(where: \.isActive)?
            .tabs.first(where: \.isSelected)?
            .sessions.first(where: \.isActive)
    }

    private func codexCompletionAcknowledgement(
        for session: TerminalSessionSnapshot
    ) -> CodexCompletionAcknowledgement? {
        guard let tty = session.tty,
              codexObservationSessionIdentityByTTY[tty] == session.id,
              let observation = codexObservations[tty] else { return nil }
        return CodexCompletionAcknowledgement(observation: observation, sessionID: session.id)
    }

    private func acknowledgeCodexCompletion(
        _ completion: CodexCompletionAcknowledgement?,
        tty: String?
    ) -> Bool {
        guard let completion, let tty,
              codexObservationSessionIdentityByTTY[tty] == completion.sessionID,
              let observation = codexObservations[tty],
              completion == CodexCompletionAcknowledgement(
                observation: observation, sessionID: completion.sessionID
              ), codexAcknowledgedCompletions[tty] != completion else { return false }
        codexAcknowledgedCompletions[tty] = completion
        return true
    }

    private func acknowledgeFocusedCodexCompletion(
        in windows: [TerminalWindowSnapshot],
        terminal: TerminalApp
    ) {
        let session = Self.focusedCodexSession(
            in: windows,
            isFrontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier == terminal.bundleIdentifier
        )
        let previousID = codexFocusedSessionIDs[terminal.bundleIdentifier]
        codexFocusedSessionIDs[terminal.bundleIdentifier] = session?.id
        guard let session, session.id != previousID else { return }
        _ = acknowledgeCodexCompletion(codexCompletionAcknowledgement(for: session), tty: session.tty)
    }

    private func refreshCodexMonitoring() {
        guard isStarted, codexMonitorScanID == nil else { return }
        let sessionIdentityByTTY = Self.codexSessionIdentityByTTY(in: iTermWindows)
        let terminalThreadPrefixes = Self.codexThreadPrefixesByTTY(in: iTermWindows)
        let ttys = Set(sessionIdentityByTTY.keys)
        guard !ttys.isEmpty else {
            codexObservations = [:]
            codexObservationSessionIdentityByTTY = [:]
            codexAcknowledgedCompletions = [:]
            codexTitleTasks.values.forEach { $0.task.cancel() }
            codexTitleTasks = [:]
            codexTitleStates = [:]
            codexRuntimeTasks.values.forEach { $0.cancel() }
            codexRuntimeTasks = [:]
            codexFinalReadTTYs = []
            codexRuntimeObservations = [:]
            codexNativeObservations = [:]
            codexNativeThreadPrefixes = [:]
            codexThreadBindings = [:]
            codexMonitorQueue.async { [codexSessionMonitor] in codexSessionMonitor.reset() }
            return
        }
        let scanID = UUID()
        codexMonitorScanID = scanID
        codexMonitorQueue.async { [weak self] in
            guard let self else { return }
            let observations = codexSessionMonitor.observations(
                in: ttys,
                expectedGeneration: codexSessionMonitor.scanGeneration(),
                terminalThreadPrefixes: terminalThreadPrefixes
            )
            DispatchQueue.main.async { [weak self] in
                guard let self, isStarted, codexMonitorScanID == scanID else { return }
                codexMonitorScanID = nil
                let currentIdentityByTTY = Self.codexSessionIdentityByTTY(in: iTermWindows)
                let currentThreadPrefixes = Self.codexThreadPrefixesByTTY(in: iTermWindows)
                guard sessionIdentityByTTY == currentIdentityByTTY,
                      terminalThreadPrefixes == currentThreadPrefixes else {
                    let changedTTYs = Self.changedCodexSessionTTYs(
                        captured: sessionIdentityByTTY, current: currentIdentityByTTY
                    )
                    if !changedTTYs.isEmpty {
                        codexMonitorQueue.async { [codexSessionMonitor] in
                            codexSessionMonitor.reset(ttys: changedTTYs)
                        }
                    }
                    refreshCodexMonitoring()
                    return
                }
                codexNativeObservations = observations
                codexNativeThreadPrefixes = terminalThreadPrefixes
                reconcileCodexBindings(observations: observations, identities: sessionIdentityByTTY)
                acceptCodexObservations(mergingCodexRuntimeObservations(), identities: sessionIdentityByTTY)
                refreshBoundCodexThreads()
            }
        }
    }

    func boundCodexThreadID(_ session: TerminalSessionSnapshot) -> String? {
        guard let tty = session.tty,
              let binding = codexThreadBindings[tty], binding.isManual,
              binding.terminalSessionID == session.id else { return nil }
        return binding.threadID
    }

    func bindCodexThread(_ threadID: String?, to session: TerminalSessionSnapshot) {
        guard let tty = session.tty,
              codexObservationSessionIdentityByTTY[tty] == session.id,
              let observation = codexObservations[tty], observation.isProcessAlive,
              let processIdentity = observation.processIdentity else {
            actionError = "This Codex terminal is no longer available."
            return
        }
        let normalized = threadID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let normalized {
            guard UUID(uuidString: normalized) != nil else {
                actionError = "Enter the Codex thread ID shown by /status."
                return
            }
            guard !codexThreadBindings.contains(where: { $0.key != tty && $0.value.threadID == normalized }) else {
                actionError = "This Codex conversation is already tracked in another terminal."
                return
            }
        }
        actionError = nil
        codexRuntimeTasks.removeValue(forKey: tty)?.cancel()
        codexFinalReadTTYs.remove(tty)
        codexRuntimeObservations[tty] = nil
        codexThreadBindings[tty] = normalized.map {
            CodexThreadBinding(terminalSessionID: session.id, processIdentity: processIdentity, threadID: $0)
        }
        codexTitleTasks.removeValue(forKey: tty)?.task.cancel()
        codexTitleStates[tty] = nil
        codexObservations[tty] = CodexSessionObservation(
            status: nil, changedAt: nil, processIdentity: processIdentity, sessionID: normalized
        )
        publishItermWindows()
        refreshCodexMonitoring()
    }

    /// Keeps manual choices and derives unambiguous daemon queries from automatic rollout matches.
    static func reconciledCodexBindings(
        _ existing: [String: CodexThreadBinding],
        observations: [String: CodexSessionObservation], identities: [String: String]
    ) -> [String: CodexThreadBinding] {
        var bindings = existing.filter { tty, binding in
            guard identities[tty] == binding.terminalSessionID,
                  let observation = observations[tty],
                  observation.processIdentity == binding.processIdentity else { return false }
            return binding.isManual || (observation.requiresRuntimeStatus
                && observation.sessionID?.lowercased() == binding.threadID)
        }
        for (tty, observation) in observations where bindings[tty] == nil && observation.isProcessAlive {
            guard observation.requiresRuntimeStatus, let terminalID = identities[tty],
                  let process = observation.processIdentity, let sessionID = observation.sessionID,
                  let threadID = UUID(uuidString: sessionID)?.uuidString.lowercased() else { continue }
            bindings[tty] = CodexThreadBinding(
                terminalSessionID: terminalID, processIdentity: process, threadID: threadID, isManual: false
            )
        }
        let counts = Dictionary(grouping: bindings.values, by: \.threadID).mapValues(\.count)
        return bindings.filter { _, binding in binding.isManual || counts[binding.threadID] == 1 }
    }

    private func reconcileCodexBindings(
        observations: [String: CodexSessionObservation], identities: [String: String]
    ) {
        let bindings = Self.reconciledCodexBindings(
            codexThreadBindings, observations: observations, identities: identities
        )
        for (tty, binding) in codexThreadBindings where bindings[tty] != binding {
            codexRuntimeTasks.removeValue(forKey: tty)?.cancel()
            codexFinalReadTTYs.remove(tty)
            codexRuntimeObservations[tty] = nil
        }
        codexThreadBindings = bindings
        for tty in bindings.keys {
            let isFinal = observations[tty]?.isProcessAlive == false
            if isFinal != codexFinalReadTTYs.contains(tty) {
                codexRuntimeTasks.removeValue(forKey: tty)?.cancel()
                codexRuntimeObservations[tty] = nil
                if isFinal { codexFinalReadTTYs.insert(tty) }
                else { codexFinalReadTTYs.remove(tty) }
            }
        }
    }

    private static func codexRuntimeBaseline(
        _ observation: CodexSessionObservation, binding: CodexThreadBinding
    ) -> CodexSessionObservation {
        guard observation.sessionID?.lowercased() != binding.threadID else { return observation }
        return CodexSessionObservation(
            status: nil, changedAt: nil, processIdentity: binding.processIdentity,
            sessionID: binding.threadID, isProcessAlive: observation.isProcessAlive
        )
    }

    /// Invalidates an asynchronous status result when its sampled rollout has moved to another lifecycle.
    static func mergingCodexRuntimeObservation(
        _ overlay: CodexRuntimeOverlay, into observation: CodexSessionObservation
    ) -> CodexSessionObservation {
        let baseline = overlay.sampledFrom
        let runtime = overlay.observation
        guard runtime.processIdentity == observation.processIdentity,
              runtime.sessionID?.lowercased() == observation.sessionID?.lowercased(),
              baseline.processIdentity == observation.processIdentity,
              baseline.sessionID?.lowercased() == observation.sessionID?.lowercased() else { return observation }
        let matchesLifecycle = baseline.isProcessAlive == observation.isProcessAlive
            && baseline.status == observation.status && baseline.changedAt == observation.changedAt
            && baseline.completionInProgressID == observation.completionInProgressID
            && baseline.latestCompletion == observation.latestCompletion
            && baseline.recentCompletions == observation.recentCompletions
        var completions: [String: SessionCompletion] = [:]
        for completion in (observation.recentCompletions ?? []) + [observation.latestCompletion].compactMap({ $0 }) {
            completions[completion.id] = completion
        }
        for completion in (runtime.recentCompletions ?? []) + [runtime.latestCompletion].compactMap({ $0 }) {
            let existing = completions[completion.id]
            // Rollout timestamps retain subsecond order when the daemon reports whole seconds.
            completions[completion.id] = SessionCompletion(
                id: completion.id, completedAt: existing?.completedAt ?? completion.completedAt,
                exitStatus: completion.exitStatus ?? existing?.exitStatus
            )
        }
        let recent = Array(completions.values.sorted {
            $0.completedAt == $1.completedAt ? $0.id < $1.id : $0.completedAt < $1.completedAt
        }.suffix(64))
        let runtimeChangedAt = runtime.status == .finished
            ? runtime.latestCompletion.flatMap { completions[$0.id]?.completedAt } ?? runtime.changedAt
            : runtime.changedAt
        let isOlder = runtimeChangedAt.map { floor($0) < floor(observation.changedAt ?? 0) } ?? false
        let matchesCurrentTurn = observation.completionInProgressID.map { turn in
            switch runtime.status {
            case .finished: return runtime.latestCompletion?.id == turn
            case .running, .awaitingInput: return runtime.completionInProgressID == turn
            default: return true
            }
        } ?? true
        let useRuntimeStatus = matchesLifecycle && runtime.status != nil && !isOlder && matchesCurrentTurn
            && !(runtime.status == .idle && observation.status != nil)
        return CodexSessionObservation(
            status: useRuntimeStatus ? runtime.status : observation.status,
            changedAt: useRuntimeStatus ? runtimeChangedAt : observation.changedAt,
            processIdentity: observation.processIdentity,
            titleExcerpt: observation.titleExcerpt ?? runtime.titleExcerpt,
            sessionID: observation.sessionID,
            latestCompletion: recent.last,
            recentCompletions: recent.isEmpty && observation.recentCompletions == nil
                && runtime.recentCompletions == nil ? nil : recent,
            completionInProgressID: useRuntimeStatus
                ? runtime.completionInProgressID : observation.completionInProgressID,
            isProcessAlive: observation.isProcessAlive,
            requiresRuntimeStatus: observation.requiresRuntimeStatus
        )
    }

    private func mergingCodexRuntimeObservations() -> [String: CodexSessionObservation] {
        var observations = codexNativeObservations
        for (tty, binding) in codexThreadBindings {
            guard let native = observations[tty] else { continue }
            let baseline = Self.codexRuntimeBaseline(native, binding: binding)
            observations[tty] = codexRuntimeObservations[tty].map {
                Self.mergingCodexRuntimeObservation($0, into: baseline)
            } ?? baseline
        }
        return observations
    }

    private func refreshBoundCodexThreads() {
        for (tty, binding) in codexThreadBindings where codexRuntimeTasks[tty] == nil {
            let isFinal = codexFinalReadTTYs.contains(tty)
            guard let native = codexNativeObservations[tty],
                  !isFinal || codexRuntimeObservations[tty] == nil else { continue }
            let baseline = Self.codexRuntimeBaseline(native, binding: binding)
            let terminalThreadPrefix = codexNativeThreadPrefixes[tty]
            codexRuntimeTasks[tty] = Task { @MainActor [weak self] in
                let runtime = try? await CodexAppServerClient().observation(
                    threadID: binding.threadID, includeUnloadedHistory: isFinal
                )
                let excerpt: String?
                if let path = runtime?.rolloutPath, let self, !Task.isCancelled {
                    excerpt = await withCheckedContinuation { continuation in
                        self.codexMonitorQueue.async { [codexSessionMonitor = self.codexSessionMonitor] in
                            continuation.resume(returning: codexSessionMonitor.titleExcerpt(
                                at: path, threadID: binding.threadID, process: binding.processIdentity
                            ))
                        }
                    }
                } else {
                    excerpt = nil
                }
                guard let self, !Task.isCancelled, codexThreadBindings[tty] == binding else { return }
                codexRuntimeTasks[tty] = nil
                guard isStarted, codexNativeObservations[tty]?.processIdentity == binding.processIdentity,
                      Self.codexSessionIdentityByTTY(in: iTermWindows)[tty] == binding.terminalSessionID,
                      Self.codexThreadPrefixesByTTY(in: iTermWindows)[tty] == terminalThreadPrefix else { return }
                let status = runtime?.status
                let observation = CodexSessionObservation(
                    status: isFinal && (status == .running || status == .awaitingInput) ? nil : status,
                    changedAt: runtime?.changedAt,
                    processIdentity: binding.processIdentity,
                    titleExcerpt: excerpt,
                    sessionID: binding.threadID,
                    latestCompletion: runtime?.latestCompletion,
                    recentCompletions: runtime?.recentCompletions,
                    completionInProgressID: isFinal ? nil : runtime?.completionInProgressID,
                    isProcessAlive: !isFinal
                )
                codexRuntimeObservations[tty] = CodexRuntimeOverlay(observation: observation, sampledFrom: baseline)
                acceptCodexObservations(mergingCodexRuntimeObservations(), identities: codexObservationSessionIdentityByTTY)
            }
        }
    }

    private func acceptCodexObservations(
        _ observations: [String: CodexSessionObservation], identities: [String: String]
    ) {
        let accepted = identities.filter { observations[$0.key] != nil }
        reconcileCodexTitles(observations: observations, terminalSessionIDs: accepted)
        scheduleCodexTitles(observations: observations, terminalSessionIDs: accepted)
        guard codexObservations != observations || codexObservationSessionIdentityByTTY != accepted else { return }
        codexObservations = observations
        codexObservationSessionIdentityByTTY = accepted
        codexAcknowledgedCompletions = codexAcknowledgedCompletions.filter { tty, completion in
            guard accepted[tty] == completion.sessionID, let observation = observations[tty] else { return false }
            return completion == CodexCompletionAcknowledgement(observation: observation, sessionID: completion.sessionID)
        }
        publishItermWindows()
    }

    private func reconcileCodexTitles(
        observations: [String: CodexSessionObservation],
        terminalSessionIDs: [String: String]
    ) {
        let staleTTYs = codexTitleStates.compactMap { tty, state -> String? in
            guard terminalSessionIDs[tty] == state.terminalSessionID,
                  observations[tty]?.processIdentity == state.processIdentity,
                  observations[tty]?.sessionID == state.codexSessionID else { return tty }
            return nil
        }
        for tty in staleTTYs {
            codexTitleTasks.removeValue(forKey: tty)?.task.cancel()
            codexTitleStates[tty] = nil
        }
    }

    private func scheduleCodexTitles(
        observations: [String: CodexSessionObservation],
        terminalSessionIDs: [String: String]
    ) {
        let cachedTitles = titleDefaults.data(forKey: Self.codexTitleCacheKey).flatMap {
            try? JSONDecoder().decode([String: CachedCodexTitle].self, from: $0)
        } ?? [:]
        for (tty, observation) in observations {
            guard let terminalSessionID = terminalSessionIDs[tty],
                  let processIdentity = observation.processIdentity else { continue }
            let excerpt = observation.titleExcerpt
            let cached = cachedTitles[tty].flatMap { cached in
                cached.terminalSessionID == terminalSessionID && cached.pid == processIdentity.pid
                    && cached.startedAt == processIdentity.startedAt
                    && observation.sessionID != nil && cached.codexSessionID == observation.sessionID
                    && LocalLLMService.isValidSessionTitle(cached.title)
                    ? cached : nil
            }
            var state = codexTitleStates[tty] ?? CodexTitleState(
                terminalSessionID: terminalSessionID,
                processIdentity: processIdentity,
                codexSessionID: observation.sessionID,
                attemptedExcerpt: "",
                attempts: 0,
                completedExcerpt: excerpt.flatMap {
                    cached?.excerptDigest == Self.titleExcerptDigest($0) ? $0 : nil
                },
                title: cached?.title,
                requestID: nil
            )
            // Restoration is independent of the backfill preference and current activity.
            codexTitleStates[tty] = state
            // Backfill requires a verified thread; lifecycle may be unknown after a bounded bootstrap.
            guard generateCodexTitle != nil, observation.sessionID != nil, let excerpt,
                  observation.status == .finished || (state.title == nil && fillsMissingTitles()),
                  state.title != nil || fillsMissingTitles() else { continue }
            if state.attemptedExcerpt != excerpt {
                codexTitleTasks.removeValue(forKey: tty)?.task.cancel()
                state.attemptedExcerpt = excerpt
                state.attempts = 0
                state.requestID = nil
            }
            guard state.completedExcerpt != excerpt,
                  state.attempts < 2,
                  state.requestID == nil else {
                codexTitleStates[tty] = state
                continue
            }
            let requestID = UUID()
            state.attempts += 1
            state.requestID = requestID
            codexTitleStates[tty] = state
            startCodexTitleRequest(
                tty: tty,
                terminalSessionID: terminalSessionID,
                processIdentity: processIdentity,
                codexSessionID: observation.sessionID,
                excerpt: excerpt,
                requestID: requestID,
                requiresFinishedStatus: state.title != nil,
                reportsFailure: false,
                attempt: state.attempts
            )
        }
    }

    private func startCodexTitleRequest(
        tty: String,
        terminalSessionID: String,
        processIdentity: CodexSessionMonitor.ProcessIdentity,
        codexSessionID: String?,
        excerpt: String,
        requestID: UUID,
        requiresFinishedStatus: Bool,
        reportsFailure: Bool,
        attempt: Int
    ) {
        guard let generateCodexTitle else { return }
        let task = Task { @MainActor [weak self] in
            do {
                let title = try await generateCodexTitle(excerpt)
                self?.finishCodexTitleRequest(
                    tty: tty,
                    terminalSessionID: terminalSessionID,
                    processIdentity: processIdentity,
                    codexSessionID: codexSessionID,
                    excerpt: excerpt,
                    requestID: requestID,
                    requiresFinishedStatus: requiresFinishedStatus,
                    manual: reportsFailure,
                    title: title,
                    failure: nil
                )
            } catch {
                CodexTitleDiagnostics.shared.recordFailure(
                    error, manual: reportsFailure, requestID: requestID,
                    codexPID: processIdentity.pid, attempt: attempt
                )
                self?.finishCodexTitleRequest(
                    tty: tty,
                    terminalSessionID: terminalSessionID,
                    processIdentity: processIdentity,
                    codexSessionID: codexSessionID,
                    excerpt: excerpt,
                    requestID: requestID,
                    requiresFinishedStatus: requiresFinishedStatus,
                    manual: reportsFailure,
                    title: nil,
                    failure: reportsFailure ? error.localizedDescription : nil
                )
            }
        }
        codexTitleTasks[tty] = (requestID, task)
    }

    @MainActor
    private func finishCodexTitleRequest(
        tty: String,
        terminalSessionID: String,
        processIdentity: CodexSessionMonitor.ProcessIdentity,
        codexSessionID: String?,
        excerpt: String,
        requestID: UUID,
        requiresFinishedStatus: Bool,
        manual: Bool,
        title: String?,
        failure: String?
    ) {
        defer {
            if codexTitleTasks[tty]?.requestID == requestID {
                codexTitleTasks[tty] = nil
            }
            if codexTitleStates[tty]?.requestID == requestID {
                codexTitleStates[tty]?.requestID = nil
            }
        }
        guard isStarted,
              codexObservationSessionIdentityByTTY[tty] == terminalSessionID,
              Self.codexSessionIdentityByTTY(in: iTermWindows)[tty] == terminalSessionID,
              codexNativeThreadPrefixes[tty] == Self.codexThreadPrefixesByTTY(in: iTermWindows)[tty],
              let observation = codexObservations[tty],
              !requiresFinishedStatus || observation.status == .finished,
              observation.processIdentity == processIdentity,
              observation.sessionID == codexSessionID,
              observation.titleExcerpt == excerpt,
              var state = codexTitleStates[tty],
              state.terminalSessionID == terminalSessionID,
              state.processIdentity == processIdentity,
              state.codexSessionID == codexSessionID,
              state.attemptedExcerpt == excerpt,
              state.requestID == requestID,
              manual || state.title != nil || fillsMissingTitles() else {
            if title != nil {
                CodexTitleDiagnostics.shared.recordDiscard(
                    manual: manual, requestID: requestID, codexPID: processIdentity.pid
                )
            }
            return
        }
        state.requestID = nil
        if let title {
            state.title = title
            state.completedExcerpt = excerpt
            var cached = titleDefaults.data(forKey: Self.codexTitleCacheKey).flatMap {
                try? JSONDecoder().decode([String: CachedCodexTitle].self, from: $0)
            } ?? [:]
            cached[tty] = CachedCodexTitle(
                terminalSessionID: terminalSessionID, pid: processIdentity.pid,
                startedAt: processIdentity.startedAt, codexSessionID: codexSessionID,
                excerptDigest: Self.titleExcerptDigest(excerpt), title: title
            )
            if let data = try? JSONEncoder().encode(cached) {
                titleDefaults.set(data, forKey: Self.codexTitleCacheKey)
            }
        }
        codexTitleStates[tty] = state
        if let failure {
            actionError = "Could not refresh session title: \(failure)"
        }
        guard title != nil else { return }
        publishItermWindows()
    }

    private static func titleExcerptDigest(_ excerpt: String) -> String {
        SHA256.hash(data: Data(excerpt.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func codexSessionIdentityByTTY(
        in windows: [TerminalWindowSnapshot]
    ) -> [String: String] {
        var identities: [String: String] = [:]
        var ambiguousTTYs: Set<String> = []
        for session in windows.flatMap(\.tabs).flatMap(\.sessions) {
            guard let tty = session.tty else { continue }
            if let existing = identities[tty], existing != session.id { ambiguousTTYs.insert(tty) }
            identities[tty] = session.id
        }
        return identities.filter { !ambiguousTTYs.contains($0.key) }
    }

    /// Ignores hints from ambiguous TTYs and preserves the native no-thread-yet sentinel.
    static func codexThreadPrefixesByTTY(in windows: [TerminalWindowSnapshot]) -> [String: String] {
        let identities = codexSessionIdentityByTTY(in: windows)
        var prefixes: [String: String] = [:]
        for session in windows.flatMap(\.tabs).flatMap(\.sessions) {
            guard let tty = session.tty, identities[tty] == session.id,
                  let prefix = session.codexThreadIDPrefix else { continue }
            prefixes[tty] = prefix
        }
        return prefixes
    }

    private func reconcileCodexObservationSessions() {
        let current = Self.codexSessionIdentityByTTY(in: iTermWindows)
        let currentPrefixes = Self.codexThreadPrefixesByTTY(in: iTermWindows)
        let staleTTYs = Self.staleCodexObservationTTYs(
            accepted: codexObservationSessionIdentityByTTY,
            current: current
        )
        let changedHints = Set(codexObservationSessionIdentityByTTY.keys.filter {
            codexNativeThreadPrefixes[$0] != currentPrefixes[$0]
        })
        let invalidatedTTYs = staleTTYs.union(changedHints)
        guard !invalidatedTTYs.isEmpty else { return }
        codexAcknowledgedCompletions = codexAcknowledgedCompletions.filter { !invalidatedTTYs.contains($0.key) }
        codexObservationSessionIdentityByTTY = codexObservationSessionIdentityByTTY.filter {
            !staleTTYs.contains($0.key)
        }
        for tty in invalidatedTTYs {
            let pending = staleTTYs.contains(tty) ? nil : codexObservations[tty].map {
                CodexSessionObservation(
                    status: nil, changedAt: nil, processIdentity: $0.processIdentity,
                    isProcessAlive: $0.isProcessAlive
                )
            }
            codexObservations[tty] = pending
            codexTitleTasks.removeValue(forKey: tty)?.task.cancel()
            codexTitleStates[tty] = nil
            codexRuntimeTasks.removeValue(forKey: tty)?.cancel()
            codexRuntimeObservations[tty] = nil
            codexNativeObservations[tty] = pending
            codexNativeThreadPrefixes[tty] = currentPrefixes[tty]
            codexThreadBindings[tty] = nil
            codexFinalReadTTYs.remove(tty)
        }
        if !staleTTYs.isEmpty {
            codexMonitorScanID = nil
            codexMonitorQueue.async { [codexSessionMonitor] in codexSessionMonitor.reset(ttys: staleTTYs) }
        }
        refreshCodexMonitoring()
    }

    static func staleCodexObservationTTYs(
        accepted: [String: String],
        current: [String: String]
    ) -> Set<String> {
        Set(accepted.compactMap { current[$0.key] == $0.value ? nil : $0.key })
    }

    static func changedCodexSessionTTYs(
        captured: [String: String],
        current: [String: String]
    ) -> Set<String> {
        Set(Set(captured.keys).union(current.keys).filter { captured[$0] != current[$0] })
    }

    private func statusIdentity(for session: TerminalSessionSnapshot) -> SessionStatusIdentity {
        let observation = session.agentKind == .codex
            ? session.tty.flatMap { codexObservations[$0] } : nil
        return SessionStatusIdentity(
            tty: session.tty,
            activityKind: session.activityKind,
            agentKind: session.agentKind,
            status: session.status,
            changedAt: session.statusChangedAt,
            exitStatus: session.exitStatus,
            hasRunningSubagents: session.hasRunningSubagents,
            latestCompletion: session.latestCompletion,
            completionInProgressID: session.completionInProgressID,
            codexThreadIDPrefix: session.codexThreadIDPrefix,
            codexProcess: observation?.processIdentity,
            codexSessionID: observation?.sessionID
        )
    }

    /// Repeated snapshots retain the override; new lifecycle evidence releases it.
    private func applyingManualIdleStatuses(
        to windows: [TerminalWindowSnapshot]
    ) -> [TerminalWindowSnapshot] {
        let sessions = windows.flatMap(\.tabs).flatMap(\.sessions)
        let currentIDs = Set(sessions.map(\.id))
        manualIdleStatuses = manualIdleStatuses.filter { currentIDs.contains($0.key) }
        return windows.map { window in
            TerminalWindowSnapshot(
                id: window.id,
                number: window.number,
                isActive: window.isActive,
                tabs: window.tabs.map { tab in
                    TerminalTabSnapshot(
                        id: tab.id,
                        title: tab.title,
                        isSelected: tab.isSelected,
                        sessions: tab.sessions.map { session in
                            guard let identity = manualIdleStatuses[session.id] else { return session }
                            guard identity == statusIdentity(for: session) else {
                                manualIdleStatuses[session.id] = nil
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
                                status: .idle,
                                activityKind: session.activityKind,
                                exitStatus: nil,
                                statusChangedAt: session.statusChangedAt,
                                hasRunningSubagents: session.hasRunningSubagents,
                                agentKind: session.agentKind,
                                latestCompletion: session.latestCompletion,
                                recentCompletions: session.recentCompletions,
                                completionInProgressID: session.completionInProgressID,
                                codexThreadIDPrefix: session.codexThreadIDPrefix
                            )
                        }
                    )
                }
            )
        }
    }

    private func publishWindows(_ observedWindows: [TerminalWindowSnapshot]) {
        lifecycleWindows = observedWindows
        windows = applyingManualIdleStatuses(to: observedWindows)
    }

    private func publishItermWindows() {
        let visibleWindows = mergingCodexObservations(into: iTermWindows)
        let completions = iTermAgentCompletionTracker.completions(
            in: visibleWindows,
            activityKind: .agent
        )
        recordSuccessfulAgentCompletions(completions)
        updateStatusMenuSummary()
        publishWindows(visibleWindows)
    }

}

final class ItermBridgeClient {
    private static let actionTimeout: TimeInterval = 15

    private let queue = DispatchQueue(label: "com.caishilin.iTermate.bridge")
    private let onMessage: (BridgeMessage) -> Void
    private let onStateChange: (BridgeConnectionState) -> Void
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private var reconnectWorkItem: DispatchWorkItem?
    private var installedBridgeURL: URL?
    private var lastLaunchDate = Date.distantPast
    private var isReady = false
    private var queuedActionRequests: [String: SessionActionRequest] = [:]
    private var actionCompletions: [String: (String?) -> Void] = [:]

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
            for requestID in Array(actionCompletions.keys) {
                finishAction(
                    requestID: requestID,
                    error: "iTerm2 Bridge stopped before completing the action"
                )
            }
            BridgeInstaller.stopRunningBridge()
        }
    }

    func reconnectAfterWake() {
        queue.async { [weak self] in
            self?.scheduleReconnect(after: nil)
        }
    }

    func activate(sessionID: String, completion: @escaping (String?) -> Void) {
        perform(SessionActionRequest(type: "activateSession", requestId: UUID().uuidString,
                                     sessionId: sessionID), completion: completion)
    }

    func close(sessionID: String) {
        let request = SessionActionRequest(
            type: "closeSession",
            requestId: UUID().uuidString,
            sessionId: sessionID
        )
        queue.async { [weak self] in self?.send(request) }
    }

    func closeArchivedSession(sessionID: String, shellPID: Int32, completion: @escaping (String?) -> Void) {
        perform(SessionActionRequest(type: "closeArchivedSession", requestId: UUID().uuidString,
                                     sessionId: sessionID, expectedShellPID: shellPID), completion: completion)
    }

    func resumePiSession(_ location: PiResumeLocation, completion: @escaping (String?) -> Void) {
        perform(SessionActionRequest(type: "resumePiSession", requestId: UUID().uuidString,
                                     path: location.cwd, piSessionId: location.sessionID,
                                     sessionDirectory: location.directory.path), completion: completion)
    }

    func openProject(
        atPath path: String,
        completion: @escaping (String?) -> Void
    ) {
        perform(
            SessionActionRequest(
                type: "openProject",
                requestId: UUID().uuidString,
                path: path
            ),
            completion: completion
        )
    }

    /// Supplies App-observed Codex states for this navigation only, including unknown states.
    func activateNextFinishedSession(
        codexStatuses: [String: TerminalSessionStatus?],
        completion: @escaping (String?) -> Void
    ) {
        perform(
            SessionActionRequest(
                type: "activateNextFinishedSession",
                requestId: UUID().uuidString,
                codexStatuses: codexStatuses
            ),
            completion: completion
        )
    }

    func recoverSessionStatus(sessionID: String, observation: PiStatusSnapshot) {
        struct Request: Encodable {
            let type = "setSessionStatus"
            let requestId = "pi-recovery-" + UUID().uuidString
            let agentKind = SessionAgentKind.pi
            let recovery = true
            let sessionId: String
            let status: TerminalSessionStatus?
            let reporterId: String
            let sequence: Int
            let exitStatus: Int?
            let hasRunningSubagents: Bool
            let completionId: String?
            let completedAt: TimeInterval?
            let latestCompletion: SessionCompletion?
            let recentCompletions: [SessionCompletion]?
        }
        let request = Request(sessionId: sessionID, status: observation.status,
                              reporterId: observation.reporterId, sequence: observation.sequence,
                              exitStatus: observation.exitStatus, hasRunningSubagents: observation.hasRunningSubagents,
                              completionId: observation.completionId, completedAt: observation.completedAt,
                              latestCompletion: observation.latestCompletion,
                              recentCompletions: observation.recentCompletions)
        // Recovery observations must not be queued across a disconnect.
        queue.async { [weak self] in _ = self?.send(request) }
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
                self.flushQueuedActions()
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
                if message.type == "actionResult", let requestID = message.requestId {
                    // A no-longer-needed recovery is normal, not a failed user action.
                    if requestID.hasPrefix("pi-recovery-") { continue }
                    finishAction(
                        requestID: requestID,
                        error: message.ok == true
                            ? nil
                            : message.error ?? "iTerm2 action failed"
                    )
                }
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

    private func perform(
        _ request: SessionActionRequest,
        completion: @escaping (String?) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }
            actionCompletions[request.requestId] = completion
            if isReady {
                if !send(request) {
                    finishAction(
                        requestID: request.requestId,
                        error: "Could not send iTerm2 action"
                    )
                    return
                }
            } else {
                queuedActionRequests[request.requestId] = request
            }
            queue.asyncAfter(deadline: .now() + Self.actionTimeout) { [weak self] in
                guard self?.actionCompletions[request.requestId] != nil else { return }
                self?.finishAction(
                    requestID: request.requestId,
                    error: "iTerm2 action timed out"
                )
            }
        }
    }

    private func flushQueuedActions() {
        let requests = Array(queuedActionRequests.values)
        queuedActionRequests.removeAll()
        for request in requests where !send(request) {
            finishAction(
                requestID: request.requestId,
                error: "Could not send iTerm2 action"
            )
        }
    }

    private func finishAction(requestID: String, error: String?) {
        queuedActionRequests.removeValue(forKey: requestID)
        guard let completion = actionCompletions.removeValue(forKey: requestID) else {
            return
        }
        DispatchQueue.main.async { completion(error) }
    }

    @discardableResult
    private func send<T: Encodable>(_ value: T) -> Bool {
        guard isReady, let connection else { return false }

        do {
            var data = try JSONEncoder().encode(value)
            data.append(0x0A)
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error { self?.scheduleReconnect(after: error) }
            })
            return true
        } catch {
            publish(state: .disconnected("Could not encode Bridge request"))
            return false
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

private struct SessionActionRequest: Encodable {
    let type: String
    let requestId: String
    let sessionId: String?
    let path: String?
    let piSessionId: String?
    let sessionDirectory: String?
    let expectedShellPID: Int32?
    let codexStatuses: [String: TerminalSessionStatus?]?

    init(
        type: String,
        requestId: String,
        sessionId: String? = nil,
        path: String? = nil,
        piSessionId: String? = nil,
        sessionDirectory: String? = nil,
        expectedShellPID: Int32? = nil,
        codexStatuses: [String: TerminalSessionStatus?]? = nil
    ) {
        self.type = type
        self.requestId = requestId
        self.sessionId = sessionId
        self.path = path
        self.piSessionId = piSessionId
        self.sessionDirectory = sessionDirectory
        self.expectedShellPID = expectedShellPID
        self.codexStatuses = codexStatuses
    }
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
