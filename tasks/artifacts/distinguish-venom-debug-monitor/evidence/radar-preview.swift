import SwiftUI
import AppKit
private struct VenomDebugStatusView: View {
    let reduceMotion: Bool

    // Clockwise ring on a 7×7 grid, using the existing status glyph's two-point pitch.
    private static let ring = [
        (3, 0), (4, 0), (5, 1), (6, 2), (6, 3), (6, 4), (5, 5), (4, 6),
        (3, 6), (2, 6), (1, 5), (0, 4), (0, 3), (0, 2), (1, 1), (2, 0),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: reduceMotion)) { timeline in
            let frame = Int(timeline.date.timeIntervalSinceReferenceDate / 0.12) % Self.ring.count
            Canvas { context, size in
                let origin = CGPoint(x: (size.width - 14) / 2, y: (size.height - 14) / 2)
                for (index, point) in (Self.ring + [(3, 3)]).enumerated() {
                    let distance = (frame - index + Self.ring.count) % Self.ring.count
                    let opacity: Double = index == Self.ring.count ? 1
                        : (reduceMotion ? 0.7 : (distance < 3 ? [1.0, 0.65, 0.45][distance] : 0.25))
                    let rect = CGRect(
                        x: origin.x + CGFloat(point.0) * 2 + 0.25,
                        y: origin.y + CGFloat(point.1) * 2 + 0.25,
                        width: 1.75,
                        height: 1.75
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 0.35),
                        with: .color(.teal.opacity(opacity))
                    )
                }
            }
        }
    }
}


@main struct Preview {
    @MainActor static func main() throws {
        for (name, scheme, reduced) in [("light", ColorScheme.light, false), ("dark", ColorScheme.dark, false), ("reduced", ColorScheme.dark, true)] {
            let view = VenomDebugStatusView(reduceMotion: reduced).frame(width: 36, height: 16)
                .background(scheme == .light ? Color.white : Color.black)
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 12
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("No rendered pixels") }
            try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("radar-" + name + ".png"))
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}
