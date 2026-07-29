import AppKit
import CoreGraphics
import SwiftUI

@main
struct ItermateApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(store: appDelegate.store)
        } label: {
            Image("StatusIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .accessibilityLabel("iTermate")
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

        contentView = PanelHostingView(
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

private final class PanelHostingView: NSHostingView<PanelContent> {
    private let resizeEdgeWidth: CGFloat = 8
    private var resizeTrackingAreas: [NSTrackingArea] = []

    override func updateTrackingAreas() {
        resizeTrackingAreas.forEach(removeTrackingArea)
        resizeTrackingAreas.removeAll()
        super.updateTrackingAreas()

        let edgeWidth = min(resizeEdgeWidth, bounds.width / 2)
        guard edgeWidth > 0 else { return }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .enabledDuringMouseDrag
        ]
        let edges = [
            ("left", NSRect(x: 0, y: 0, width: edgeWidth, height: bounds.height)),
            (
                "right",
                NSRect(
                    x: bounds.width - edgeWidth,
                    y: 0,
                    width: edgeWidth,
                    height: bounds.height
                )
            )
        ]

        resizeTrackingAreas = edges.map { edge, rect in
            NSTrackingArea(
                rect: rect,
                options: options,
                owner: self,
                userInfo: ["iTermateResizeEdge": edge]
            )
        }
        resizeTrackingAreas.forEach(addTrackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        if event.trackingArea?.userInfo?["iTermateResizeEdge"] != nil {
            NSCursor.resizeLeftRight.set()
        }
        super.mouseEntered(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        if event.trackingArea?.userInfo?["iTermateResizeEdge"] != nil {
            NSCursor.resizeLeftRight.set()
        }
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        if event.trackingArea?.userInfo?["iTermateResizeEdge"] != nil {
            NSCursor.arrow.set()
        }
        super.mouseExited(with: event)
    }
}

private struct PanelContent: View {
    @ObservedObject var store: ItermStore
    @ObservedObject var settings: AppSettings
    @State private var collapsedSectionIDs: Set<String> = []

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

            Spacer(minLength: 0)

            HStack {
                settingsButton
                Spacer()
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

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .accessibilityLabel("Settings")
        } else {
            Button {
                NSApplication.shared.sendAction(
                    Selector(("showSettingsWindow:")),
                    to: nil,
                    from: nil
                )
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
    }

    private var groupingMenu: some View {
        Menu {
            Section("Group By") {
                Picker(
                    "Group By",
                    selection: Binding(
                        get: { settings.sessionListStyle },
                        set: settings.setSessionListStyle
                    )
                ) {
                    ForEach(SessionListStyle.allCases) { style in
                        Label(style.title, systemImage: style.systemImage)
                            .tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.inline)
            }

            Section("Display") {
                Toggle(
                    isOn: Binding(
                        get: { settings.showsTabHeaders },
                        set: settings.setShowsTabHeaders
                    )
                ) {
                    Label("Show Tab Headers", systemImage: "rectangle.stack")
                }
                .disabled(settings.sessionListStyle != .window)
            }

            Section("Sections") {
                Button {
                    collapsedSectionIDs.subtract(collapsibleSectionIDs)
                } label: {
                    Label("Expand All", systemImage: "chevron.down.2")
                }
                .disabled(collapsedSectionIDs.isDisjoint(with: collapsibleSectionIDs))

                Button {
                    collapsedSectionIDs.formUnion(collapsibleSectionIDs)
                } label: {
                    Label("Collapse All", systemImage: "chevron.right.2")
                }
                .disabled(collapsibleSectionIDs.isSubset(of: collapsedSectionIDs))
            }
        } label: {
            Image(systemName: "rectangle.3.group")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Configure session list")
        .accessibilityLabel("Session list settings")
    }

    private var sessionGroups: [SessionListGroup] {
        SessionGrouping.groups(
            from: store.windows,
            style: settings.sessionListStyle
        )
    }

    private var showsTabHeaders: Bool {
        settings.sessionListStyle == .window && settings.showsTabHeaders
    }

    private var collapsibleSectionIDs: Set<String> {
        var ids = Set(sessionGroups.map(\.id))
        if showsTabHeaders {
            ids.formUnion(
                sessionGroups.flatMap(\.sessions).map { tabSectionID($0.tabID) }
            )
        }
        return ids
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(sessionGroups) { group in
                    groupHeader(group)

                    if !collapsedSectionIDs.contains(group.id) {
                        ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, item in
                            if showsTabHeaders, group.startsTab(at: index) {
                                tabHeader(item)
                            }

                            if !showsTabHeaders || !isTabCollapsed(item.tabID) {
                                sessionButton(item)
                                    .id("\(settings.sessionListStyle.rawValue):\(item.id)")
                                    .padding(.leading, showsTabHeaders ? 12 : 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private func groupHeader(_ group: SessionListGroup) -> some View {
        Button {
            toggleSection(group.id)
        } label: {
            HStack(spacing: 6) {
                disclosureIcon(isCollapsed: collapsedSectionIDs.contains(group.id))
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 10)
        .accessibilityLabel(
            "\(collapsedSectionIDs.contains(group.id) ? "Expand" : "Collapse") \(group.title)"
        )
    }

    private func tabHeader(_ item: SessionListItem) -> some View {
        let sectionID = tabSectionID(item.tabID)
        return Button {
            toggleSection(sectionID)
        } label: {
            HStack(spacing: 6) {
                disclosureIcon(isCollapsed: collapsedSectionIDs.contains(sectionID))
                Image(systemName: "rectangle.stack")
                Text(item.tabTitle)
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .accessibilityLabel(
            "\(collapsedSectionIDs.contains(sectionID) ? "Expand" : "Collapse") \(item.tabTitle)"
        )
    }

    private func disclosureIcon(isCollapsed: Bool) -> some View {
        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
            .font(.caption2)
            .frame(width: 8)
    }

    private func tabSectionID(_ tabID: String) -> String {
        "tab:\(tabID)"
    }

    private func isTabCollapsed(_ tabID: String) -> Bool {
        collapsedSectionIDs.contains(tabSectionID(tabID))
    }

    private func toggleSection(_ sectionID: String) {
        if collapsedSectionIDs.remove(sectionID) == nil {
            collapsedSectionIDs.insert(sectionID)
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

                if let status = item.session.status {
                    switch status {
                    case .running:
                        WorkingStatusIcon()
                    case .finished:
                        Image(
                            systemName: item.session.exitStatus == 0
                                ? "checkmark.circle.fill"
                                : "xmark.circle.fill"
                        )
                        .foregroundStyle(
                            item.session.exitStatus == 0 ? .green : .red
                        )
                        .help(
                            item.session.exitStatus == 0
                                ? "Command finished successfully"
                                : "Command failed"
                        )
                    }
                }

                if item.session.isMinimized == true {
                    Image(systemName: "rectangle.compress.vertical")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
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

private struct WorkingStatusIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFlipping = false

    var body: some View {
        Image(systemName: "hourglass")
            .foregroundStyle(.orange)
            .rotationEffect(.degrees(reduceMotion ? 0 : (isFlipping ? 180 : 0)))
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isFlipping
            )
            .onAppear {
                isFlipping = true
            }
            .help("Command running")
            .accessibilityLabel("Command running")
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
            application.isActive,
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
