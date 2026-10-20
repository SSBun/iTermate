import AppKit
import SwiftUI
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
private struct SessionIconAnchors: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(
        value: inout [String: Anchor<CGRect>],
        nextValue: () -> [String: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct SessionGroupConnectors: View {
    let sessionIDs: [String]
    let anchors: [String: Anchor<CGRect>]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                for (upperID, lowerID) in zip(sessionIDs, sessionIDs.dropFirst()) {
                    guard let upperAnchor = anchors[upperID],
                          let lowerAnchor = anchors[lowerID] else { continue }
                    let upper = geometry[upperAnchor]
                    let lower = geometry[lowerAnchor]
                    guard lower.minY > upper.maxY else { continue }
                    let segment = CGRect(
                        x: upper.midX - 0.5,
                        y: upper.maxY,
                        width: 1,
                        height: lower.minY - upper.maxY
                    )
                    context.fill(Path(segment), with: .color(.secondary.opacity(0.45)))
                }
            }
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


struct PreviewSession: Identifiable {
    let id: String
    let title: String
    let agent: SessionAgentKind?
    let fontSize: CGFloat
    let focused: Bool
}

struct ConnectorPreview: View {
    let scheme: ColorScheme

    private let rows = [
        PreviewSession(id: "one", title: "推送容器冗余判断清理变更", agent: .pi, fontSize: 13, focused: false),
        PreviewSession(id: "two", title: "核查双端点赞数显示差异", agent: .pi, fontSize: 19, focused: true),
        PreviewSession(id: "three", title: "native-short-reader", agent: .pi, fontSize: 13, focused: false)
    ]

    private func row(_ item: PreviewSession) -> some View {
        HStack(spacing: 8) {
            SessionEnvironmentIcon(agentKind: item.agent, isFocused: item.focused, color: item.focused ? .blue : .secondary)
                .anchorPreference(key: SessionIconAnchors.self, value: .bounds) { [item.id: $0] }
            Text(item.title).font(.system(size: item.fontSize)).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .padding(.vertical, item.agent == nil ? 5 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.focused ? Color.blue.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func group(_ title: String, rows: [PreviewSession], indented: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !title.isEmpty {
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 5)
            }
            ForEach(rows) { row($0).padding(.leading, indented ? 12 : 0) }
        }
        .overlayPreferenceValue(SessionIconAnchors.self) { anchors in
            if rows.count > 1 {
                SessionGroupConnectors(sessionIDs: rows.map(\.id), anchors: anchors)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(scheme == .dark ? "深色 · 图标间连线" : "浅色 · 图标间连线").font(.headline).padding(.bottom, 12)
            Text("native-short-reader · 同一 Tab / 混合行高").font(.system(size: 11)).foregroundStyle(.secondary)
            group("", rows: rows)
            group("Tab 2 · 标题开启并缩进", rows: [
                PreviewSession(id: "four", title: "Codex 会话", agent: .codex, fontSize: 13, focused: false),
                PreviewSession(id: "five", title: "Shell 会话", agent: nil, fontSize: 13, focused: false)
            ], indented: true)
            group("另一个项目 · 单会话不连线", rows: [
                PreviewSession(id: "six", title: "MyWiki", agent: nil, fontSize: 13, focused: false)
            ])
            group("已折叠 Tab · 无会话，无连接线", rows: [])
        }
        .padding(18)
        .frame(width: 420)
        .background(scheme == .dark ? Color(white: 0.12) : Color(white: 0.96))
        .environment(\.colorScheme, scheme)
        .foregroundStyle(scheme == .dark ? Color.white : Color.black)
    }
}

@MainActor
func renderPreview() throws {
    let content = HStack(alignment: .top, spacing: 12) {
        ConnectorPreview(scheme: .dark)
        ConnectorPreview(scheme: .light)
    }.padding(12).background(Color.gray.opacity(0.3))
    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ConnectorPreview", code: 1)
    }
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("已生成离屏预览：\(bitmap.pixelsWide)×\(bitmap.pixelsHigh)")
}
try await renderPreview()
