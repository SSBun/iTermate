import AppKit
import Combine
import Foundation
import Sparkle
import SwiftUI
import UserNotifications

private enum PanelFontDefaults {
    static let name = "system"
    static let size: CGFloat = 13
}

private struct AppConfig {
    var panelWidth = PanelLayout.defaultWidth
    var panelFontName = PanelFontDefaults.name
    var panelFontSize = PanelFontDefaults.size
    var sessionListStyle: SessionListStyle = .window
    var sectionTitleStyle: SectionTitleStyle = .fullPath
    var showsTabHeaders = true
    var showsSessionTime = true
    var sessionTimeFormat: SessionTimeFormat = .compact
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
            case "panel_font_name":
                if let fontName = Self.stringValue(String(value)) {
                    panelFontName = fontName
                }
            case "panel_font_size":
                if let size = Double(value), size.isFinite, size > 0 {
                    panelFontSize = CGFloat(size)
                }
            case "session_list_style":
                if let style = Self.stringValue(String(value)),
                   let parsedStyle = SessionListStyle(rawValue: style) {
                    sessionListStyle = parsedStyle
                }
            case "section_title_style":
                if let style = Self.stringValue(String(value)),
                   let parsedStyle = SectionTitleStyle(rawValue: style) {
                    sectionTitleStyle = parsedStyle
                }
            case "shows_tab_headers":
                if value == "true" {
                    showsTabHeaders = true
                } else if value == "false" {
                    showsTabHeaders = false
                }
            case "shows_session_time":
                if value == "true" {
                    showsSessionTime = true
                } else if value == "false" {
                    showsSessionTime = false
                }
            case "session_time_format":
                if let format = Self.stringValue(String(value)),
                   let parsedFormat = SessionTimeFormat(rawValue: format) {
                    sessionTimeFormat = parsedFormat
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

    var toml: String {
        """
        # iTermate user configuration
        panel_width = \(panelWidth)
        panel_font_name = "\(panelFontName)"
        panel_font_size = \(panelFontSize)
        session_list_style = \"\(sessionListStyle.rawValue)\"
        section_title_style = \"\(sectionTitleStyle.rawValue)\"
        shows_tab_headers = \(showsTabHeaders)
        shows_session_time = \(showsSessionTime)
        session_time_format = "\(sessionTimeFormat.rawValue)"
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
    @Published private(set) var panelFontName: String
    @Published private(set) var panelFontSize: CGFloat
    @Published private(set) var sessionListStyle: SessionListStyle
    @Published private(set) var sectionTitleStyle: SectionTitleStyle
    @Published private(set) var showsTabHeaders: Bool
    @Published private(set) var showsSessionTime: Bool
    @Published private(set) var sessionTimeFormat: SessionTimeFormat
    @Published private(set) var completionNotificationsEnabled: Bool

    private let configURL: URL

    init(configURL: URL = AppSettings.defaultConfigURL) {
        self.configURL = configURL
        let config = AppConfig(contents: (try? String(contentsOf: configURL)) ?? "")
        panelWidth = config.panelWidth
        panelFontName = config.panelFontName
        panelFontSize = config.panelFontSize
        sessionListStyle = config.sessionListStyle
        sectionTitleStyle = config.sectionTitleStyle
        showsTabHeaders = config.showsTabHeaders
        showsSessionTime = config.showsSessionTime
        sessionTimeFormat = config.sessionTimeFormat
        completionNotificationsEnabled = config.completionNotificationsEnabled

        if !FileManager.default.fileExists(atPath: configURL.path) {
            writeConfig(config)
        }
    }

    var panelFont: NSFont {
        guard
            panelFontName != PanelFontDefaults.name,
            let font = NSFont(name: panelFontName, size: panelFontSize)
        else {
            return .systemFont(ofSize: panelFontSize)
        }
        return font
    }

    func setPanelWidth(_ width: CGFloat) {
        panelWidth = PanelLayout.clampedWidth(width)
        updateConfig { $0.panelWidth = panelWidth }
    }

    func setPanelFont(_ font: NSFont) {
        panelFontName = font.fontName
        panelFontSize = font.pointSize
        updateConfig {
            $0.panelFontName = panelFontName
            $0.panelFontSize = panelFontSize
        }
    }

    func setPanelFontName(_ fontName: String) {
        panelFontName = fontName
        updateConfig { $0.panelFontName = fontName }
    }

    func setPanelFontSize(_ panelFontSize: CGFloat) {
        guard panelFontSize.isFinite, panelFontSize > 0 else { return }
        self.panelFontSize = panelFontSize
        updateConfig { $0.panelFontSize = panelFontSize }
    }

    func resetPanelWidth() {
        setPanelWidth(PanelLayout.defaultWidth)
    }

    func setSessionListStyle(_ style: SessionListStyle) {
        sessionListStyle = style
        updateConfig { $0.sessionListStyle = style }
    }

    func setSectionTitleStyle(_ style: SectionTitleStyle) {
        sectionTitleStyle = style
        updateConfig { $0.sectionTitleStyle = style }
    }

    func setShowsTabHeaders(_ showsTabHeaders: Bool) {
        self.showsTabHeaders = showsTabHeaders
        updateConfig { $0.showsTabHeaders = showsTabHeaders }
    }

    func setShowsSessionTime(_ showsSessionTime: Bool) {
        self.showsSessionTime = showsSessionTime
        updateConfig { $0.showsSessionTime = showsSessionTime }
    }

    func setSessionTimeFormat(_ format: SessionTimeFormat) {
        sessionTimeFormat = format
        updateConfig { $0.sessionTimeFormat = format }
    }

    func setCompletionNotificationsEnabled(_ enabled: Bool) {
        completionNotificationsEnabled = enabled
        updateConfig { $0.completionNotificationsEnabled = enabled }
    }

    func requestCompletionNotificationAuthorization(
        using notificationCenter: UNUserNotificationCenter = .current(),
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        guard completionNotificationsEnabled else { return }

        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog(
                    "iTermate notification authorization failed: %@",
                    String(describing: error)
                )
                return
            }
            if !granted {
                NSLog("iTermate notification authorization was not granted")
            }
            completion(granted)
        }
    }

    private func updateConfig(_ update: (inout AppConfig) -> Void) {
        let contents: String
        if FileManager.default.fileExists(atPath: configURL.path) {
            guard let existingContents = try? String(contentsOf: configURL) else { return }
            contents = existingContents
        } else {
            contents = ""
        }

        var config = AppConfig(contents: contents)
        update(&config)
        writeConfig(config)
    }

    private func writeConfig(_ config: AppConfig) {
        try? FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? config.toml.write(to: configURL, atomically: true, encoding: .utf8)
    }
}

@available(macOS 14.0, *)
struct OpenSettingsButton<Label: View>: View {
    @Environment(\.openSettings) private var openSettings

    private let label: Label

    init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }

    var body: some View {
        Button {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openSettings()
        } label: {
            label
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let updater: SPUUpdater

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

            AboutSettingsView(updater: updater)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 420)
    }
}

private struct BasicSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var showsNotificationAuthorizationAlert = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker(
                    "Panel Font",
                    selection: Binding(
                        get: {
                            NSFont(name: settings.panelFontName, size: settings.panelFontSize) == nil
                                ? PanelFontDefaults.name
                                : settings.panelFontName
                        },
                        set: settings.setPanelFontName
                    )
                ) {
                    Text("System").tag(PanelFontDefaults.name)
                    ForEach(NSFontManager.shared.availableFonts.sorted(), id: \.self) { fontName in
                        Text(
                            NSFont(name: fontName, size: settings.panelFontSize)?.displayName
                                ?? fontName
                        )
                        .tag(fontName)
                    }
                }

                TextField(
                    "Panel Font Size",
                    value: Binding(
                        get: { Double(settings.panelFontSize) },
                        set: { settings.setPanelFontSize(CGFloat($0)) }
                    ),
                    format: FloatingPointFormatStyle<Double>()
                )
            }

            Section("Sessions") {
                Toggle(
                    "Show tab headers in Window view",
                    isOn: Binding(
                        get: { settings.showsTabHeaders },
                        set: settings.setShowsTabHeaders
                    )
                )
                .toggleStyle(.checkbox)

                Toggle(
                    "Show session time",
                    isOn: Binding(
                        get: { settings.showsSessionTime },
                        set: settings.setShowsSessionTime
                    )
                )
                .toggleStyle(.checkbox)

                Picker(
                    "Time format",
                    selection: Binding(
                        get: { settings.sessionTimeFormat },
                        set: settings.setSessionTimeFormat
                    )
                ) {
                    ForEach(SessionTimeFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .disabled(!settings.showsSessionTime)

                Picker(
                    "Project Path Section Title",
                    selection: Binding(
                        get: { settings.sectionTitleStyle },
                        set: settings.setSectionTitleStyle
                    )
                ) {
                    ForEach(SectionTitleStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .disabled(settings.sessionListStyle != .projectPath)
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
        .alert(
            "Notifications Are Disabled",
            isPresented: $showsNotificationAuthorizationAlert
        ) {
            Button("Open Notification Settings", action: openNotificationSettings)
            Button("Not Now", role: .cancel) {}
        } message: {
            Text(
                "Enable notifications for iTermate in System Settings > Notifications."
            )
        }
    }

    private func setCompletionNotificationsEnabled(_ enabled: Bool) {
        settings.setCompletionNotificationsEnabled(enabled)
        settings.requestCompletionNotificationAuthorization { granted in
            guard !granted else { return }
            DispatchQueue.main.async {
                showsNotificationAuthorizationAlert = true
            }
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

private struct CheckForUpdatesButton: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

private struct AboutSettingsView: View {
    let updater: SPUUpdater

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

            CheckForUpdatesButton(updater: updater)

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
            OpenSettingsButton {
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
