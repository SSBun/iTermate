import AppKit
import CoreGraphics
import OSLog
import Sparkle
import SwiftUI

private let panelResizeLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.caishilin.iTermate",
    category: "PanelResize"
)
private let sessionStatusViewLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.caishilin.iTermate",
    category: "SessionStatusView"
)

@main
struct ItermateApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(store: appDelegate.store, settings: appDelegate.settings)
        } label: {
            statusBarIcon()
                .renderingMode(.template)
                .accessibilityLabel("iTermate")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                settings: appDelegate.settings,
                updater: appDelegate.updaterController.updater
            )
        }
    }
}

private func statusBarIcon() -> Image {
    guard let image = NSImage(named: "StatusIcon"), image.size.height > 0 else {
        return Image(systemName: "terminal")
    }

    let height: CGFloat = 18
    image.size = NSSize(
        width: height * image.size.width / image.size.height,
        height: height
    )
    return Image(nsImage: image)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let store = ItermStore()
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private var panelFollower: PanelFollower?
    private var notificationController: SessionNotificationController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        AgentIntegrationManager().updateInstalledPiIntegration()
        updaterController.startUpdater()
        panelFollower = PanelFollower(store: store, settings: settings)
        notificationController = SessionNotificationController(
            store: store,
            settings: settings
        )
        panelFollower?.start()
        store.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        store.stop()
    }

    @objc private func workspaceDidWake(_ notification: Notification) {
        store.reconnectAfterWake()
    }
}

private final class PanelFollower {
    private let panel: ComradePanel
    private var timer: Timer?
    private var lastWindowSize: CGSize?
    private var isResizeInProgress = false
    private var lastResizeChangeTime: TimeInterval = 0

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

        guard !panel.inLiveResize, !panel.isManuallyResizing else { return }

        let panelFrame = PanelLayout.frame(
            for: window.frame,
            in: screen.visibleFrame,
            width: panel.settings.panelWidth,
            preferredSide: panel.settings.panelDockingSide
        )
        let now = ProcessInfo.processInfo.systemUptime
        if let lastWindowSize, lastWindowSize != window.frame.size {
            if !isResizeInProgress {
                panelResizeLogger.notice(
                    "iTerm resize began from=\(Int(lastWindowSize.width.rounded()), privacy: .public)x\(Int(lastWindowSize.height.rounded()), privacy: .public) to=\(Int(window.frame.width.rounded()), privacy: .public)x\(Int(window.frame.height.rounded()), privacy: .public)"
                )
            }
            isResizeInProgress = true
            lastResizeChangeTime = now
        } else if isResizeInProgress, now - lastResizeChangeTime > 0.25 {
            let side = if panelFrame.maxX <= window.frame.minX {
                "left"
            } else if panelFrame.minX >= window.frame.maxX {
                "right"
            } else {
                "overlay"
            }
            panelResizeLogger.notice(
                "iTerm resize settled window=\(Int(window.frame.width.rounded()), privacy: .public)x\(Int(window.frame.height.rounded()), privacy: .public) panelOrigin=(\(Int(panelFrame.minX.rounded()), privacy: .public),\(Int(panelFrame.minY.rounded()), privacy: .public)) panel=\(Int(panelFrame.width.rounded()), privacy: .public)x\(Int(panelFrame.height.rounded()), privacy: .public) side=\(side, privacy: .public)"
            )
            isResizeInProgress = false
        }
        lastWindowSize = window.frame.size
        if panel.frame != panelFrame {
            panel.setFrame(panelFrame, display: true)
        }

        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }
}

final class ComradePanel: NSPanel, NSWindowDelegate {
    let settings: AppSettings
    fileprivate var isManuallyResizing = false

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
        acceptsMouseMovedEvents = true
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

    func manuallyResizedFrame(
        from initialFrame: NSRect,
        leftEdge: Bool,
        mouseDeltaX: CGFloat
    ) -> NSRect {
        let proposedWidth = initialFrame.width + (leftEdge ? -mouseDeltaX : mouseDeltaX)
        let width = PanelLayout.clampedWidth(proposedWidth)
        var frame = initialFrame
        frame.size.width = width
        if leftEdge {
            frame.origin.x = initialFrame.maxX - width
        }
        return frame
    }
}

private final class PanelHostingView: NSHostingView<PanelContent> {
    private let resizeEdgeWidth: CGFloat = 8
    private var resizeTrackingAreas: [NSTrackingArea] = []
    private var resizeCursorPushed = false

    deinit {
        popResizeCursor()
    }

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
        super.mouseEntered(with: event)
        if event.trackingArea?.userInfo?["iTermateResizeEdge"] != nil {
            pushResizeCursor()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let location = convert(event.locationInWindow, from: nil)
        if location.x <= resizeEdgeWidth || location.x >= bounds.width - resizeEdgeWidth {
            pushResizeCursor()
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        popResizeCursor()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let leftEdge = location.x <= resizeEdgeWidth
        guard
            leftEdge || location.x >= bounds.width - resizeEdgeWidth,
            let panel = window as? ComradePanel
        else {
            return super.mouseDown(with: event)
        }

        pushResizeCursor()
        let initialFrame = panel.frame
        let initialMouseX = NSEvent.mouseLocation.x
        panel.isManuallyResizing = true
        defer {
            panel.isManuallyResizing = false
            panel.settings.setPanelWidth(panel.frame.width)
        }

        while true {
            guard let nextEvent = panel.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp]
            ) else { break }
            guard nextEvent.type == .leftMouseDragged else { break }
            let frame = panel.manuallyResizedFrame(
                from: initialFrame,
                leftEdge: leftEdge,
                mouseDeltaX: NSEvent.mouseLocation.x - initialMouseX
            )
            panel.setFrame(frame, display: true)
        }
    }

    private func pushResizeCursor() {
        guard !resizeCursorPushed else { return }
        NSCursor.resizeLeftRight.push()
        resizeCursorPushed = true
    }

    private func popResizeCursor() {
        guard resizeCursorPushed else { return }
        NSCursor.pop()
        resizeCursorPushed = false
    }
}

private struct ActiveHoverRegion: NSViewRepresentable {
    let onHover: (Bool) -> Void

    func makeNSView(context: Context) -> ActiveHoverView {
        ActiveHoverView(onHover: onHover)
    }

    func updateNSView(_ view: ActiveHoverView, context: Context) {
        view.onHover = onHover
    }
}

private final class ActiveHoverView: NSView {
    var onHover: (Bool) -> Void
    private var hoverTrackingArea: NSTrackingArea?

    init(onHover: @escaping (Bool) -> Void) {
        self.onHover = onHover
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        super.updateTrackingAreas()

        let hoverTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(hoverTrackingArea)
        self.hoverTrackingArea = hoverTrackingArea
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func mouseEntered(with event: NSEvent) {
        onHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover(false)
    }
}

private struct PanelContent: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @ObservedObject var store: ItermStore
    @ObservedObject var settings: AppSettings
    @State private var collapsedSectionIDs: Set<String> = []
    @State private var hoveredSessionID: String?
    @State private var hoveredCloseButtonSessionID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text("iTermate")
                } icon: {
                    statusBarIcon()
                        .renderingMode(.template)
                }
                .font(panelFont(1.2))
                Spacer()
                Button {
                    store.resetSessionStatuses()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset all session statuses")
                .accessibilityLabel("Reset all session statuses")
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
                        .font(panelFont(0.85))
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
        .font(panelFont())
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            panelBackground
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        }
        .overlay {
            ActiveHoverRegion { isHovered in
                if !isHovered {
                    hoveredSessionID = nil
                    hoveredCloseButtonSessionID = nil
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(1)
        .tint(settings.accentColor)
        .environment(\.colorScheme, effectiveColorScheme)
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            OpenSettingsButton {
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
            style: settings.sessionListStyle,
            pinnedProjectPaths: settings.pinnedProjectFolderPaths
        )
    }

    private var showsTabHeaders: Bool {
        settings.showsTabHeaders
    }

    private var collapsibleSectionIDs: Set<String> {
        var ids = Set(sessionGroups.map(\.id))
        if showsTabHeaders {
            ids.formUnion(
                sessionGroups.flatMap { group in
                    group.sessions
                        .filter { tabHeaderSessions(group, tabID: $0.tabID) != nil }
                        .map { tabSectionID($0.tabID) }
                }
            )
        }
        return ids
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(sessionGroups) { group in
                    let containsFocusedSession = settings.sessionListStyle == .projectPath
                        && group.sessions.contains(where: \.isFocused)
                    VStack(alignment: .leading, spacing: 2) {
                        groupHeader(group)

                        if !collapsedSectionIDs.contains(group.id) {
                            ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, item in
                                let hasTabHeader = tabHeaderSessions(group, tabID: item.tabID) != nil
                                if hasTabHeader, group.startsTab(at: index) {
                                    tabHeader(
                                        item,
                                        sessions: group.sessions(inTab: item.tabID)
                                    )
                                }

                                if !hasTabHeader || !isTabCollapsed(item.tabID) {
                                    sessionButton(item)
                                        .id(
                                            "\(settings.sessionListStyle.rawValue):\(item.id):\(item.session.name):\(item.isFocused):\(item.session.status?.rawValue ?? "idle"):\(item.session.activityKind?.rawValue ?? "none"):\(item.session.exitStatus ?? -1)"
                                        )
                                        .padding(.leading, hasTabHeader ? 12 : 0)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if containsFocusedSession {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(settings.accentColor.opacity(0.05))
                        }
                    }
                }
            }
        }
    }

    /// Sessions of one tab when its header should render.
    private func tabHeaderSessions(
        _ group: SessionListGroup,
        tabID: String
    ) -> [SessionListItem]? {
        guard showsTabHeaders else { return nil }
        return group.sessions(inTab: tabID)
    }

    private func sectionTitle(for group: SessionListGroup) -> String {
        guard settings.sessionListStyle == .projectPath else { return group.title }
        return settings.sectionTitleStyle.title(for: group.title)
    }

    private func groupHeader(_ group: SessionListGroup) -> some View {
        let title = sectionTitle(for: group)
        let isProjectFolder = settings.sessionListStyle == .projectPath
            && group.id != "path:"
        let customization = isProjectFolder
            ? settings.projectFolderCustomization(at: group.title)
            : ProjectFolderCustomization()
        let projectColor = isProjectFolder
            ? settings.projectFolderColor(at: group.title)
            : nil
        let headerColor: Color = projectColor ?? .secondary
        return Button {
            toggleSection(group.id)
        } label: {
            HStack(spacing: 6) {
                disclosureIcon(isCollapsed: collapsedSectionIDs.contains(group.id))
                Image(systemName: isProjectFolder ? "folder" : "macwindow")
                    .foregroundStyle(headerColor)
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(headerColor)
                if customization.isPinned {
                    Image(systemName: "pin.fill")
                        .accessibilityHidden(true)
                }
                if customization.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .font(headerFont())
        .foregroundStyle(.secondary)
        .padding(.top, 5)
        .accessibilityLabel(
            "\(collapsedSectionIDs.contains(group.id) ? "Expand" : "Collapse") \(title)"
                + (customization.isPinned ? ", pinned" : "")
                + (customization.isFavorite ? ", favorite" : "")
        )
        .contextMenu {
            if isProjectFolder {
                projectFolderActions(for: group.title)
                Divider()
            }
            closeAllSessionsButton(for: group.sessions)
        }
    }

    /// Project Path style shows "Tab N" (position in its window) instead of
    /// the tab's dynamic title, which usually repeats the project path.
    private func tabSubgroupTitle(for item: SessionListItem) -> String {
        guard settings.sessionListStyle == .projectPath else { return item.tabTitle }
        for window in store.windows {
            if let index = window.tabs.firstIndex(where: { $0.id == item.tabID }) {
                return "Tab \(index + 1)"
            }
        }
        return item.tabTitle
    }

    private func tabHeader(
        _ item: SessionListItem,
        sessions: [SessionListItem]
    ) -> some View {
        let sectionID = tabSectionID(item.tabID)
        let title = tabSubgroupTitle(for: item)
        return Button {
            toggleSection(sectionID)
        } label: {
            HStack(spacing: 6) {
                disclosureIcon(isCollapsed: collapsedSectionIDs.contains(sectionID))
                Image(systemName: "rectangle.stack")
                Text(title)
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(headerFont())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.leading, settings.sessionListStyle == .projectPath ? 12 : 0)
        .padding(.top, 10)
        .accessibilityLabel(
            "\(collapsedSectionIDs.contains(sectionID) ? "Expand" : "Collapse") \(title)"
        )
        .contextMenu {
            closeAllSessionsButton(for: sessions)
        }
    }

    @ViewBuilder
    private func projectFolderActions(for path: String) -> some View {
        let customization = settings.projectFolderCustomization(at: path)

        Button {
            settings.togglePinnedProjectFolder(at: path)
        } label: {
            Label(
                customization.isPinned ? "Unpin" : "Pin",
                systemImage: customization.isPinned ? "pin.slash" : "pin"
            )
        }

        Button {
            settings.toggleFavoriteProjectFolder(at: path)
        } label: {
            Label(
                customization.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: customization.isFavorite ? "star.slash" : "star"
            )
        }

        ColorPicker(
            selection: Binding(
                get: { settings.projectFolderColor(at: path) ?? settings.accentColor },
                set: { settings.setProjectFolderColor(NSColor($0), at: path) }
            ),
            supportsOpacity: false
        ) {
            Label("Custom Color…", systemImage: "paintpalette")
        }

        if customization.colorHex != nil {
            Button {
                settings.setProjectFolderColor(nil, at: path)
            } label: {
                Label("Clear Color", systemImage: "xmark.circle")
            }
        }
    }

    private func closeAllSessionsButton(
        for sessions: [SessionListItem]
    ) -> some View {
        Button(role: .destructive) {
            sessions.forEach { store.close(sessionID: $0.session.id) }
        } label: {
            Label("Close All Sessions", systemImage: "trash")
        }
    }

    private func disclosureIcon(isCollapsed: Bool) -> some View {
        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
            .font(panelFont(0.7))
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
        HStack(spacing: 0) {
            Button {
                store.activate(sessionID: item.session.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: item.isFocused ? "circle.fill" : "circle")
                        .font(.system(size: 8))
                        .foregroundStyle(
                            item.isFocused ? settings.accentColor : .secondary
                        )

                    Text(sessionName(item.session))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if
                        item.session.status == .idle,
                        item.session.activityKind == .agent
                    {
                        AgentIdleStatusView()
                    } else if
                        let status = item.session.status,
                        let animation = SessionStatusAnimation(session: item.session)
                    {
                        HStack(spacing: 4) {
                            SessionStatusMatrix(
                                animation: animation,
                                style: settings.statusAnimationStyle(for: animation),
                                customColor: settings.statusAnimationCustomColor(
                                    for: animation
                                ).map { NSColor($0) }
                            )
                                .frame(width: 36, height: 16)
                                .help(animation.accessibilityLabel)
                                .accessibilityLabel(animation.accessibilityLabel)
                                .accessibilityHidden(settings.showsSessionTime)

                            if settings.showsSessionTime {
                                TimelineView(
                                    .periodic(
                                        from: .now,
                                        by: settings.sessionTimeFormat.refreshInterval
                                    )
                                ) { context in
                                    Text(
                                        status.label(
                                            changedAt: item.session.statusChangedAt,
                                            now: context.date,
                                            format: settings.sessionTimeFormat
                                        )
                                    )
                                    .font(panelFont(0.85))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }

                    if item.session.isMinimized == true {
                        Image(systemName: "rectangle.compress.vertical")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .padding(.leading, 8)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Activate session \(sessionName(item.session))")

            Button {
                store.close(sessionID: item.session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(panelFont(0.85))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 30)
                    .background {
                        if hoveredCloseButtonSessionID == item.id {
                            Circle()
                                .fill(Color.secondary.opacity(0.18))
                                .frame(width: 22, height: 22)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hoveredSessionID == item.id ? 1 : 0)
            .allowsHitTesting(hoveredSessionID == item.id)
            .help("Close session")
            .accessibilityLabel("Close session \(sessionName(item.session))")
            .overlay {
                ActiveHoverRegion { isHovered in
                    if isHovered {
                        hoveredCloseButtonSessionID = item.id
                    } else if hoveredCloseButtonSessionID == item.id {
                        hoveredCloseButtonSessionID = nil
                    }
                }
            }
        }
        .padding(.trailing, 4)
        .background(
            item.isFocused
                ? settings.accentColor.opacity(0.14)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            ActiveHoverRegion { isHovered in
                if isHovered {
                    hoveredSessionID = item.id
                } else if hoveredSessionID == item.id {
                    hoveredSessionID = nil
                    hoveredCloseButtonSessionID = nil
                }
            }
        }
    }

    private func sessionName(_ session: TerminalSessionSnapshot) -> String {
        let name = session.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Session" : name
    }

    @ViewBuilder
    private var panelBackground: some View {
        if settings.panelBackgroundStyle.usesBlur {
            Rectangle().fill(.regularMaterial)
        } else {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private var effectiveColorScheme: ColorScheme {
        settings.panelBackgroundStyle.colorScheme ?? systemColorScheme
    }

    private func panelFont(_ scale: CGFloat = 1) -> Font {
        let font = settings.panelFont
        return Font(font.withSize(font.pointSize * scale))
    }

    /// Header variant of the panel font with a bold trait so section titles
    /// stand out from session rows regardless of the selected typeface.
    private func headerFont(_ scale: CGFloat = 0.85) -> Font {
        let font = settings.panelFont
        let sized = font.withSize(font.pointSize * scale)
        let bold = NSFontManager.shared.convert(sized, toHaveTrait: .boldFontMask)
        return Font(bold)
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
                .font(panelFont())
                .foregroundStyle(.secondary)
        }
    }
}

enum SessionStatusAnimation: String, CaseIterable, Identifiable {
    case agentRunning = "agent_running"
    case agentSucceeded = "agent_success"
    case agentFailed = "agent_failed"
    case commandRunning = "shell_running"
    case commandSucceeded = "shell_success"
    case commandFailed = "shell_failed"
    case commandFinished = "shell_finished"

    var id: String { rawValue }

    static let agentAnimations: [Self] = [
        .agentRunning,
        .agentSucceeded,
        .agentFailed
    ]
    static let shellAnimations: [Self] = [
        .commandRunning,
        .commandSucceeded,
        .commandFailed,
        .commandFinished
    ]

    var settingsTitle: String {
        switch self {
        case .agentRunning, .commandRunning:
            "Running"
        case .agentSucceeded, .commandSucceeded:
            "Success"
        case .agentFailed, .commandFailed:
            "Failed"
        case .commandFinished:
            "Finished"
        }
    }

    var defaultStyle: SessionStatusAnimationStyle {
        switch self {
        case .agentRunning, .agentSucceeded, .agentFailed:
            .alien
        case .commandRunning, .commandSucceeded, .commandFailed, .commandFinished:
            .robot
        }
    }

    init?(session: TerminalSessionSnapshot) {
        guard let status = session.status else { return nil }

        let kind = session.activityKind ?? .command
        switch (kind, status, session.exitStatus) {
        case (_, .idle, _):
            return nil
        case (.agent, .running, _):
            self = .agentRunning
        case (.command, .running, _):
            self = .commandRunning
        case (_, .finished, nil):
            self = .commandFinished
        case (.agent, .finished, .some(0)):
            self = .agentSucceeded
        case (.agent, .finished, .some):
            self = .agentFailed
        case (.command, .finished, .some(0)):
            self = .commandSucceeded
        case (.command, .finished, .some):
            self = .commandFailed
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .agentRunning:
            "Agent working"
        case .agentSucceeded:
            "Agent finished successfully"
        case .agentFailed:
            "Agent failed"
        case .commandRunning:
            "Command running"
        case .commandSucceeded:
            "Command finished successfully"
        case .commandFailed:
            "Command failed"
        case .commandFinished:
            "Command finished"
        }
    }

    var color: NSColor {
        switch self {
        case .agentRunning:
            .systemPurple
        case .commandRunning:
            .systemOrange
        case .agentSucceeded, .commandSucceeded:
            .systemGreen
        case .agentFailed, .commandFailed:
            .systemRed
        case .commandFinished:
            .systemBlue
        }
    }

    func pixelColor(
        brightness: CGFloat,
        customColor: NSColor? = nil
    ) -> NSColor {
        let brightness = min(max(brightness, 0), 1)
        let highlightFraction = 0.1 + brightness * 0.3
        let baseColor = customColor ?? color
        return (
            baseColor.blended(withFraction: highlightFraction, of: .white) ?? baseColor
        ).withAlphaComponent(1)
    }

    func brightness(
        column: Int,
        row: Int,
        frame: Int,
        style: SessionStatusAnimationStyle? = nil
    ) -> CGFloat {
        if (14...15).contains(column) {
            return statusBarBrightness(row: row, frame: frame)
        }

        switch style ?? defaultStyle {
        case .alien:
            return alienBrightness(column: column, row: row, frame: frame)
        case .robot:
            return robotBrightness(column: column, row: row, frame: frame)
        case .classic:
            return classicBrightness(column: column, row: row, frame: frame)
        }
    }

    private enum StatusPhase {
        case running
        case succeeded
        case failed
        case finished
    }

    private var statusPhase: StatusPhase {
        switch self {
        case .agentRunning, .commandRunning:
            .running
        case .agentSucceeded, .commandSucceeded:
            .succeeded
        case .agentFailed, .commandFailed:
            .failed
        case .commandFinished:
            .finished
        }
    }

    private func alienBrightness(
        column: Int,
        row: Int,
        frame: Int
    ) -> CGFloat {
        guard (0...10).contains(column) else { return 0 }

        let animationPhase = frame / 4 % 4
        let verticalOffset: Int
        switch statusPhase {
        case .succeeded:
            verticalOffset = [1, 0, 0, 1][animationPhase]
        case .failed:
            verticalOffset = [1, 2, 2, 1][animationPhase]
        case .running, .finished:
            verticalOffset = 1
        }

        let sourceRow = row - verticalOffset
        var sourceColumn = column
        if statusPhase == .failed {
            let direction = sourceRow.isMultiple(of: 2) ? 1 : -1
            sourceColumn -= [0, 1, -1, 0][animationPhase] * direction
        }

        let gaze = statusPhase == .running
            ? [-1, 0, 1, 0][animationPhase]
            : 0
        guard Self.isAlienPixel(
            column: sourceColumn,
            row: sourceRow,
            gaze: gaze
        ) else {
            return 0
        }

        switch statusPhase {
        case .running:
            return [0.55, 0.7, 1, 0.7][(animationPhase + sourceRow) % 4]
        case .succeeded:
            return sourceRow == frame / 2 % 7 ? 1 : 0.65
        case .failed:
            return (sourceColumn + sourceRow + frame / 2) % 5 == 0 ? 1 : 0.55
        case .finished:
            let pulse: [CGFloat] = [0.45, 0.6, 0.8, 1, 0.8, 0.6]
            return pulse[frame / 2 % pulse.count]
        }
    }

    private func robotBrightness(
        column: Int,
        row: Int,
        frame: Int
    ) -> CGFloat {
        guard (0...10).contains(column) else { return 0 }

        let animationPhase = frame / 4 % 4
        let verticalOffset = statusPhase == .succeeded
            ? [1, 2, 1, 1][animationPhase]
            : 1
        let horizontalOffset = statusPhase == .failed
            ? [-1, 0, 1, 0][animationPhase]
            : 0
        let sourceColumn = column - horizontalOffset
        let sourceRow = row - verticalOffset
        guard Self.isRobotPixel(column: sourceColumn, row: sourceRow) else {
            return 0
        }

        let isEye = sourceRow == 3 && (sourceColumn == 4 || sourceColumn == 6)
        switch statusPhase {
        case .running where isEye:
            let activeEye = animationPhase.isMultiple(of: 2) ? 4 : 6
            return sourceColumn == activeEye ? 1 : 0.45
        case .succeeded:
            return sourceRow == 5 && (4...6).contains(sourceColumn) ? 1 : 0.65
        case .failed:
            return (sourceColumn + sourceRow + frame / 2) % 5 == 0 ? 1 : 0.55
        case .finished where isEye:
            return animationPhase == 2 ? 0 : 0.9
        default:
            return 0.65
        }
    }

    private enum ClassicGlyph: Equatable {
        case caret
        case underscore
        case x
    }

    private func classicBrightness(
        column: Int,
        row: Int,
        frame: Int
    ) -> CGFloat {
        guard (0...10).contains(column) else { return 0 }

        let glyphs: [ClassicGlyph] = switch statusPhase {
        case .running:
            [.caret, .underscore]
        case .succeeded, .finished:
            [.caret, .underscore, .caret]
        case .failed:
            [.x, .underscore, .x]
        }
        let width = glyphs.count * 3 + glyphs.count - 1
        let position = column - (11 - width) / 2
        guard position >= 0 else { return 0 }

        let glyphIndex = position / 4
        let glyphColumn = position % 4
        guard
            glyphs.indices.contains(glyphIndex),
            glyphColumn < 3,
            Self.isClassicPixel(
                glyphs[glyphIndex],
                column: glyphColumn,
                row: row
            )
        else {
            return 0
        }

        switch statusPhase {
        case .running:
            guard glyphs[glyphIndex] == .underscore else { return 0.7 }
            return (frame / 6).isMultiple(of: 2) ? 1 : 0.2
        case .succeeded, .finished:
            let pulse: [CGFloat] = [0.55, 0.7, 0.85, 1, 0.85, 0.7]
            return pulse[frame / 3 % pulse.count]
        case .failed:
            return (frame / 4).isMultiple(of: 2) ? 1 : 0.3
        }
    }

    private static func isClassicPixel(
        _ glyph: ClassicGlyph,
        column: Int,
        row: Int
    ) -> Bool {
        switch glyph {
        case .caret:
            (row == 2 && column == 1)
                || (row == 3 && (column == 0 || column == 2))
        case .underscore:
            row == 5
        case .x:
            (row == 2 && (column == 0 || column == 2))
                || (row == 3 && column == 1)
                || (row == 4 && (column == 0 || column == 2))
        }
    }

    private func statusBarBrightness(row: Int, frame: Int) -> CGFloat {
        guard (1...6).contains(row) else { return 0 }

        let level = row - 1
        switch self {
        case .agentRunning:
            return level == frame / 2 % 6 ? 1 : 0.35
        case .commandRunning:
            let filledLevels = frame / 3 % 6 + 1
            guard level >= 6 - filledLevels else { return 0 }
            return level == 6 - filledLevels ? 1 : 0.55
        case .agentSucceeded, .commandSucceeded:
            return level == frame / 2 % 6 ? 1 : 0.55
        case .agentFailed:
            return (level + frame / 3) % 3 == 0 ? 1 : 0
        case .commandFailed:
            return (level + frame / 2) % 2 == 0 ? 0.85 : 0
        case .commandFinished:
            let pulse: [CGFloat] = [0.35, 0.5, 0.7, 0.9, 1, 0.9, 0.7, 0.5]
            return pulse[frame / 2 % pulse.count]
        }
    }

    private static func isAlienPixel(
        column: Int,
        row: Int,
        gaze: Int
    ) -> Bool {
        switch row {
        case 0:
            column == 2 || column == 8
        case 1:
            column == 3 || column == 7
        case 2:
            (2...8).contains(column)
        case 3:
            (1...9).contains(column)
                && column != 3 + gaze
                && column != 7 + gaze
        case 4:
            (0...10).contains(column)
        case 5:
            [0, 2, 4, 5, 6, 8, 10].contains(column)
        case 6:
            [3, 4, 6, 7].contains(column)
        default:
            false
        }
    }

    private static func isRobotPixel(column: Int, row: Int) -> Bool {
        switch row {
        case 0:
            (4...6).contains(column)
        case 1:
            column == 5
        case 2:
            (1...9).contains(column)
        case 3:
            [0, 1, 4, 6, 9, 10].contains(column)
        case 4:
            [0, 1, 5, 9, 10].contains(column)
        case 5:
            column == 1 || (3...7).contains(column) || column == 9
        case 6:
            (2...8).contains(column)
        default:
            false
        }
    }
}

private struct AgentIdleStatusView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        SessionStatusMatrix(
            animation: .agentRunning,
            style: .alien,
            customColor: .secondaryLabelColor,
            animates: false
        )
        .frame(width: 36, height: 16)
        .opacity(isVisible ? 0.3 : 0)
        .help("Agent idle — waiting for input")
        .accessibilityLabel("Agent idle — waiting for input")
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = true
                }
            }
        }
    }
}

struct SessionStatusMatrix: NSViewRepresentable {
    let animation: SessionStatusAnimation
    let style: SessionStatusAnimationStyle
    let customColor: NSColor?
    let animates: Bool

    init(
        animation: SessionStatusAnimation,
        style: SessionStatusAnimationStyle,
        customColor: NSColor?,
        animates: Bool = true
    ) {
        self.animation = animation
        self.style = style
        self.customColor = customColor
        self.animates = animates
    }

    func makeNSView(context: Context) -> SessionStatusMatrixView {
        SessionStatusMatrixView(
            animation: animation,
            style: style,
            customColor: customColor,
            animates: animates
        )
    }

    func updateNSView(_ view: SessionStatusMatrixView, context: Context) {
        view.update(
            animation: animation,
            style: style,
            customColor: customColor,
            animates: animates
        )
    }

    static func dismantleNSView(
        _ view: SessionStatusMatrixView,
        coordinator: Void
    ) {
        view.stopAnimating()
    }
}

final class SessionStatusMatrixView: NSView {
    private static let columns = 18
    private static let rows = 8
    private static let pixelPitch: CGFloat = 2
    private static let pixelSize: CGFloat = 1.75
    private static let animationInterval: TimeInterval = 1.0 / 20.0

    private(set) var animation: SessionStatusAnimation {
        didSet {
            guard animation != oldValue else { return }
            frameIndex = 0
            needsDisplay = true
        }
    }
    private(set) var style: SessionStatusAnimationStyle
    private(set) var customColor: NSColor?
    private(set) var animates: Bool

    private var frameIndex = 0
    private var timer: Timer?
    private var accessibilityObserver: NSObjectProtocol?

    init(
        animation: SessionStatusAnimation,
        style: SessionStatusAnimationStyle,
        customColor: NSColor?,
        animates: Bool
    ) {
        self.animation = animation
        self.style = style
        self.customColor = customColor
        self.animates = animates
        super.init(frame: .zero)
        let animationName = String(describing: animation)
        sessionStatusViewLogger.notice(
            "Status matrix created animation=\(animationName, privacy: .public)"
        )
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAnimationTimer()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        animation: SessionStatusAnimation,
        style: SessionStatusAnimationStyle,
        customColor: NSColor?,
        animates: Bool
    ) {
        if self.animation != animation {
            let oldAnimationName = String(describing: self.animation)
            let newAnimationName = String(describing: animation)
            sessionStatusViewLogger.notice(
                "Status matrix animation changed from=\(oldAnimationName, privacy: .public) to=\(newAnimationName, privacy: .public)"
            )
        }
        let animationBehaviorChanged = self.animates != animates
        if self.style != style || animationBehaviorChanged {
            frameIndex = 0
        }
        self.animation = animation
        self.style = style
        self.customColor = customColor
        self.animates = animates
        needsDisplay = true
        if animationBehaviorChanged {
            updateAnimationTimer()
        }
    }

    deinit {
        if let accessibilityObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(
                accessibilityObserver
            )
        }
        timer?.invalidate()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 36, height: 16)
    }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAnimationTimer()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for row in 0..<Self.rows {
            for column in 0..<Self.columns {
                let brightness = animation.brightness(
                    column: column,
                    row: row,
                    frame: frameIndex,
                    style: style
                )
                guard brightness > 0 else { continue }
                animation.pixelColor(
                    brightness: brightness,
                    customColor: customColor
                ).setFill()
                NSBezierPath(
                    roundedRect: NSRect(
                        x: CGFloat(column) * Self.pixelPitch + 0.25,
                        y: CGFloat(row) * Self.pixelPitch + 0.25,
                        width: Self.pixelSize,
                        height: Self.pixelSize
                    ),
                    xRadius: 0.35,
                    yRadius: 0.35
                ).fill()
            }
        }
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }

    private func updateAnimationTimer() {
        guard
            animates,
            window != nil,
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else {
            stopAnimating()
            frameIndex = 0
            needsDisplay = true
            return
        }
        guard timer == nil else { return }

        let timer = Timer(
            timeInterval: Self.animationInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            frameIndex = (frameIndex + 1) % 240
            needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
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

        let candidateFrames = windowInfo.compactMap { info -> CGRect? in
            guard
                (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == application.processIdentifier,
                (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1 > 0,
                let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                let quartzFrame = CGRect(dictionaryRepresentation: bounds),
                quartzFrame.width > 0,
                quartzFrame.height > 0
            else {
                return nil
            }
            return quartzFrame
        }

        // ponytail: the largest layer-0 window excludes iTerm modal alerts; use window IDs if multi-window precision is needed.
        guard let quartzFrame = largestWindowFrame(from: candidateFrames) else {
            return nil
        }
        return ItermWindow(frame: PanelLayout.appKitFrame(fromQuartzFrame: quartzFrame))
    }

    static func largestWindowFrame(from frames: [CGRect]) -> CGRect? {
        frames.max { first, second in
            first.width * first.height < second.width * second.height
        }
    }
}
