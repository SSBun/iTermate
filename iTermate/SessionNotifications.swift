import Combine
import Foundation
import UserNotifications

struct SessionCompletionTracker {
    private var previousRunningSessionIDs: Set<String>?

    mutating func completions(
        in windows: [TerminalWindowSnapshot]
    ) -> [TerminalSessionSnapshot] {
        let sessions = windows.flatMap(\.tabs).flatMap(\.sessions)
        let runningSessionIDs = Set(
            sessions.lazy.filter { $0.status == .running }.map(\.id)
        )
        defer { previousRunningSessionIDs = runningSessionIDs }

        guard let previousRunningSessionIDs else { return [] }
        return sessions.filter {
            $0.status == .finished && previousRunningSessionIDs.contains($0.id)
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
        windowsSubscription = store.$windows.sink { [weak self] windows in
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
