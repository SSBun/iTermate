import AppKit
import Combine
import Foundation
import ServiceManagement
import Sparkle
import SwiftUI
import UserNotifications

private enum PanelFontDefaults {
    static let name = "system"
    static let size: CGFloat = 13
}

enum PanelBackgroundStyle: String, CaseIterable, Identifiable {
    case systemBlur
    case darkBlur
    case lightBlur
    case systemOpaque
    case darkOpaque
    case lightOpaque

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemBlur:
            "System Blur"
        case .darkBlur:
            "Dark Blur"
        case .lightBlur:
            "Light Blur"
        case .systemOpaque:
            "System Opaque"
        case .darkOpaque:
            "Dark Opaque"
        case .lightOpaque:
            "Light Opaque"
        }
    }

    var usesBlur: Bool {
        switch self {
        case .systemBlur, .darkBlur, .lightBlur:
            true
        case .systemOpaque, .darkOpaque, .lightOpaque:
            false
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .systemBlur, .systemOpaque:
            nil
        case .darkBlur, .darkOpaque:
            .dark
        case .lightBlur, .lightOpaque:
            .light
        }
    }
}

enum SessionStatusAnimationStyle: String, CaseIterable, Identifiable {
    case alien
    case robot
    case classic
    /// A static pixel question mark for an Agent awaiting a reply.
    case questionMark = "question_mark"

    var id: String { rawValue }

    var title: String { self == .questionMark ? "Question Mark" : rawValue.capitalized }
}

struct SessionStatusAnimationPreferences: Equatable {
    var style: SessionStatusAnimationStyle
    var colorHex: String? = nil
}

struct ProjectFolderCustomization: Codable, Equatable {
    var isPinned = false
    var isFavorite = false
    var colorHex: String?

    var isEmpty: Bool {
        !isPinned && !isFavorite && colorHex == nil
    }
}

private struct AppConfig {
    var panelWidth = PanelLayout.defaultWidth
    var panelDockingSide: PanelDockingSide = .right
    var panelFontName = PanelFontDefaults.name
    var panelFontSize = PanelFontDefaults.size
    var panelBackgroundStyle: PanelBackgroundStyle = .systemBlur
    var iTerm2PanelEnabled = true
    var ghosttyPanelEnabled = true
    var accentColorHex: String?
    var focusedSectionBackgroundOpacity = 0.05
    var statusAnimationPreferences = Dictionary(
        uniqueKeysWithValues: SessionStatusAnimation.allCases.map {
            ($0, SessionStatusAnimationPreferences(style: $0.defaultStyle))
        }
    )
    var sessionListStyle: SessionListStyle = .window
    var sectionTitleStyle: SectionTitleStyle = .fullPath
    var showsTabHeaders = true
    var showsSessionTime = true
    var sessionTimeFormat: SessionTimeFormat = .compact
    var completionNotificationsEnabled = false
    var projectFolderCustomizations: [String: ProjectFolderCustomization] = [:]

    init(contents: String = "") {
        for line in contents.split(whereSeparator: \.isNewline) {
            let line = line.split(separator: "#", maxSplits: 1)[0]
                .trimmingCharacters(in: .whitespaces)
            guard let separator = line.firstIndex(of: "=") else { continue }

            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)

            if let animation = SessionStatusAnimation.allCases.first(where: {
                key == "status_animation_\($0.rawValue)_style"
            }) {
                if
                    let rawStyle = Self.stringValue(String(value)),
                    let style = SessionStatusAnimationStyle(rawValue: rawStyle)
                {
                    statusAnimationPreferences[
                        animation,
                        default: SessionStatusAnimationPreferences(
                            style: animation.defaultStyle
                        )
                    ].style = style
                }
                continue
            }

            if let animation = SessionStatusAnimation.allCases.first(where: {
                key == "status_animation_\($0.rawValue)_color"
            }) {
                if let color = Self.stringValue(String(value)) {
                    if color == "default" {
                        statusAnimationPreferences[animation]?.colorHex = nil
                    } else if color.count == 6, UInt64(color, radix: 16) != nil {
                        statusAnimationPreferences[animation]?.colorHex = color.uppercased()
                    }
                }
                continue
            }

            switch key {
            case "panel_width":
                if let width = Double(value) {
                    panelWidth = PanelLayout.clampedWidth(CGFloat(width))
                }
            case "panel_docking_side":
                if
                    let side = Self.stringValue(String(value)),
                    let parsedSide = PanelDockingSide(rawValue: side)
                {
                    panelDockingSide = parsedSide
                }
            case "panel_font_name":
                if let fontName = Self.stringValue(String(value)) {
                    panelFontName = fontName
                }
            case "panel_font_size":
                if let size = Double(value), size.isFinite, size > 0 {
                    panelFontSize = CGFloat(size)
                }
            case "panel_background_style":
                if
                    let style = Self.stringValue(String(value)),
                    let parsedStyle = PanelBackgroundStyle(rawValue: style)
                {
                    panelBackgroundStyle = parsedStyle
                }
            case "iterm2_panel_enabled":
                if value == "true" {
                    iTerm2PanelEnabled = true
                } else if value == "false" {
                    iTerm2PanelEnabled = false
                }
            case "ghostty_panel_enabled":
                if value == "true" {
                    ghosttyPanelEnabled = true
                } else if value == "false" {
                    ghosttyPanelEnabled = false
                }
            case "accent_color":
                if let color = Self.stringValue(String(value)) {
                    if color == "system" {
                        accentColorHex = nil
                    } else if color.count == 6, UInt64(color, radix: 16) != nil {
                        accentColorHex = color.uppercased()
                    }
                }
            case "focused_section_background_opacity":
                if let opacity = Double(value), opacity.isFinite {
                    focusedSectionBackgroundOpacity = min(max(opacity, 0), 1)
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
            case "project_folder_customizations":
                if
                    let encoded = Self.stringValue(String(value)),
                    let data = Data(base64Encoded: encoded),
                    let customizations = try? JSONDecoder().decode(
                        [String: ProjectFolderCustomization].self,
                        from: data
                    )
                {
                    projectFolderCustomizations = customizations
                }
            default:
                continue
            }
        }
    }

    var toml: String {
        let statusAnimations = SessionStatusAnimation.allCases.flatMap { animation in
            let preferences = statusAnimationPreferences[animation]
                ?? SessionStatusAnimationPreferences(style: animation.defaultStyle)
            return [
                "status_animation_\(animation.rawValue)_style = \"\(preferences.style.rawValue)\"",
                "status_animation_\(animation.rawValue)_color = \"\(preferences.colorHex ?? "default")\""
            ]
        }.joined(separator: "\n")

        return """
        # iTermate user configuration
        panel_width = \(panelWidth)
        panel_docking_side = "\(panelDockingSide.rawValue)"
        panel_font_name = "\(panelFontName)"
        panel_font_size = \(panelFontSize)
        panel_background_style = "\(panelBackgroundStyle.rawValue)"
        iterm2_panel_enabled = \(iTerm2PanelEnabled)
        ghostty_panel_enabled = \(ghosttyPanelEnabled)
        accent_color = "\(accentColorHex ?? "system")"
        focused_section_background_opacity = \(focusedSectionBackgroundOpacity)
        \(statusAnimations)
        session_list_style = \"\(sessionListStyle.rawValue)\"
        section_title_style = \"\(sectionTitleStyle.rawValue)\"
        shows_tab_headers = \(showsTabHeaders)
        shows_session_time = \(showsSessionTime)
        session_time_format = "\(sessionTimeFormat.rawValue)"
        completion_notifications_enabled = \(completionNotificationsEnabled)
        project_folder_customizations = "\(encodedProjectFolderCustomizations)"
        """
    }

    private var encodedProjectFolderCustomizations: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (
            try? encoder.encode(projectFolderCustomizations).base64EncodedString()
        ) ?? "e30="
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
    @Published private(set) var panelDockingSide: PanelDockingSide
    @Published private(set) var panelFontName: String
    @Published private(set) var panelFontSize: CGFloat
    @Published private(set) var panelBackgroundStyle: PanelBackgroundStyle
    @Published private var iTerm2PanelEnabled: Bool
    @Published private var ghosttyPanelEnabled: Bool
    @Published private(set) var accentColorHex: String?
    @Published private(set) var focusedSectionBackgroundOpacity: Double
    @Published private(set) var statusAnimationPreferences: [
        SessionStatusAnimation: SessionStatusAnimationPreferences
    ]
    @Published private(set) var sessionListStyle: SessionListStyle
    @Published private(set) var sectionTitleStyle: SectionTitleStyle
    @Published private(set) var showsTabHeaders: Bool
    @Published private(set) var showsSessionTime: Bool
    @Published private(set) var sessionTimeFormat: SessionTimeFormat
    @Published private(set) var completionNotificationsEnabled: Bool
    @Published private(set) var projectFolderCustomizations: [
        String: ProjectFolderCustomization
    ]

    private let configURL: URL

    init(configURL: URL = AppSettings.defaultConfigURL) {
        self.configURL = configURL
        let config = AppConfig(contents: (try? String(contentsOf: configURL)) ?? "")
        panelWidth = config.panelWidth
        panelDockingSide = config.panelDockingSide
        panelFontName = config.panelFontName
        panelFontSize = config.panelFontSize
        panelBackgroundStyle = config.panelBackgroundStyle
        iTerm2PanelEnabled = config.iTerm2PanelEnabled
        ghosttyPanelEnabled = config.ghosttyPanelEnabled
        accentColorHex = config.accentColorHex
        focusedSectionBackgroundOpacity = config.focusedSectionBackgroundOpacity
        statusAnimationPreferences = config.statusAnimationPreferences
        sessionListStyle = config.sessionListStyle
        sectionTitleStyle = config.sectionTitleStyle
        showsTabHeaders = config.showsTabHeaders
        showsSessionTime = config.showsSessionTime
        sessionTimeFormat = config.sessionTimeFormat
        completionNotificationsEnabled = config.completionNotificationsEnabled
        projectFolderCustomizations = config.projectFolderCustomizations

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

    var accentColor: Color {
        Self.color(hex: accentColorHex) ?? Color(nsColor: .controlAccentColor)
    }

    func statusAnimationStyle(
        for animation: SessionStatusAnimation
    ) -> SessionStatusAnimationStyle {
        let style = statusAnimationPreferences[animation]?.style ?? animation.defaultStyle
        return animation.availableStyles.contains(style) ? style : animation.defaultStyle
    }

    func statusAnimationColor(for animation: SessionStatusAnimation) -> Color {
        statusAnimationCustomColor(for: animation)
            ?? (animation == .agentAwaitingInput ? accentColor : Color(nsColor: animation.color))
    }

    func statusAnimationCustomColor(
        for animation: SessionStatusAnimation
    ) -> Color? {
        Self.color(hex: statusAnimationPreferences[animation]?.colorHex)
    }

    func hasCustomStatusAnimationColor(
        for animation: SessionStatusAnimation
    ) -> Bool {
        statusAnimationPreferences[animation]?.colorHex != nil
    }

    func setPanelWidth(_ width: CGFloat) {
        panelWidth = PanelLayout.clampedWidth(width)
        updateConfig { $0.panelWidth = panelWidth }
    }

    func setPanelDockingSide(_ side: PanelDockingSide) {
        panelDockingSide = side
        updateConfig { $0.panelDockingSide = side }
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

    func setPanelBackgroundStyle(_ style: PanelBackgroundStyle) {
        panelBackgroundStyle = style
        updateConfig { $0.panelBackgroundStyle = style }
    }

    func isPanelEnabled(for terminalApp: TerminalApp) -> Bool {
        switch terminalApp {
        case .iTerm2:
            iTerm2PanelEnabled
        case .ghostty:
            ghosttyPanelEnabled
        }
    }

    func setPanelEnabled(_ isEnabled: Bool, for terminalApp: TerminalApp) {
        switch terminalApp {
        case .iTerm2:
            iTerm2PanelEnabled = isEnabled
            updateConfig { $0.iTerm2PanelEnabled = isEnabled }
        case .ghostty:
            ghosttyPanelEnabled = isEnabled
            updateConfig { $0.ghosttyPanelEnabled = isEnabled }
        }
    }

    func setAccentColor(_ color: NSColor?) {
        accentColorHex = color.flatMap(Self.hexRGB)
        updateConfig { $0.accentColorHex = accentColorHex }
    }

    func setFocusedSectionBackgroundOpacity(_ opacity: Double) {
        guard opacity.isFinite else { return }
        let opacity = min(max(opacity, 0), 1)
        focusedSectionBackgroundOpacity = opacity
        updateConfig { $0.focusedSectionBackgroundOpacity = opacity }
    }

    func setStatusAnimationStyle(
        _ style: SessionStatusAnimationStyle,
        for animation: SessionStatusAnimation
    ) {
        updateStatusAnimationPreferences(for: animation) { $0.style = style }
    }

    func setStatusAnimationColor(
        _ color: NSColor?,
        for animation: SessionStatusAnimation
    ) {
        updateStatusAnimationPreferences(for: animation) {
            $0.colorHex = color.flatMap(Self.hexRGB)
        }
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

    /// Paths of pinned project folders.
    ///
    /// - Complexity: O(n), where n is the number of customized project folders.
    var pinnedProjectFolderPaths: Set<String> {
        Set(projectFolderCustomizations.compactMap { path, customization in
            customization.isPinned ? path : nil
        })
    }

    func projectFolderCustomization(at path: String) -> ProjectFolderCustomization {
        projectFolderCustomizations[path] ?? ProjectFolderCustomization()
    }

    func projectFolderColor(at path: String) -> Color? {
        Self.color(hex: projectFolderCustomizations[path]?.colorHex)
    }

    func togglePinnedProjectFolder(at path: String) {
        updateProjectFolderCustomization(at: path) { $0.isPinned.toggle() }
    }

    func toggleFavoriteProjectFolder(at path: String) {
        updateProjectFolderCustomization(at: path) { $0.isFavorite.toggle() }
    }

    func setProjectFolderColor(_ color: NSColor?, at path: String) {
        updateProjectFolderCustomization(at: path) {
            $0.colorHex = color.flatMap(Self.hexRGB)
        }
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

    private func updateStatusAnimationPreferences(
        for animation: SessionStatusAnimation,
        _ update: (inout SessionStatusAnimationPreferences) -> Void
    ) {
        updateConfig { config in
            var preferences = config.statusAnimationPreferences[animation]
                ?? SessionStatusAnimationPreferences(style: animation.defaultStyle)
            update(&preferences)
            config.statusAnimationPreferences[animation] = preferences
            statusAnimationPreferences = config.statusAnimationPreferences
        }
    }

    private func updateProjectFolderCustomization(
        at path: String,
        _ update: (inout ProjectFolderCustomization) -> Void
    ) {
        updateConfig { config in
            var customization = config.projectFolderCustomizations[path]
                ?? ProjectFolderCustomization()
            update(&customization)
            if customization.isEmpty {
                config.projectFolderCustomizations.removeValue(forKey: path)
            } else {
                config.projectFolderCustomizations[path] = customization
            }
            projectFolderCustomizations = config.projectFolderCustomizations
        }
    }

    private static func color(hex: String?) -> Color? {
        guard
            let hex,
            hex.count == 6,
            let rgb = UInt64(hex, radix: 16)
        else {
            return nil
        }
        return Color(
            red: Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8) & 0xff) / 255,
            blue: Double(rgb & 0xff) / 255
        )
    }

    private static func hexRGB(_ color: NSColor) -> String? {
        guard let color = color.usingColorSpace(.sRGB) else { return nil }
        return String(
            format: "%02X%02X%02X",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
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
    @ObservedObject var store: ItermStore
    @ObservedObject var settings: AppSettings
    let updater: SPUUpdater

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AgentSettingsView()
                .tabItem {
                    Label("Agents", systemImage: "terminal")
                }

            StatusAnimationSettingsView(settings: settings)
                .tabItem {
                    Label("Status Animation", systemImage: "waveform.path")
                }

            StatisticsSettingsView(store: store)
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar")
                }

            AboutSettingsView(updater: updater)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .tint(settings.accentColor)
        .frame(width: 520, height: 420)
    }
}

private struct StatisticsSettingsView: View {
    @ObservedObject var store: ItermStore

    var body: some View {
        Form {
            Section("Agent Completions") {
                statisticRow("Total", value: store.agentCompletionStatistics.total)
                statisticRow("This Month", value: store.agentCompletionStatistics.month)
                statisticRow("This Week", value: store.agentCompletionStatistics.week)
                statisticRow("Today", value: store.agentCompletionStatistics.day)
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
        .onAppear {
            store.refreshCompletionStatistics()
        }
    }

    private func statisticRow(_ title: String, value: Int) -> some View {
        LabeledContent(title) {
            Text(value.formatted())
                .monospacedDigit()
        }
    }
}

private struct StatusAnimationSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Agent") {
                ForEach(SessionStatusAnimation.agentAnimations) { animation in
                    animationRow(animation)
                }
            }

            Section("Shell") {
                ForEach(SessionStatusAnimation.shellAnimations) { animation in
                    animationRow(animation)
                }
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
    }

    private func animationRow(
        _ animation: SessionStatusAnimation
    ) -> some View {
        LabeledContent(animation.settingsTitle) {
            HStack(spacing: 10) {
                Group {
                    if animation == .agentAwaitingInput {
                        AgentWaitingStatusView(
                            style: settings.statusAnimationStyle(for: animation),
                            color: settings.statusAnimationColor(for: animation)
                        )
                    } else {
                        SessionStatusMatrix(
                            animation: animation,
                            style: settings.statusAnimationStyle(for: animation),
                            customColor: settings.statusAnimationCustomColor(
                                for: animation
                            ).map { NSColor($0) }
                        )
                    }
                }
                .frame(width: 36, height: 16)
                .accessibilityLabel("\(animation.accessibilityLabel) preview")

                Picker(
                    "\(animation.accessibilityLabel) Style",
                    selection: Binding(
                        get: { settings.statusAnimationStyle(for: animation) },
                        set: {
                            settings.setStatusAnimationStyle($0, for: animation)
                        }
                    )
                ) {
                    ForEach(animation.availableStyles) { style in
                        Text(style.title).tag(style)
                    }
                }
                .labelsHidden()
                .frame(width: animation == .agentAwaitingInput ? 124 : 96)

                ColorPicker(
                    "\(animation.accessibilityLabel) Color",
                    selection: Binding(
                        get: { settings.statusAnimationColor(for: animation) },
                        set: {
                            settings.setStatusAnimationColor(
                                NSColor($0),
                                for: animation
                            )
                        }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()

                if settings.hasCustomStatusAnimationColor(for: animation) {
                    Button {
                        settings.setStatusAnimationColor(nil, for: animation)
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Use Default Color")
                    .accessibilityLabel(
                        "Use default color for \(animation.accessibilityLabel)"
                    )
                }
            }
        }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError = ""
    @State private var showsLoginItemError = false
    @State private var showsNotificationAuthorizationAlert = false

    var body: some View {
        Form {
            Section("Application") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { launchesAtLogin },
                        set: setLaunchesAtLogin
                    )
                )
            }

            Section("Terminals") {
                Toggle(
                    "Show Panel in iTerm2",
                    isOn: Binding(
                        get: { settings.isPanelEnabled(for: .iTerm2) },
                        set: { settings.setPanelEnabled($0, for: .iTerm2) }
                    )
                )

                Toggle(
                    "Show Panel in Ghostty",
                    isOn: Binding(
                        get: { settings.isPanelEnabled(for: .ghostty) },
                        set: { settings.setPanelEnabled($0, for: .ghostty) }
                    )
                )
            }

            Section("Panel") {
                Picker(
                    "Preferred Docking Side",
                    selection: Binding(
                        get: { settings.panelDockingSide },
                        set: settings.setPanelDockingSide
                    )
                ) {
                    ForEach(PanelDockingSide.allCases, id: \.self) { side in
                        Text(side.rawValue.capitalized).tag(side)
                    }
                }
            }

            Section("Appearance") {
                Picker(
                    "Background Style",
                    selection: Binding(
                        get: { settings.panelBackgroundStyle },
                        set: settings.setPanelBackgroundStyle
                    )
                ) {
                    ForEach(PanelBackgroundStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                HStack {
                    ColorPicker(
                        "Accent Color",
                        selection: Binding(
                            get: { settings.accentColor },
                            set: { settings.setAccentColor(NSColor($0)) }
                        ),
                        supportsOpacity: false
                    )
                    if settings.accentColorHex != nil {
                        Button("Use System") {
                            settings.setAccentColor(nil)
                        }
                    }
                }

                LabeledContent("Focused Section Opacity") {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { settings.focusedSectionBackgroundOpacity },
                                set: settings.setFocusedSectionBackgroundOpacity
                            ),
                            in: 0...1,
                            step: 0.01
                        )
                        .frame(width: 140)
                        .accessibilityLabel("Focused Section Opacity")

                        Text(
                            settings.focusedSectionBackgroundOpacity,
                            format: .percent.precision(.fractionLength(0))
                        )
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                    }
                }

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
                    "Show Tab Headers",
                    isOn: Binding(
                        get: { settings.showsTabHeaders },
                        set: settings.setShowsTabHeaders
                    )
                )

                Toggle(
                    "Show Session Time",
                    isOn: Binding(
                        get: { settings.showsSessionTime },
                        set: settings.setShowsSessionTime
                    )
                )

                Picker(
                    "Time Format",
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
                    "Notify When Sessions Finish",
                    isOn: Binding(
                        get: { settings.completionNotificationsEnabled },
                        set: setCompletionNotificationsEnabled
                    )
                )
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
        .onAppear {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
        .alert(
            "Couldn’t Update Login Item",
            isPresented: $showsLoginItemError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemError)
        }
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

    private func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginItemError = error.localizedDescription
            showsLoginItemError = true
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
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

private struct AboutSettingsView: View {
    let updater: SPUUpdater
    @StateObject private var viewModel: CheckForUpdatesViewModel

    init(updater: SPUUpdater) {
        self.updater = updater
        _viewModel = StateObject(
            wrappedValue: CheckForUpdatesViewModel(updater: updater)
        )
    }

    var body: some View {
        Form {
            Section("Application") {
                LabeledContent("Name", value: "iTermate")
                LabeledContent("Version", value: versionText)
                LabeledContent("Updates") {
                    Button("Check for Updates…", action: updater.checkForUpdates)
                        .disabled(!viewModel.canCheckForUpdates)
                }
                LabeledContent("Copyright", value: copyrightText)
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
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
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ItermStore
    @ObservedObject var settings: AppSettings
    @State private var projectActionError: String?
    @State private var projectActionIsPending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("iTermate", systemImage: "terminal")
                    .font(.headline)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(statusTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let statusDetail {
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 5) {
                Text(store.completedAgentTurnsToday.formatted())
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(completionCountColor)
                Text("COMPLETED TODAY")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Label(runningAgentSummary, systemImage: "bolt.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)

            Divider()

            Text("FAVORITE PROJECTS")
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)

            favoriteProjects

            if let projectActionError {
                Text(projectActionError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
        .tint(settings.accentColor)
        .frame(width: 340)
        .onAppear {
            projectActionError = nil
            store.refreshStatusMenu()
        }
    }

    @ViewBuilder
    private var favoriteProjects: some View {
        if favoriteProjectPaths.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("No Favorite Projects")
                    .foregroundStyle(.secondary)
                Text("Add favorites from a Project Path section menu.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        } else if favoriteProjectPaths.count > 5 {
            ScrollView {
                favoriteProjectRows
            }
            .frame(height: 160)
        } else {
            favoriteProjectRows
        }
    }

    private var favoriteProjectRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(favoriteProjectPaths, id: \.self) { path in
                Button {
                    openFavoriteProject(atPath: path)
                } label: {
                    HStack(spacing: 12) {
                        Text(projectTitle(for: path))
                            .lineLimit(1)
                            .layoutPriority(1)
                        Spacer(minLength: 8)
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 210, alignment: .trailing)
                            .help(path)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .disabled(projectActionIsPending)
            }
        }
    }

    private var favoriteProjectPaths: [String] {
        settings.projectFolderCustomizations.compactMap { path, customization in
            customization.isFavorite ? path : nil
        }.sorted { first, second in
            let titleOrder = projectTitle(for: first).localizedStandardCompare(
                projectTitle(for: second)
            )
            if titleOrder == .orderedSame {
                return first.localizedStandardCompare(second) == .orderedAscending
            }
            return titleOrder == .orderedAscending
        }
    }

    private var completionCountColor: Color {
        store.completedAgentTurnsToday > 0 ? settings.accentColor : .primary
    }

    private var runningAgentSummary: String {
        guard let count = store.runningAgentSessionCount else {
            return "Running agents unavailable"
        }
        return "\(count) \(count == 1 ? "agent" : "agents") running"
    }

    private var statusTitle: String {
        switch store.statusMenuConnectionState {
        case .connecting:
            "Connecting"
        case .disconnected:
            "Disconnected"
        case .connected:
            "Connected"
        }
    }

    private var statusColor: Color {
        switch store.statusMenuConnectionState {
        case .connecting:
            .orange
        case .disconnected:
            .red
        case .connected:
            .green
        }
    }

    private var statusDetail: String? {
        guard case .disconnected(let message) = store.statusMenuConnectionState else {
            return nil
        }
        return message
    }

    private func projectTitle(for path: String) -> String {
        let title = (path as NSString).lastPathComponent
        return title.isEmpty ? path : title
    }

    private func openFavoriteProject(atPath path: String) {
        projectActionError = nil
        projectActionIsPending = true
        store.openFavoriteProject(atPath: path) { error in
            projectActionIsPending = false
            if let error {
                projectActionError = error
            } else {
                dismiss()
            }
        }
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
