import Combine
import Foundation
import UserNotifications

struct SessionCompletionTracker {
    private var previousRunningSessions: [String: TerminalSessionSnapshot]?
    private var observationStartedAt: TimeInterval?
    private var observedCompletionIDs: Set<String> = []
    private var observedInProgressCompletionIDs: Set<String> = []

    mutating func completions(
        in windows: [TerminalWindowSnapshot],
        activityKind: SessionActivityKind? = nil,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> [TerminalSessionSnapshot] {
        let sessions = windows.flatMap(\.tabs).flatMap(\.sessions).filter {
            activityKind == nil || $0.activityKind == activityKind
        }
        let runningSessions = Dictionary(
            sessions.lazy.filter { $0.status == .running }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        defer {
            previousRunningSessions = runningSessions
            for session in sessions where session.status == .running || session.status == .awaitingInput {
                if let id = session.completionInProgressID { observedInProgressCompletionIDs.insert(id) }
            }
        }

        let wasInitialized = observationStartedAt != nil
        let startedAt = observationStartedAt ?? now
        observationStartedAt = startedAt
        return sessions.flatMap { session -> [TerminalSessionSnapshot] in
            if session.recentCompletions != nil || session.latestCompletion != nil {
                let events = session.recentCompletions ?? session.latestCompletion.map { [$0] } ?? []
                return events.sorted { $0.completedAt < $1.completedAt }.compactMap { completion in
                    // Reconnection may replay history; IDs deduplicate across panes and data sources too.
                    guard completion.isValid, observedCompletionIDs.insert(completion.id).inserted,
                          wasInitialized else { return nil }
                    // Codex timestamps have second precision; only the same observed turn may share our start second.
                    let followsRunning = observedInProgressCompletionIDs.contains(completion.id)
                    guard completion.completedAt >= startedAt
                        || (followsRunning && completion.completedAt.rounded(.down) == startedAt.rounded(.down)) else { return nil }
                    return TerminalSessionSnapshot(
                        id: session.id, name: session.name, path: session.path, tty: session.tty,
                        windowId: session.windowId, tabId: session.tabId, isActive: session.isActive,
                        isMinimized: session.isMinimized, status: .finished, activityKind: session.activityKind,
                        exitStatus: completion.exitStatus, statusChangedAt: completion.completedAt,
                        hasRunningSubagents: session.hasRunningSubagents, agentKind: session.agentKind,
                        latestCompletion: completion,
                        codexThreadIDPrefix: session.codexThreadIDPrefix
                    )
                }
            }
            guard session.status == .finished,
                  let previous = previousRunningSessions?[session.id] else { return [] }
            // Replacing a shell fallback with a recovered Agent state is not a completion event.
            return previous.activityKind == session.activityKind ? [session] : []
        }
    }
}

final class SessionNotificationController: NSObject, UNUserNotificationCenterDelegate {
    private static let sessionIDKey = "sessionID"

    private let store: ItermStore
    private let settings: AppSettings
    private let notificationCenter: UNUserNotificationCenter
    private var tracker = SessionCompletionTracker()
    private var windowsSubscription: AnyCancellable?

    init(
        store: ItermStore,
        settings: AppSettings,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.store = store
        self.settings = settings
        self.notificationCenter = notificationCenter
        super.init()
        notificationCenter.delegate = self
        windowsSubscription = store.$lifecycleWindows.sink { [weak self] windows in
            self?.handle(windows)
        }
        settings.requestCompletionNotificationAuthorization(using: notificationCenter)
    }

    static func sessionIDToActivate(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) -> String? {
        guard actionIdentifier == UNNotificationDefaultActionIdentifier else {
            return nil
        }
        return userInfo[sessionIDKey] as? String
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let sessionID = Self.sessionIDToActivate(
            actionIdentifier: response.actionIdentifier,
            userInfo: response.notification.request.content.userInfo
        ) else {
            return
        }
        store.activate(sessionID: sessionID)
    }

    private func handle(_ windows: [TerminalWindowSnapshot]) {
        let completions = tracker.completions(in: windows)
        guard settings.completionNotificationsEnabled else { return }
        completions.forEach(sendNotification)
    }

    private func sendNotification(for session: TerminalSessionSnapshot) {
        let name = session.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = UNMutableNotificationContent()
        content.title = "\(name.isEmpty ? "Session" : name) finished"
        switch session.exitStatus {
        case .some(0):
            content.body = "Completed successfully."
        case let .some(exitStatus):
            content.body = "Exited with status \(exitStatus)."
        case .none:
            content.body = "Command finished."
        }
        content.sound = .default
        content.userInfo = [Self.sessionIDKey: session.id]

        notificationCenter.add(
            UNNotificationRequest(
                identifier: "session-finished-\(session.id)-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
        ) { error in
            if let error {
                NSLog("iTermate notification failed: %@", String(describing: error))
            }
        }
    }
}
