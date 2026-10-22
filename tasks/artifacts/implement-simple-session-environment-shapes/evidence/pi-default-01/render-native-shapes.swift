import SwiftUI
import AppKit
enum SessionAgentKind: String, Codable, Equatable {
    /// A Pi session identified by its integration.
    case pi
    /// A Codex session identified by its reporter.
    case codex
    /// An Agent whose integration has not supplied its identity.
    case unknown

    /// The UI environment name; unidentified Agents default to Pi without changing their recorded identity.
    var displayName: String {
        switch self {
        case .pi, .unknown: "Pi"
        case .codex: "Codex"
        }
    }
}

/// A static pixel identity mark: shape identifies the environment, fill identifies focus.
private struct SessionEnvironmentIcon: View {
    let agentKind: SessionAgentKind?
    let isFocused: Bool
    let color: Color

    private var glyph: [String] {
        switch agentKind {
        case .pi, .unknown:
            isFocused
                ? ["00011000", "00011000", "00111100", "00111100", "01111110", "01111110", "11111111", "11111111"]
                : ["00011000", "00011000", "00100100", "00100100", "01000010", "01000010", "10000001", "11111111"]
        case .codex:
            isFocused
                ? ["1111111", "1111111", "1111111", "1111111", "1111111", "1111111", "1111111"]
                : ["1111111", "1000001", "1000001", "1000001", "1000001", "1000001", "1111111"]
        case nil:
            isFocused
                ? ["00111100", "01111110", "11111111", "11111111", "11111111", "11111111", "01111110", "00111100"]
                : ["00111100", "01000010", "10000001", "10000001", "10000001", "10000001", "01000010", "00111100"]
        }
    }

    private var label: String {
        agentKind?.displayName ?? "Shell"
    }

    var body: some View {
        Canvas { context, size in
            let rows = glyph
            let columns = rows.first?.count ?? 8
            let origin = CGPoint(
                x: (size.width - CGFloat(columns)) / 2,
                y: (size.height - CGFloat(rows.count)) / 2
            )
            for (row, bits) in rows.enumerated() {
                for (column, bit) in bits.enumerated() where bit == "1" {
                    let rect = CGRect(
                        x: origin.x + CGFloat(column),
                        y: origin.y + CGFloat(row),
                        width: 1,
                        height: 1
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: 14, height: 14)
        .help(label)
        .accessibilityLabel(label)
    }
}

@main
struct RenderShapes {
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let kinds: [(String, SessionAgentKind?)] = [("shell", nil), ("pi", .pi), ("codex", .codex), ("unknown", .unknown)]
        for (schemeName, scheme) in [("dark", ColorScheme.dark), ("light", ColorScheme.light)] {
            for (name, kind) in kinds {
                for focused in [false, true] {
                    let content = SessionEnvironmentIcon(
                        agentKind: kind, isFocused: focused,
                        color: focused ? Color(red: 113 / 255, green: 173 / 255, blue: 1) : .secondary
                    ).environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: content)
                    renderer.scale = 8
                    guard let image = renderer.cgImage,
                          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
                    else { throw CocoaError(.fileReadUnknown) }
                    try png.write(to: output.appendingPathComponent("\(schemeName)-\(name)-\(focused ? "focused" : "outline").png"))
                }
            }
        }
    }
}
