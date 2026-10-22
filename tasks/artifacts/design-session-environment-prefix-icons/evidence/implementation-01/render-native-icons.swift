import SwiftUI
import AppKit
enum SessionAgentKind: String, Codable, Equatable {
    /// A Pi session identified by its integration.
    case pi
    /// A Codex session identified by its reporter.
    case codex
    /// An Agent whose integration has not supplied its identity.
    case unknown

    /// The environment name used in tooltips and accessibility descriptions.
    var displayName: String {
        switch self {
        case .pi: "Pi"
        case .codex: "Codex"
        case .unknown: "Agent (identity unavailable)"
        }
    }
}

/// A pixel identity mark; animation does not imply an active Agent turn.
private struct SessionEnvironmentIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let agentKind: SessionAgentKind?

    private var glyph: [String] {
        switch agentKind {
        case .pi:
            ["111111", "010010", "010010", "010010", "110011"]
        case .codex:
            ["0000000", "0010100", "0100010", "1000001", "0100010", "0010100", "0000000"]
        case .unknown:
            ["0011100", "0100010", "1000001", "1000001", "1000001", "0100010", "0011100"]
        case nil:
            ["0000000", "1000000", "0100000", "0010000", "0100000", "1001111", "0000000"]
        }
    }

    private var color: Color {
        switch agentKind {
        case .pi: Color(red: 193 / 255, green: 160 / 255, blue: 245 / 255)
        case .codex: Color(red: 126 / 255, green: 216 / 255, blue: 191 / 255)
        case .unknown: .secondary
        case nil: Color(red: 167 / 255, green: 175 / 255, blue: 186 / 255)
        }
    }

    private var label: String {
        agentKind?.displayName ?? "Shell"
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let rows = glyph
                let columns = rows.first?.count ?? 7
                let origin = CGPoint(
                    x: (size.width - CGFloat(columns) * 2) / 2,
                    y: (size.height - CGFloat(rows.count) * 2) / 2
                )
                let time = timeline.date.timeIntervalSinceReferenceDate
                for (row, bits) in rows.enumerated() {
                    for (column, bit) in bits.enumerated() where bit == "1" {
                        let rect = CGRect(
                            x: origin.x + CGFloat(column) * 2 + 0.25,
                            y: origin.y + CGFloat(row) * 2 + 0.25,
                            width: 1.75,
                            height: 1.75
                        )
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 0.25),
                            with: .color(color.opacity(opacity(row: row, column: column, time: time)))
                        )
                    }
                }
            }
        }
        .frame(width: 14, height: 14)
        .help(label)
        .accessibilityLabel(label)
    }

    private func opacity(row: Int, column: Int, time: TimeInterval) -> Double {
        guard !reduceMotion else { return 0.88 }
        switch agentKind {
        case .pi:
            let sweep = Int(time.truncatingRemainder(dividingBy: 4) / 4 * 6)
            return row == 0 && column == sweep ? 1 : 0.78
        case .codex:
            return (time.truncatingRemainder(dividingBy: 3.2) < 1.6) == (column < 3) ? 1 : 0.62
        case .unknown:
            return time.truncatingRemainder(dividingBy: 3.2) < 1.6 ? 0.88 : 0.62
        case nil:
            guard row == 5 && column >= 3 else { return 0.88 }
            return time.truncatingRemainder(dividingBy: 2.4) < 1.6 ? 1 : 0.36
        }
    }
}

@main
struct RenderIcons {
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let kinds: [(String, SessionAgentKind?)] = [("pi", .pi), ("codex", .codex), ("shell", nil), ("unknown", .unknown)]
        for (name, kind) in kinds {
            let content = SessionEnvironmentIcon(agentKind: kind)
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 8
            guard let image = renderer.cgImage else { throw CocoaError(.fileReadUnknown) }
            let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
            try png.write(to: output.appendingPathComponent(name + "-native.png"))
        }
    }
}
