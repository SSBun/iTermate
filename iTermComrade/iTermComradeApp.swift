import AppKit
import CoreGraphics
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelFollower: PanelFollower?
    private var statusItem: NSStatusItem?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelFollower = PanelFollower()
        panelFollower?.start()
        installStatusItem()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.trailinghalf.inset.filled",
            accessibilityDescription: "iTermComrade"
        )

        let menu = NSMenu()
        menu.addItem(withTitle: "Quit iTermComrade", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
}

private final class PanelFollower {
    private let panel = ComradePanel()
    private var timer: Timer?

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

        let panelFrame = PanelLayout.frame(for: window.frame, in: screen.visibleFrame)
        panel.setFrame(panelFrame, display: true)

        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }
}

final class ComradePanel: NSPanel {
    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: PanelLayout.width, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        contentView = NSHostingView(rootView: PanelContent())
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
}

private struct PanelContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("iTermComrade", systemImage: "terminal")
                .font(.headline)
            Text("Session list will appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(1)
    }
}

private struct ItermWindow {
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
