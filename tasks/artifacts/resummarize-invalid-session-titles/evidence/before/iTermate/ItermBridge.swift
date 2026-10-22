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

    /// A legacy Agent without identity must not be presented as a Shell.
    var environmentAgentKind: SessionAgentKind? {
        agentKind ?? (activityKind == .agent ? .unknown : nil)
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
            sessions: clusteredByTab(commandSessions)
        ))
        return groups
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

        init?(observation: CodexSessionObservation, sessionID: String) {
            guard observation.status == .finished,
                  let processIdentity = observation.processIdentity,
                  let changedAt = observation.changedAt else { return nil }
            self.sessionID = sessionID
            self.processIdentity = processIdentity
            self.changedAt = changedAt
        }
    }

    private struct CodexTitleState {
        let terminalSessionID: String
        let processIdentity: CodexSessionMonitor.ProcessIdentity
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
    private lazy var ghosttyClient = GhosttyClient(
        onSnapshot: { [weak self] windows in self?.applyGhosttySnapshot(windows) },
        onStateChange: { [weak self] state in self?.updateGhosttyConnectionState(state) },
        onActionError: { [weak self] error in self?.updateGhosttyActionError(error) }
    )
    private lazy var terminalStatusServer = TerminalStatusServer(
        onReport: { [weak self] report in self?.applyTerminalStatus(report) ?? false },
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
    private let codexSessionMonitor = CodexSessionMonitor()
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
    private var lastActiveGhosttyTerminalID: String?
    private var iTermAgentCompletionTracker = SessionCompletionTracker()
    private var ghosttyAgentCompletionTracker = SessionCompletionTracker()
    private var iTermSnapshotIsReady = false
    private var ghosttySnapshotIsReady = false
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
        terminalStatusServer.start()
        piArchives.start()
        let statusExpiryTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.expireTerminalStatuses()
            self?.refreshCodexMonitoring()
            self?.refreshVenomDebugMonitoring()
            self?.recoverUnknownPiStatuses()
        }
        RunLoop.main.add(statusExpiryTimer, forMode: .common)
        self.statusExpiryTimer = statusExpiryTimer
        if Self.isRunning(.iTerm2) {
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
        codexMonitorScanID = nil
        codexObservations = [:]
        codexObservationSessionIdentityByTTY = [:]
        codexAcknowledgedCompletions = [:]
        codexFocusedSessionIDs = [:]
        if let terminalDeactivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminalDeactivationObserver)
            self.terminalDeactivationObserver = nil
        }
        codexTitleTasks.values.forEach { $0.task.cancel() }
        codexTitleTasks = [:]
        codexTitleStates = [:]
        codexSessionMonitor.reset()
        venomMonitorScanID = nil
        venomDebugMonitoringSessions = [:]
        invalidatePiStatusRecovery()
        terminalStatusServer.stop()
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
        invalidatePiStatusRecovery()
        venomMonitorScanID = nil
        venomDebugMonitoringSessions = [:]
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

    func refreshCompletionStatistics() {
        updateCompletionStatistics()
    }

    func refreshStatusMenu() {
        updateCompletionStatistics()
        if Self.isRunning(.iTerm2) {
            startClient(for: .iTerm2)
        }
        if Self.isRunning(.ghostty) {
            refreshGhostty(force: true)
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
              let excerpt = observation.titleExcerpt,
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
                ? state.title : nil
        }
        codexTitleStates[tty] = CodexTitleState(
            terminalSessionID: session.id,
            processIdentity: processIdentity,
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
        let didActivate: (String?) -> Void = { [weak self] error in
            guard error == nil, let self,
                  acknowledgeCodexCompletion(completion, tty: session?.tty) else { return }
            publishItermWindows()
            publishGhosttyWindows()
        }
        switch terminalApp ?? .iTerm2 {
        case .iTerm2:
            iTermClient.activate(sessionID: sessionID, completion: didActivate)
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
            ghosttyClient.activate(terminalID: sessionID, completion: didActivate)
        }
    }

    func archivePiSession(_ session: TerminalSessionSnapshot, in terminal: TerminalApp) {
        Task { @MainActor in
            do {
                let shellPID = try await piArchives.archive(session, terminal: terminal)
                guard Self.isRunning(terminal) else { return }
                let completion: (String?) -> Void = { [weak self] failure in
                    if let failure { self?.piArchives.error = "Archive saved, but terminal close failed: \(failure)" }
                }
                switch terminal {
                case .iTerm2: iTermClient.closeArchivedSession(sessionID: session.id, shellPID: shellPID, completion: completion)
                case .ghostty: ghosttyClient.closeArchivedSession(terminalID: session.id, tty: session.tty ?? "", shellPID: shellPID, completion: completion)
                }
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
                    if terminal == .iTerm2 {
                        self.startClient(for: .iTerm2)
                        self.iTermClient.resumePiSession(location, completion: finish)
                    } else {
                        self.ghosttyClient.resumePiSession(location, completion: finish)
                    }
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
            updateStatusMenuSummary()
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
            if terminalApp != .ghostty {
                self.windows = visibleWindows
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
        if terminalApp != .ghostty {
            connectionState = state
            windows = mergingCodexObservations(into: iTermWindows)
        }
    }

    private func recordSuccessfulAgentCompletions(
        _ completions: [TerminalSessionSnapshot]
    ) {
        let successCount = completions.lazy.filter { $0.exitStatus == 0 }.count
        guard successCount > 0 else { return }
        completionCountsByDay[Self.dayKey(), default: 0] += successCount
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
        let ghosttyIsRunning = Self.isRunning(.ghostty)
        var sourceStates: [BridgeConnectionState] = []
        if iTermIsRunning {
            sourceStates.append(
                statusMenuSourceState(
                    connectionState: iTermConnectionState,
                    hasSnapshot: iTermSnapshotIsReady
                )
            )
        }
        if ghosttyIsRunning {
            sourceStates.append(
                statusMenuSourceState(
                    connectionState: ghosttyConnectionState,
                    hasSnapshot: ghosttySnapshotIsReady
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
                + (ghosttyIsRunning ? Self.runningAgentCount(in: ghosttyWindows) : 0)
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
        reconcileCodexObservationSessions()
        acknowledgeFocusedCodexCompletion(in: windows, terminal: .ghostty)

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
            terminalStatusRegistry.activate(tty: tty, acknowledgeAgent: false)
        }
        lastActiveGhosttyTerminalID = activeSession?.id

        ghosttyConnectionState = .connected
        ghosttySnapshotIsReady = true
        publishGhosttyWindows()
        guard terminalApp == .ghostty else { return }
        actionError = nil
        connectionState = .connected
    }

    /// Applies a report and confirms whether the registry accepted it.
    private func applyTerminalStatus(_ report: TerminalStatusReport) -> Bool {
        guard terminalStatusRegistry.apply(report) else { return false }
        publishGhosttyWindows()
        return true
    }

    private func invalidatePiStatusRecovery() {
        piRecoveryGeneration += 1
        // Keep old requests counted until they finish, so reconnects cannot exceed the limit.
    }

    private func recoverUnknownPiStatuses() {
        guard isStarted else { return }
        let sources: [(TerminalApp, [TerminalWindowSnapshot])] = [
            (.iTerm2, iTermConnectionState == .connected ? iTermWindows : []),
            (.ghostty, ghosttyConnectionState == .connected ? ghosttyWindows : []),
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
                      let status = observation.status,
                      isStarted, generation == piRecoveryGeneration else { return }
                let currentWindows = terminal == .iTerm2 ? iTermWindows : ghosttyWindows
                guard let current = currentWindows.flatMap(\.tabs).flatMap(\.sessions).first(where: { $0.id == session.id }),
                      current.tty == session.tty, current.statusChangedAt == session.statusChangedAt,
                      current.status == session.status, current.activityKind == session.activityKind,
                      current.activityKind != .agent || current.status == nil else { return }
                if terminal == .iTerm2 {
                    iTermClient.recoverSessionStatus(sessionID: session.id, observation: observation)
                } else if let tty = session.tty, let state = TerminalStatusReport.State(rawValue: status.rawValue) {
                    let report = TerminalStatusReport(
                        tty: tty, source: .agent, reporterID: observation.reporterId,
                        sequence: observation.sequence, state: state, exitStatus: observation.exitStatus,
                        heartbeat: false, hasRunningSubagents: observation.hasRunningSubagents,
                        agentKind: .pi
                    )
                    if terminalStatusRegistry.apply(report, recovering: true) { publishGhosttyWindows() }
                }
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

    private func expireTerminalStatuses() {
        guard terminalStatusRegistry.expireStaleAgentHeartbeats() else { return }
        publishGhosttyWindows()
    }

    private func resetTerminalStatusTransport() {
        guard terminalStatusRegistry.clearRunning() else { return }
        publishGhosttyWindows()
    }

    private func publishGhosttyWindows() {
        let statusWindows = ghosttySourceWindows.map { window in
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
        ghosttyWindows = mergingCodexObservations(into: statusWindows)
        let completions = ghosttyAgentCompletionTracker.completions(
            in: ghosttyWindows,
            activityKind: .agent
        )
        recordSuccessfulAgentCompletions(completions)
        updateStatusMenuSummary()
        guard terminalApp == .ghostty else { return }
        windows = ghosttyWindows
    }

    private func mergingTerminalStatus(
        into session: TerminalSessionSnapshot
    ) -> TerminalSessionSnapshot {
        guard let tty = session.tty else { return session }
        var session = session
        session.agentKind = terminalStatusRegistry.agentKind(for: tty)
        guard let status = terminalStatusRegistry.visibleStatus(for: tty) else {
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
            statusChangedAt: status.changedAt,
            hasRunningSubagents: status.hasRunningSubagents,
            agentKind: session.agentKind
        )
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
              let observation = codexObservations[tty] else {
            return session
        }
        return Self.mergingCodexObservation(
            observation,
            acceptedSessionID: codexObservationSessionIdentityByTTY[tty],
            acknowledgement: codexAcknowledgedCompletions[tty],
            title: codexTitleStates[tty].flatMap { state in
                state.terminalSessionID == session.id
                    && state.processIdentity == observation.processIdentity ? state.title : nil
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
            exitStatus: status == .finished ? 0 : nil,
            statusChangedAt: observation.changedAt,
            hasRunningSubagents: false,
            agentKind: .codex
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
        let sessionIdentityByTTY = Self.codexSessionIdentityByTTY(
            in: iTermWindows + ghosttySourceWindows
        )
        let ttys = Set(sessionIdentityByTTY.keys)
        guard !ttys.isEmpty else {
            codexObservations = [:]
            codexObservationSessionIdentityByTTY = [:]
            codexAcknowledgedCompletions = [:]
            codexTitleTasks.values.forEach { $0.task.cancel() }
            codexTitleTasks = [:]
            codexTitleStates = [:]
            codexSessionMonitor.reset()
            return
        }
        let scanID = UUID()
        let generation = codexSessionMonitor.scanGeneration()
        codexMonitorScanID = scanID
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let observations = codexSessionMonitor.observations(
                in: ttys,
                expectedGeneration: generation
            )
            DispatchQueue.main.async { [weak self] in
                guard let self, isStarted, codexMonitorScanID == scanID else { return }
                codexMonitorScanID = nil
                let currentIdentityByTTY = Self.codexSessionIdentityByTTY(
                    in: iTermWindows + ghosttySourceWindows
                )
                guard sessionIdentityByTTY == currentIdentityByTTY else {
                    codexSessionMonitor.reset(ttys: Self.changedCodexSessionTTYs(
                        captured: sessionIdentityByTTY,
                        current: currentIdentityByTTY
                    ))
                    refreshCodexMonitoring()
                    return
                }
                let observationIdentities = sessionIdentityByTTY.filter {
                    observations[$0.key] != nil
                }
                reconcileCodexTitles(
                    observations: observations,
                    terminalSessionIDs: observationIdentities
                )
                scheduleCodexTitles(
                    observations: observations,
                    terminalSessionIDs: observationIdentities
                )
                guard codexObservations != observations
                        || codexObservationSessionIdentityByTTY != observationIdentities else { return }
                codexObservations = observations
                codexObservationSessionIdentityByTTY = observationIdentities
                codexAcknowledgedCompletions = codexAcknowledgedCompletions.filter { tty, completion in
                    guard observationIdentities[tty] == completion.sessionID,
                          let observation = observations[tty] else { return false }
                    return completion == CodexCompletionAcknowledgement(
                        observation: observation, sessionID: completion.sessionID
                    )
                }
                publishItermWindows()
                publishGhosttyWindows()
            }
        }
    }

    private func reconcileCodexTitles(
        observations: [String: CodexSessionObservation],
        terminalSessionIDs: [String: String]
    ) {
        let staleTTYs = codexTitleStates.compactMap { tty, state -> String? in
            guard terminalSessionIDs[tty] == state.terminalSessionID,
                  observations[tty]?.processIdentity == state.processIdentity else { return tty }
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
                    && !cached.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? cached : nil
            }
            var state = codexTitleStates[tty] ?? CodexTitleState(
                terminalSessionID: terminalSessionID,
                processIdentity: processIdentity,
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
            guard generateCodexTitle != nil, let excerpt,
                  observation.status == .finished || (state.title == nil && fillsMissingTitles()
                    && (observation.status == .idle || observation.status == .interrupted
                        || observation.status == .awaitingInput)),
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
                excerpt: excerpt,
                requestID: requestID,
                requiresFinishedStatus: observation.status == .finished,
                reportsFailure: false,
                attempt: state.attempts
            )
        }
    }

    private func startCodexTitleRequest(
        tty: String,
        terminalSessionID: String,
        processIdentity: CodexSessionMonitor.ProcessIdentity,
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
              let observation = codexObservations[tty],
              !requiresFinishedStatus || observation.status == .finished,
              observation.processIdentity == processIdentity,
              observation.titleExcerpt == excerpt,
              var state = codexTitleStates[tty],
              state.terminalSessionID == terminalSessionID,
              state.processIdentity == processIdentity,
              state.attemptedExcerpt == excerpt,
              state.requestID == requestID,
              manual || (observation.status != .running && (state.title != nil || fillsMissingTitles())) else {
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
                startedAt: processIdentity.startedAt, excerptDigest: Self.titleExcerptDigest(excerpt), title: title
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
        publishGhosttyWindows()
    }

    private static func titleExcerptDigest(_ excerpt: String) -> String {
        SHA256.hash(data: Data(excerpt.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func codexSessionIdentityByTTY(
        in windows: [TerminalWindowSnapshot]
    ) -> [String: String] {
        var identities: [String: String] = [:]
        for session in windows.flatMap(\.tabs).flatMap(\.sessions) {
            if let tty = session.tty {
                identities[tty] = session.id
            }
        }
        return identities
    }

    private func reconcileCodexObservationSessions() {
        let current = Self.codexSessionIdentityByTTY(in: iTermWindows + ghosttySourceWindows)
        let staleTTYs = Self.staleCodexObservationTTYs(
            accepted: codexObservationSessionIdentityByTTY,
            current: current
        )
        guard !staleTTYs.isEmpty else { return }
        codexObservations = codexObservations.filter { !staleTTYs.contains($0.key) }
        codexAcknowledgedCompletions = codexAcknowledgedCompletions.filter { !staleTTYs.contains($0.key) }
        codexObservationSessionIdentityByTTY = codexObservationSessionIdentityByTTY.filter {
            !staleTTYs.contains($0.key)
        }
        for tty in staleTTYs {
            codexTitleTasks.removeValue(forKey: tty)?.task.cancel()
            codexTitleStates[tty] = nil
        }
        codexMonitorScanID = nil
        codexSessionMonitor.reset(ttys: staleTTYs)
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

    private func publishItermWindows() {
        let visibleWindows = mergingCodexObservations(into: iTermWindows)
        let completions = iTermAgentCompletionTracker.completions(
            in: visibleWindows,
            activityKind: .agent
        )
        recordSuccessfulAgentCompletions(completions)
        updateStatusMenuSummary()
        guard terminalApp != .ghostty else { return }
        windows = visibleWindows
    }

    private func updateGhosttyConnectionState(_ state: BridgeConnectionState) {
        ghosttyRefreshIsPending = false
        ghosttyConnectionState = state
        if state != .connected {
            invalidatePiStatusRecovery()
            ghosttySourceWindows = []
            reconcileCodexObservationSessions()
            ghosttyWindows = []
            ghosttySnapshotIsReady = false
            lastActiveGhosttyTerminalID = nil
            terminalStatusRegistry.reconcile(terminals: [:])
            _ = ghosttyAgentCompletionTracker.completions(
                in: [],
                activityKind: .agent
            )
        }
        updateStatusMenuSummary()
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
        }
        let request = Request(sessionId: sessionID, status: observation.status,
                              reporterId: observation.reporterId, sequence: observation.sequence,
                              exitStatus: observation.exitStatus, hasRunningSubagents: observation.hasRunningSubagents)
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

    func activate(terminalID: String, completion: @escaping (String?) -> Void) {
        perform(.activate, terminalID: terminalID, completion: completion)
    }

    func close(terminalID: String) {
        perform(.close, terminalID: terminalID)
    }

    func closeArchivedSession(terminalID: String, tty: String, shellPID: Int32, completion: @escaping (String?) -> Void) {
        queue.async {
            do {
                guard Self.isGhosttyRunning else { throw GhosttyScriptError("Ghostty is not running") }
                _ = try Self.runScript(script: Self.archiveCloseScript, arguments: [terminalID, tty, String(shellPID)])
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error.localizedDescription) }
            }
        }
    }

    func resumePiSession(_ location: PiResumeLocation, completion: @escaping (String?) -> Void) {
        queue.async {
            do {
                _ = try Self.runScript(script: Self.resumeScript, arguments: [location.cwd, location.sessionID, location.directory.path])
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion("Could not resume Pi in Ghostty: \(error.localizedDescription)") }
            }
        }
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

    private func perform(
        _ action: Action,
        terminalID: String,
        completion: ((String?) -> Void)? = nil
    ) {
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
                DispatchQueue.main.async { [onActionError] in
                    onActionError(nil)
                    completion?(nil)
                }
                loadSnapshot()
            } catch {
                DispatchQueue.main.async { [onActionError] in
                    let message = "Ghostty action failed: \(error.localizedDescription)"
                    onActionError(message)
                    completion?(message)
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

    private static let archiveCloseScript = #"""
    on run argv
        set terminalID to item 1 of argv
        set expectedTTY to item 2 of argv
        set expectedPID to (item 3 of argv) as integer
        tell application "Ghostty"
            if not (exists (first terminal whose id is terminalID)) then return
            set targetTerminal to first terminal whose id is terminalID
            if tty of targetTerminal is not expectedTTY or pid of targetTerminal is not expectedPID then
                error "Terminal ownership changed or the original shell is not idle; left open."
            end if
            close targetTerminal
        end tell
    end run
    """#

    private static let resumeScript = #"""
    on run argv
        set cwdValue to item 1 of argv
        set sessionValue to item 2 of argv
        set directoryValue to item 3 of argv
        set sessionArgument to sessionValue
        if sessionValue ends with ".jsonl" then set sessionArgument to directoryValue & "/archive_" & sessionValue & ".jsonl"
        set innerCommand to "cd -- " & quoted form of cwdValue & " && pi --session " & quoted form of sessionArgument & " --session-dir " & quoted form of directoryValue
        set commandValue to "/bin/zsh -lic " & quoted form of innerCommand
        tell application "Ghostty"
            set config to new surface configuration from {initial working directory:cwdValue, command:commandValue}
            if (count of windows) > 0 then
                new tab in front window with configuration config
            else
                new window with configuration config
            end if
            activate
        end tell
    end run
    """#

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
