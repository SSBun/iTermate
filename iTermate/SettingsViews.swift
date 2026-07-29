import AppKit
import Foundation
import SwiftUI
import UserNotifications

private struct AppConfig {
    var panelWidth = PanelLayout.defaultWidth
    var sessionListStyle: SessionListStyle = .window
    var showsTabHeaders = true
    var completionNotificationsEnabled = false

    init(contents: String = "") {
        for line in contents.split(whereSeparator: \.isNewline) {
            let line = line.split(separator: "#", maxSplits: 1)[0]
                .trimmingCharacters(in: .whitespaces)
            guard let separator = line.firstIndex(of: "=") else { continue }

            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)

            switch key {
            case "panel_width":
                if let width = Double(value) {
                    panelWidth = PanelLayout.clampedWidth(CGFloat(width))
                }
            case "session_list_style":
                if let style = Self.stringValue(String(value)),
                   let parsedStyle = SessionListStyle(rawValue: style) {
                    sessionListStyle = parsedStyle
                }
            case "shows_tab_headers":
                if value == "true" {
                    showsTabHeaders = true
                } else if value == "false" {
                    showsTabHeaders = false
                }
            case "completion_notifications_enabled":
                if value == "true" {
                    completionNotificationsEnabled = true
                } else if value == "false" {
                    completionNotificationsEnabled = false
                }
            default:
                continue
            }
        }
    }

    init(
        panelWidth: CGFloat,
        sessionListStyle: SessionListStyle,
        showsTabHeaders: Bool,
        completionNotificationsEnabled: Bool
    ) {
        self.panelWidth = panelWidth
        self.sessionListStyle = sessionListStyle
        self.showsTabHeaders = showsTabHeaders
        self.completionNotificationsEnabled = completionNotificationsEnabled
    }

    var toml: String {
        """
        # iTermate user configuration
        panel_width = \(panelWidth)
        session_list_style = \"\(sessionListStyle.rawValue)\"
        shows_tab_headers = \(showsTabHeaders)
        completion_notifications_enabled = \(completionNotificationsEnabled)
        """
    }

    private static func stringValue(_ value: String) -> String? {
        guard value.first == "\"", value.last == "\"" else { return nil }
        return String(value.dropFirst().dropLast())
    }
}

final class AppSettings: ObservableObject {
    static let defaultConfigURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".iTermate", isDirectory: true)
        .appendingPathComponent("config.toml")

    @Published private(set) var panelWidth: CGFloat
    @Published private(set) var sessionListStyle: SessionListStyle
    @Published private(set) var showsTabHeaders: Bool
    @Published private(set) var completionNotificationsEnabled: Bool

    private let configURL: URL

    init(configURL: URL = AppSettings.defaultConfigURL) {
        self.configURL = configURL
        let config = AppConfig(contents: (try? String(contentsOf: configURL)) ?? "")
        panelWidth = config.panelWidth
        sessionListStyle = config.sessionListStyle
        showsTabHeaders = config.showsTabHeaders
        completionNotificationsEnabled = config.completionNotificationsEnabled
        saveConfig()
    }

    func setPanelWidth(_ width: CGFloat) {
        panelWidth = PanelLayout.clampedWidth(width)
        saveConfig()
    }

    func resetPanelWidth() {
        setPanelWidth(PanelLayout.defaultWidth)
    }

    func setSessionListStyle(_ style: SessionListStyle) {
        sessionListStyle = style
        saveConfig()
    }

    func setShowsTabHeaders(_ showsTabHeaders: Bool) {
        self.showsTabHeaders = showsTabHeaders
        saveConfig()
    }

    func setCompletionNotificationsEnabled(_ enabled: Bool) {
        completionNotificationsEnabled = enabled
        saveConfig()
    }

    func requestCompletionNotificationAuthorization(
        using notificationCenter: UNUserNotificationCenter = .current()
    ) {
        guard completionNotificationsEnabled else { return }

        notificationCenter.requestAuthorization(options: [.alert, .sound]) {
            [weak self] granted, error in
            if let error {
                NSLog(
                    "iTermate notification authorization failed: %@",
                    String(describing: error)
                )
            }
            guard !granted else { return }
            DispatchQueue.main.async {
                self?.setCompletionNotificationsEnabled(false)
            }
        }
    }

    private func saveConfig() {
        let config = AppConfig(
            panelWidth: panelWidth,
            sessionListStyle: sessionListStyle,
            showsTabHeaders: showsTabHeaders,
            completionNotificationsEnabled: completionNotificationsEnabled
        )
        try? FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? config.toml.write(to: configURL, atomically: true, encoding: .utf8)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            BasicSettingsView(settings: settings)
                .tabItem {
                    Label("Basic", systemImage: "slider.horizontal.3")
                }

            AgentSettingsView()
                .tabItem {
                    Label("Agents", systemImage: "terminal")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 420)
    }
}

private struct BasicSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Sessions") {
                Toggle(
                    "Show tab headers in Window view",
                    isOn: Binding(
                        get: { settings.showsTabHeaders },
                        set: settings.setShowsTabHeaders
                    )
                )
                .toggleStyle(.checkbox)
            }

            Section("Notifications") {
                Toggle(
                    "Notify when sessions finish",
                    isOn: Binding(
                        get: { settings.completionNotificationsEnabled },
                        set: setCompletionNotificationsEnabled
                    )
                )
                .toggleStyle(.checkbox)
            }
        }
        .formStyle(.grouped)
    }

    private func setCompletionNotificationsEnabled(_ enabled: Bool) {
        settings.setCompletionNotificationsEnabled(enabled)
        settings.requestCompletionNotificationAuthorization()
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            Text("iTermate")
                .font(.title2.bold())

            Text(versionText)
                .foregroundStyle(.secondary)

            Text(copyrightText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var copyrightText: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(String(year)) iTermate"
    }

    private var versionText: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "Version \(version) (\($0))" } ?? "Version \(version)"
    }
}

struct StatusMenuView: View {
    @ObservedObject var store: ItermStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("iTermate", systemImage: "terminal")
                .font(.headline)

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusTitle)
                Spacer()
            }

            if let statusDetail {
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            LabeledContent("Windows", value: "\(store.windows.count)")
            LabeledContent("Tabs", value: "\(tabCount)")

            Divider()

            HStack {
                settingsControl
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private var tabCount: Int {
        store.windows.reduce(0) { $0 + $1.tabs.count }
    }

    private var statusTitle: String {
        switch store.connectionState {
        case .connecting:
            "Connecting"
        case .disconnected:
            "Disconnected"
        case .connected:
            "Connected"
        }
    }

    private var statusColor: Color {
        switch store.connectionState {
        case .connecting:
            .orange
        case .disconnected:
            .red
        case .connected:
            .green
        }
    }

    private var statusDetail: String? {
        guard case .disconnected(let message) = store.connectionState else {
            return nil
        }
        return message
    }

    @ViewBuilder
    private var settingsControl: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Text("Settings…")
            }
        } else {
            Button("Settings…") {
                NSApplication.shared.sendAction(
                    Selector(("showSettingsWindow:")),
                    to: nil,
                    from: nil
                )
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
}
