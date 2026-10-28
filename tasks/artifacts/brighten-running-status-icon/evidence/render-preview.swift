import AppKit
import SwiftUI
import OSLog
let sessionStatusViewLogger = Logger(subsystem: "preview", category: "status")
enum SessionStatusAnimationStyle { case alien, robot, classic, questionMark }
private enum AgentQuestionStatusView {
    static let glyph = [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b00000, 0b00100]
}
enum SessionStatusAnimation: String, CaseIterable, Identifiable {
    case agentRunning = "agent_running"
    /// An Agent is paused for a user response, not a successful completion.
    case agentAwaitingInput = "agent_awaiting_input"
    case agentSucceeded = "agent_success"
    case agentFailed = "agent_failed"
    case commandRunning = "shell_running"
    case commandSucceeded = "shell_success"
    case commandFailed = "shell_failed"
    case commandFinished = "shell_finished"

    var id: String { rawValue }

    /// Waiting presets do not animate; the question view owns its reminder shake.
    var isAnimated: Bool { self != .agentAwaitingInput }

    static let agentAnimations: [Self] = [
        .agentRunning,
        .agentAwaitingInput,
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
        case .agentAwaitingInput:
            "Waiting for Reply"
        }
    }

    /// Styles offered for this state; the question glyph belongs only to waiting.
    var availableStyles: [SessionStatusAnimationStyle] {
        let presets: [SessionStatusAnimationStyle] = [.alien, .robot, .classic]
        return self == .agentAwaitingInput ? [.questionMark] : presets
    }

    var defaultStyle: SessionStatusAnimationStyle {
        switch self {
        case .agentAwaitingInput:
            .questionMark
        case .agentRunning, .agentSucceeded, .agentFailed:
            .alien
        case .commandRunning, .commandSucceeded, .commandFailed, .commandFinished:
            .robot
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .agentAwaitingInput:
            "Waiting for your reply"
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
        case .agentAwaitingInput:
            .controlAccentColor
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
        let frame = isAnimated ? frame : 0
        if (style ?? defaultStyle) == .questionMark {
            guard (6..<11).contains(column), (0..<7).contains(row) else { return 0 }
            return AgentQuestionStatusView.glyph[row] & (1 << (10 - column)) != 0 ? 1 : 0
        }
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
        case .questionMark:
            return 0 // The question glyph was handled before the status-bar branch.
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
        case .commandFinished, .agentAwaitingInput:
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
        case .agentAwaitingInput:
            return 0
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
        self.animates = animates && animation.isAnimated
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


struct Preview: View {
    func icon() -> some View {
        SessionStatusMatrix(animation: .commandRunning, style: .classic,
                            customColor: .systemPurple, animates: false)
            .frame(width: 36, height: 16)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Before").frame(width: 70, alignment: .leading)
                Button {} label: { icon() }.buttonStyle(.plain).disabled(true)
            }
            HStack { Text("After").frame(width: 70, alignment: .leading); icon() }
        }
        .padding(16)
        .frame(width: 200, height: 100)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: appearance)
    let host = NSHostingView(rootView: Preview().environment(\.colorScheme, name == "dark" ? .dark : .light))
    window.contentView = host
    host.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
    host.display()
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("comparison-\(name).png")
    try rep.representation(using: .png, properties: [:])!.write(to: url)
    print(url.path)
}
