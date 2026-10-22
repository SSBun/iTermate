// 离屏渲染真实 PanelContent；附加到移除 @main 的应用入口副本后编译。
// 不创建 AppDelegate、不调用 store.start()、不启动应用或 Bridge。
@main
struct CompactPanelPreview {
    @MainActor
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let configURL = output.appendingPathComponent("preview-config.toml")
        try """
        panel_font_name = "Menlo-Regular"
        panel_font_size = 13
        session_list_style = "projectPath"
        section_title_style = "folderName"
        shows_tab_headers = false
        shows_session_time = true
        panel_background_style = "darkOpaque"
        """.write(to: configURL, atomically: true, encoding: .utf8)
        let settings = AppSettings(configURL: configURL)
        let store = ItermStore()
        func session(_ id: String, _ name: String, _ project: String,
                     _ status: TerminalSessionStatus?, _ kind: SessionAgentKind?,
                     focused: Bool = false, children: Bool = false) -> TerminalSessionSnapshot {
            TerminalSessionSnapshot(
                id: id, name: name, path: "/preview/\(project)", tty: nil,
                windowId: "preview-window", tabId: project,
                isActive: focused, isMinimized: false, status: status,
                activityKind: kind == nil ? .command : .agent,
                exitStatus: status == .finished ? 0 : nil,
                statusChangedAt: Date().timeIntervalSince1970 - 245,
                hasRunningSubagents: children, agentKind: kind
            )
        }
        let tabs = [
            TerminalTabSnapshot(id: "iTermate", title: "iTermate", isSelected: true, sessions: [
                session("a", "修正问题分类误判并验证集成生效情况", "iTermate", .running, .pi, focused: true),
                session("b", "用户关闭 Codex 任务", "iTermate", .awaitingInput, .codex),
                session("c", "iTermate ('zsh (kiro-cli-term)')", "iTermate", nil, nil),
                session("d", "完成 Codex Session 刷新覆盖", "iTermate", .finished, .codex),
                session("e", "任务目标：确认多行 Task Target 格式是否应归类为 question", "iTermate", .awaitingInput, .pi)
            ]),
            TerminalTabSnapshot(id: "MyTwitter", title: "MyTwitter", isSelected: false, sessions: [
                session("f", "验证作者列表", "MyTwitter", .running, .codex, children: true),
                session("g", "检测进度更新", "MyTwitter", .running, .codex),
                session("h", "MyTwitter ('zsh (kiro-cli-term)')", "MyTwitter", nil, nil)
            ]),
            TerminalTabSnapshot(id: "skills", title: "skills", isSelected: false, sessions: [
                session("i", "按功能拆分提交并更新远端分支", "skills", .idle, .pi),
                session("j", "自定义服务标题 (zsh)", "skills", .running, nil)
            ])
        ]
        let payload = try JSONEncoder().encode([TerminalWindowSnapshot(
            id: "preview-window", number: 1, isActive: true, tabs: tabs
        )])
        let windowJSON = String(decoding: payload, as: UTF8.self)
        for json in ["{\"type\":\"hello\"}", "{\"type\":\"snapshot\",\"sequence\":1,\"windows\":\(windowJSON)}"] {
            store.apply(try JSONDecoder().decode(BridgeMessage.self, from: Data(json.utf8)))
        }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        for (label, width, style, headers, light) in [
            ("dark", 460.0, SessionListStyle.projectPath, false, false),
            ("light", 460.0, SessionListStyle.projectPath, false, true),
            ("narrow", 180.0, SessionListStyle.projectPath, false, false),
            ("wide", 600.0, SessionListStyle.projectPath, false, false),
            ("tabs", 320.0, SessionListStyle.projectPath, true, false),
            ("window", 320.0, SessionListStyle.window, true, false)
        ] {
            settings.setSessionListStyle(style)
            settings.setShowsTabHeaders(headers)
            settings.setPanelBackgroundStyle(light ? .lightOpaque : .darkOpaque)
            let view = PanelContent(store: store, settings: settings, archives: store.piArchives)
                .frame(width: width, height: 660)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 660),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent("preview-\(label).png"))
            print("\(label): \(bitmap.pixelsWide)×\(bitmap.pixelsHigh)")
        }
    }
}
