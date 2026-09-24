import AppKit
import Carbon
import SwiftUI

/// A recorded physical key plus its modifier flags and readable key label.
struct SessionShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    var isValid: Bool {
        let allowed = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        return keyCode < 128 && modifiers & ~allowed == 0
            && modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
            && !keyLabel.isEmpty && keyLabel.count <= 20
            && !keyLabel.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }

    var displayName: String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + keyLabel
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let special: [UInt16: String] = [
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
            76: "Enter", 115: "Home", 116: "Page Up", 117: "Forward Delete",
            119: "End", 121: "Page Down", 123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        keyCode = UInt32(event.keyCode)
        self.modifiers = modifiers
        keyLabel = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
        guard isValid else { return nil }
    }
}

/// Registers one system-wide hotkey; recording only monitors this App's key events.
@MainActor
final class FinishedSessionShortcut: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var error: String?

    private let settings: AppSettings
    private let onPress: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private static let signature: OSType = 0x49544D46

    init(settings: AppSettings, onPress: @escaping () -> Void) {
        self.settings = settings
        self.onPress = onPress
    }

    func start() {
        guard handler == nil else { return }
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x49544D46, identifier.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            let owner = Unmanaged<FinishedSessionShortcut>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { owner.trigger() }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else {
            error = "Could not initialize global shortcuts (\(status))."
            return
        }
        restoreSavedShortcut()
    }

    func stop() {
        endRecording()
        unregister()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    func beginRecording() {
        guard !isRecording, handler != nil else { return }
        error = nil
        unregister()
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            if event.isARepeat { return nil }
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if event.keyCode == 53 && modifiers.isEmpty {
                self.cancelRecording()
            } else if event.keyCode == 51 && modifiers.isEmpty {
                self.assign(nil)
            } else if let shortcut = SessionShortcut(event: event) {
                self.assign(shortcut)
            } else {
                self.error = "Include Command, Control or Option with a regular key."
            }
            return nil
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.cancelRecording() }
        }
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.cancelRecording() }
        }
    }

    func cancelRecording() {
        guard isRecording else { return }
        endRecording()
        restoreSavedShortcut()
    }

    func clear() {
        assign(nil)
    }

    private func trigger() {
        guard hotKey != nil, !isRecording else { return }
        onPress()
    }

    private func assign(_ shortcut: SessionShortcut?) {
        var candidate: EventHotKeyRef?
        if let shortcut {
            guard shortcut.isValid, handler != nil else { return }
            let result = register(shortcut, reference: &candidate)
            guard result == noErr else {
                error = "This shortcut is unavailable or already in use (\(result)). Choose another combination."
                return
            }
        }
        do {
            // Persist before replacing the active binding so a write failure preserves it.
            try settings.setNextFinishedSessionShortcut(shortcut)
        } catch {
            if let candidate { UnregisterEventHotKey(candidate) }
            self.error = "Could not save the shortcut. The previous setting was preserved."
            return
        }
        unregister()
        hotKey = candidate
        error = nil
        endRecording()
    }

    private func restoreSavedShortcut() {
        guard hotKey == nil, let shortcut = settings.nextFinishedSessionShortcut, handler != nil else { return }
        let result = register(shortcut, reference: &hotKey)
        if result != noErr {
            error = "The saved shortcut could not be registered (\(result)). Choose another combination."
        }
    }

    private func register(_ shortcut: SessionShortcut, reference: inout EventHotKeyRef?) -> OSStatus {
        RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                            EventHotKeyID(signature: Self.signature, id: 1), GetApplicationEventTarget(), 0, &reference)
    }

    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    private func endRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }
        keyMonitor = nil
        resignObserver = nil
        windowObserver = nil
        isRecording = false
    }
}

struct FinishedSessionShortcutSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shortcut: FinishedSessionShortcut

    var body: some View {
        Section("Global Shortcut") {
            HStack {
                Text("Next iTerm2 Agent Session")
                Spacer()
                Button(shortcut.isRecording ? "Press a shortcut…" : settings.nextFinishedSessionShortcut?.displayName ?? "Record Shortcut") {
                    if shortcut.isRecording { shortcut.cancelRecording() }
                    else { shortcut.beginRecording() }
                }
                .help("Include Command, Control or Option. Escape cancels; Delete clears.")
                if settings.nextFinishedSessionShortcut != nil {
                    Button("Clear") { shortcut.clear() }
                }
            }
            if shortcut.isRecording {
                Text("Press a key combination. Escape cancels; Delete clears.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Agent sessions only: waiting for your reply first, then finished (including failures), running, and idle. Cycles in Window / Tab / Session order and skips the current session and ordinary commands. Works from any app.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = shortcut.error {
                Text(error).foregroundStyle(.red)
            }
        }
        .onDisappear { shortcut.cancelRecording() }
    }
}
