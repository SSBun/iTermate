import AppKit
import SwiftUI

final class AppSettings: ObservableObject {
    private static let panelWidthKey = "panelWidth"
    private static let sessionListStyleKey = "sessionListStyle"
    private static let showsTabHeadersKey = "showsTabHeaders"

    @Published private(set) var panelWidth: CGFloat
    @Published private(set) var sessionListStyle: SessionListStyle
    @Published private(set) var showsTabHeaders: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedWidth = (defaults.object(forKey: Self.panelWidthKey) as? NSNumber)
            .map { CGFloat(truncating: $0) }
        panelWidth = PanelLayout.clampedWidth(savedWidth ?? PanelLayout.defaultWidth)
        sessionListStyle = SessionListStyle(
            rawValue: defaults.string(forKey: Self.sessionListStyleKey) ?? ""
        ) ?? .window
        showsTabHeaders = (defaults.object(forKey: Self.showsTabHeadersKey) as? NSNumber)?
            .boolValue ?? true
    }

    func setPanelWidth(_ width: CGFloat) {
        panelWidth = PanelLayout.clampedWidth(width)
        defaults.set(Double(panelWidth), forKey: Self.panelWidthKey)
    }

    func resetPanelWidth() {
        setPanelWidth(PanelLayout.defaultWidth)
    }

    func setSessionListStyle(_ style: SessionListStyle) {
        sessionListStyle = style
        defaults.set(style.rawValue, forKey: Self.sessionListStyleKey)
    }

    func setShowsTabHeaders(_ showsTabHeaders: Bool) {
        self.showsTabHeaders = showsTabHeaders
        defaults.set(showsTabHeaders, forKey: Self.showsTabHeadersKey)
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

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 460, height: 220)
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
        }
        .formStyle(.grouped)
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
