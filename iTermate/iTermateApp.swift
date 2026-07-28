import AppKit
import CoreGraphics
import SwiftUI

@main
struct ItermateApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(
            "iTermate",
            systemImage: "rectangle.trailinghalf.inset.filled"
        ) {
            StatusMenuView(store: appDelegate.store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: appDelegate.settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let store = ItermStore()

    private var panelFollower: PanelFollower?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        panelFollower = PanelFollower(store: store, settings: settings)
        panelFollower?.start()
        store.start()
    }
}

private final class PanelFollower {
    private let panel: ComradePanel
    private var timer: Timer?

    init(store: ItermStore, settings: AppSettings) {
        panel = ComradePanel(store: store, settings: settings)
    }

    func start() {
        updatePanel()

        // ponytail: Polling avoids Accessibility permission; use AXObserver if profiling shows this costs too much power.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updatePanel()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func updatePanel() {
        guard
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ItermWindow.bundleIdentifier,
            let window = ItermWindow.frontmost(),
            let screen = PanelLayout.screen(containing: window.frame)
        else {
            panel.orderOut(nil)
            return
        }

        guard !panel.inLiveResize else { return }

        let panelFrame = PanelLayout.frame(
            for: window.frame,
            in: screen.visibleFrame,
            width: panel.settings.panelWidth
        )
        panel.setFrame(panelFrame, display: true)

        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }
}

final class ComradePanel: NSPanel, NSWindowDelegate {
    let settings: AppSettings

    init(
        store: ItermStore = ItermStore(),
        settings: AppSettings = AppSettings()
    ) {
        self.settings = settings

        super.init(
            contentRect: CGRect(x: 0, y: 0, width: settings.panelWidth, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        contentView = NSHostingView(
            rootView: PanelContent(store: store, settings: settings)
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false

        var minimumSize = minSize
        minimumSize.width = PanelLayout.minimumWidth
        minSize = minimumSize

        var maximumSize = maxSize
        maximumSize.width = PanelLayout.maximumWidth
        maxSize = maximumSize
        delegate = self
    }

    override var canBecomeKey: Bool { true }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: PanelLayout.clampedWidth(frameSize.width),
            height: sender.frame.height
        )
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        settings.setPanelWidth(frame.width)
    }
}

private struct PanelContent: View {
    @ObservedObject var store: ItermStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("iTermate", systemImage: "terminal")
                    .font(.headline)
                Spacer()
                groupingMenu
            }

            switch store.connectionState {
            case .connecting:
                statusView("Connecting to iTerm2…", showsProgress: true)
            case .disconnected(let message):
                statusView(message, showsProgress: false)
            case .connected:
                if let actionError = store.actionError {
                    Text(actionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if sessionGroups.isEmpty {
                    statusView("No iTerm sessions", showsProgress: false)
                } else {
                    sessionList
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(1)
    }

    private var groupingMenu: some View {
        Menu {
            ForEach(SessionListStyle.allCases) { style in
                Button {
                    settings.setSessionListStyle(style)
                } label: {
                    if settings.sessionListStyle == style {
                        Label(style.title, systemImage: "checkmark")
                    } else {
                        Text(style.title)
                    }
                }
            }
        } label: {
            Image(systemName: "rectangle.3.group")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Group sessions by \(settings.sessionListStyle.title)")
        .accessibilityLabel("Session grouping: \(settings.sessionListStyle.title)")
    }

    private var sessionGroups: [SessionListGroup] {
        SessionGrouping.groups(
            from: store.windows,
            style: settings.sessionListStyle
        )
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(sessionGroups) { group in
                    HStack(spacing: 6) {
                        Image(
                            systemName: settings.sessionListStyle == .window
                                ? "macwindow"
                                : "folder"
                        )
                        Text(group.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                    ForEach(group.sessions) { item in
                        sessionButton(item)
                            .id("\(settings.sessionListStyle.rawValue):\(item.id)")
                    }
                }
            }
        }
    }

    private func sessionButton(_ item: SessionListItem) -> some View {
        Button {
            store.activate(sessionID: item.session.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.isFocused ? "circle.fill" : "circle")
                    .font(.system(size: 8))
                    .foregroundStyle(item.isFocused ? Color.accentColor : .secondary)

                Text(sessionName(item.session))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if item.session.isMinimized == true {
                    Image(systemName: "rectangle.compress.vertical")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                item.isFocused
                    ? Color.accentColor.opacity(0.14)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Activate session \(sessionName(item.session))")
    }

    private func sessionName(_ session: TerminalSessionSnapshot) -> String {
        let name = session.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Session" : name
    }

    private func statusView(_ text: String, showsProgress: Bool) -> some View {
        HStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "exclamationmark.circle")
            }
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct ItermWindow {
    static let bundleIdentifier = "com.googlecode.iterm2"

    let frame: CGRect

    static func frontmost() -> ItermWindow? {
        guard
            let application = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).first,
            let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return nil
        }

        for info in windowInfo {
            guard
                (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == application.processIdentifier,
                (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1 > 0,
                let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                let quartzFrame = CGRect(dictionaryRepresentation: bounds),
                quartzFrame.width > 0,
                quartzFrame.height > 0
            else {
                continue
            }

            return ItermWindow(frame: PanelLayout.appKitFrame(fromQuartzFrame: quartzFrame))
        }

        return nil
    }
}
