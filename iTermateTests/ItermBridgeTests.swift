import XCTest
@testable import iTermate

final class ItermBridgeTests: XCTestCase {
    func testDecodesSnapshotHierarchy() throws {
        let data = Data(
            """
            {
              "type": "snapshot",
              "sequence": 7,
              "windows": [{
                "id": "window-1",
                "number": 1,
                "isActive": true,
                "tabs": [{
                  "id": "tab-1",
                  "title": "Development",
                  "isSelected": true,
                  "sessions": [{
                    "id": "session-1",
                    "name": "zsh",
                    "path": "/Users/example/project",
                    "windowId": "window-1",
                    "tabId": "tab-1",
                    "isActive": true,
                    "isMinimized": false,
                    "status": "finished",
                    "activityKind": "agent",
                    "exitStatus": 0,
                    "statusChangedAt": 1753833600
                  }]
                }]
              }]
            }
            """.utf8
        )

        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        XCTAssertEqual(message.sequence, 7)
        XCTAssertEqual(message.windows?.first?.tabs.first?.title, "Development")
        XCTAssertEqual(message.windows?.first?.tabs.first?.sessions.count, 1)
        XCTAssertEqual(
            message.windows?.first?.tabs.first?.sessions.first?.path,
            "/Users/example/project"
        )
        XCTAssertEqual(
            message.windows?.first?.tabs.first?.sessions.first?.tabId,
            "tab-1"
        )
        XCTAssertEqual(
            message.windows?.first?.tabs.first?.sessions.first?.status,
            .finished
        )
        XCTAssertEqual(
            message.windows?.first?.tabs.first?.sessions.first?.activityKind,
            .agent
        )
        XCTAssertEqual(
            message.windows?.first?.tabs.first?.sessions.first?.exitStatus,
            0
        )
        XCTAssertEqual(
            message.windows?.first?.tabs.first?.sessions.first?.statusChangedAt,
            1_753_833_600
        )
    }

    func testGhosttyStatusRegistryOrdersEventsAndPrioritizesAgents() {
        var registry = TerminalStatusRegistry()
        let tty = "/dev/ttys001"
        XCTAssertFalse(
            registry.apply(
                TerminalStatusReport(
                    tty: tty,
                    source: .command,
                    reporterID: "shell",
                    sequence: 1,
                    state: .running,
                    exitStatus: nil,
                    heartbeat: false
                )
            )
        )
        registry.reconcile(terminals: [tty: "terminal"])

        XCTAssertTrue(
            registry.apply(
                TerminalStatusReport(
                    tty: tty,
                    source: .command,
                    reporterID: "shell",
                    sequence: 2,
                    state: .finished,
                    exitStatus: 1,
                    heartbeat: false
                ),
                now: 20,
                uptime: 20
            )
        )
        XCTAssertFalse(
            registry.apply(
                TerminalStatusReport(
                    tty: tty,
                    source: .command,
                    reporterID: "shell",
                    sequence: 1,
                    state: .running,
                    exitStatus: nil,
                    heartbeat: false
                )
            )
        )
        XCTAssertEqual(registry.visibleStatus(for: tty)?.exitStatus, 1)

        XCTAssertTrue(
            registry.apply(
                TerminalStatusReport(
                    tty: tty,
                    source: .agent,
                    reporterID: "agent",
                    sequence: 1,
                    state: .running,
                    exitStatus: nil,
                    heartbeat: false
                ),
                now: 30,
                uptime: 30
            )
        )
        XCTAssertEqual(registry.visibleStatus(for: tty)?.activityKind, .agent)
        XCTAssertTrue(registry.expireStaleAgentHeartbeats(uptime: 39))
        XCTAssertEqual(registry.visibleStatus(for: tty)?.activityKind, .command)

        XCTAssertTrue(
            registry.apply(
                TerminalStatusReport(
                    tty: tty,
                    source: .agent,
                    reporterID: "agent",
                    sequence: 2,
                    state: .running,
                    exitStatus: nil,
                    heartbeat: true
                ),
                now: 40,
                uptime: 40
            )
        )
        XCTAssertEqual(registry.visibleStatus(for: tty)?.status, .running)
    }

    func testMapsSessionStatusAnimationsByActivityKindAndResult() {
        func animation(
            kind: SessionActivityKind,
            status: TerminalSessionStatus,
            exitStatus: Int? = nil
        ) -> SessionStatusAnimation? {
            SessionStatusAnimation(
                session: TerminalSessionSnapshot(
                    id: "session",
                    name: "Session",
                    path: nil,
                    tty: nil,
                    windowId: "window",
                    tabId: "tab",
                    isActive: false,
                    isMinimized: false,
                    status: status,
                    activityKind: kind,
                    exitStatus: exitStatus,
                    statusChangedAt: nil
                )
            )
        }

        XCTAssertEqual(animation(kind: .agent, status: .running), .agentRunning)
        XCTAssertEqual(animation(kind: .command, status: .running), .commandRunning)
        XCTAssertEqual(
            animation(kind: .agent, status: .finished, exitStatus: 0),
            .agentSucceeded
        )
        XCTAssertEqual(
            animation(kind: .agent, status: .finished, exitStatus: 1),
            .agentFailed
        )
        XCTAssertEqual(
            animation(kind: .command, status: .finished, exitStatus: 0),
            .commandSucceeded
        )
        XCTAssertEqual(
            animation(kind: .command, status: .finished, exitStatus: 1),
            .commandFailed
        )
        XCTAssertEqual(
            animation(kind: .command, status: .finished),
            .commandFinished
        )
    }

    @MainActor
    func testPanelResizeKeepsStatusAnimationScopedToEachSession() throws {
        let configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("config.toml")
        defer {
            try? FileManager.default.removeItem(
                at: configURL.deletingLastPathComponent()
            )
        }

        let store = ItermStore()
        store.apply(try hello())
        store.apply(try hierarchyMessage())
        let panel = ComradePanel(
            store: store,
            settings: AppSettings(configURL: configURL)
        )

        for height in [500, 120, 500] {
            panel.setFrame(
                CGRect(x: 20, y: 20, width: 320, height: height),
                display: true
            )
            panel.contentView?.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }

        let animations = statusAnimations(in: try XCTUnwrap(panel.contentView))
        XCTAssertEqual(animations.count, 2)
        XCTAssertEqual(animations.filter { $0 == .agentRunning }.count, 1)
        XCTAssertEqual(animations.filter { $0 == .commandSucceeded }.count, 1)
    }

    func testSessionStatusPixelColorsStayOpaqueAndBrighten() throws {
        for animation in SessionStatusAnimation.allCases {
            let base = try XCTUnwrap(
                animation.pixelColor(brightness: 0.35).usingColorSpace(.deviceRGB)
            )
            let highlight = try XCTUnwrap(
                animation.pixelColor(brightness: 1).usingColorSpace(.deviceRGB)
            )

            XCTAssertEqual(base.alphaComponent, 1, accuracy: 0.001)
            XCTAssertEqual(highlight.alphaComponent, 1, accuracy: 0.001)
            XCTAssertGreaterThan(
                highlight.redComponent
                    + highlight.greenComponent
                    + highlight.blueComponent,
                base.redComponent + base.greenComponent + base.blueComponent,
                "\(animation)"
            )
        }
    }

    func testEverySessionStatusAnimationKeepsPixelsVisibleAndChangesFrames() {
        var signatures = Set<[CGFloat]>()

        for animation in SessionStatusAnimation.allCases {
            let frames = (0..<24).map { frame in
                (0..<8).flatMap { row in
                    (0..<18).map {
                        animation.brightness(column: $0, row: row, frame: frame)
                    }
                }
            }

            XCTAssertTrue(
                frames.allSatisfy { $0.contains { $0 > 0 } },
                "\(animation)"
            )
            XCTAssertGreaterThan(Set(frames).count, 1, "\(animation)")
            XCTAssertTrue(
                signatures.insert(frames.flatMap { $0 }).inserted,
                "\(animation)"
            )

            for frame in 0..<24 {
                XCTAssertTrue(
                    (0..<8).contains { row in
                        (0...10).contains {
                            animation.brightness(
                                column: $0,
                                row: row,
                                frame: frame
                            ) > 0
                        }
                    },
                    "\(animation) avatar frame \(frame)"
                )
                XCTAssertTrue(
                    (1...6).contains { row in
                        animation.brightness(
                            column: 14,
                            row: row,
                            frame: frame
                        ) > 0
                    },
                    "\(animation) status bar frame \(frame)"
                )
                XCTAssertTrue(
                    (0..<8).allSatisfy { row in
                        (11...13).allSatisfy {
                            animation.brightness(
                                column: $0,
                                row: row,
                                frame: frame
                            ) == 0
                        }
                    },
                    "\(animation) transparent gap frame \(frame)"
                )
            }
        }
    }

    func testEveryStatusAnimationStyleKeepsPixelsVisibleAndChangesFrames() {
        for style in SessionStatusAnimationStyle.allCases {
            for animation in SessionStatusAnimation.allCases {
                let frames = (0..<24).map { frame in
                    (0..<8).flatMap { row in
                        (0..<18).map {
                            animation.brightness(
                                column: $0,
                                row: row,
                                frame: frame,
                                style: style
                            )
                        }
                    }
                }

                XCTAssertTrue(
                    frames.allSatisfy { $0.contains { $0 > 0 } },
                    "\(animation) \(style)"
                )
                XCTAssertGreaterThan(
                    Set(frames).count,
                    1,
                    "\(animation) \(style)"
                )
            }
        }
    }

    func testFormatsSessionStatusTimes() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            TerminalSessionStatus.running.label(
                changedAt: 760,
                now: now,
                format: .compact
            ),
            "Running · 4m"
        )
        XCTAssertEqual(
            TerminalSessionStatus.finished.label(
                changedAt: 880,
                now: now,
                format: .compact
            ),
            "Finished · 2m ago"
        )
        XCTAssertEqual(
            TerminalSessionStatus.running.label(
                changedAt: 728,
                now: now,
                format: .detailed
            ),
            "Running · 4m 32s"
        )
        XCTAssertEqual(SessionTimeFormat.compact.refreshInterval, 60)
        XCTAssertEqual(SessionTimeFormat.detailed.refreshInterval, 1)
    }

    func testGroupsSessionsByWindowOrExactPath() throws {
        let windows = try hierarchySnapshot()

        let windowGroups = SessionGrouping.groups(from: windows, style: .window)
        let pathGroups = SessionGrouping.groups(from: windows, style: .projectPath)
        let pinnedPathGroups = SessionGrouping.groups(
            from: windows,
            style: .projectPath,
            pinnedProjectPaths: ["/repo/subdirectory"]
        )

        XCTAssertEqual(windowGroups.map(\.title), ["Window 1", "Window 2"])
        XCTAssertEqual(
            windowGroups[0].sessions.map(\.session.id),
            ["session-1", "session-2"]
        )
        XCTAssertEqual(
            windowGroups[0].sessions.map(\.session.name),
            ["zsh", "build"]
        )
        XCTAssertTrue(windowGroups[0].startsTab(at: 0))
        XCTAssertTrue(windowGroups[0].startsTab(at: 1))
        XCTAssertFalse(windowGroups[1].startsTab(at: 1))
        XCTAssertEqual(windowGroups[0].sessions.map(\.tabTitle), ["One", "Two"])
        XCTAssertEqual(
            windowGroups[0].sessions(inTab: "tab-2").map(\.session.id),
            ["session-2"]
        )
        XCTAssertEqual(
            windowGroups[1].sessions(inTab: "tab-3").map(\.session.id),
            ["session-3", "session-4"]
        )

        XCTAssertEqual(
            pathGroups.map(\.title),
            ["/repo", "/repo/subdirectory", "Unknown Path"]
        )
        XCTAssertEqual(
            pathGroups[0].sessions.map(\.session.id),
            ["session-1", "session-3"]
        )
        XCTAssertEqual(pathGroups[2].sessions.map(\.session.id), ["session-4"])
        XCTAssertEqual(
            pinnedPathGroups.map(\.title),
            ["/repo/subdirectory", "/repo", "Unknown Path"]
        )
    }

    func testProjectPathClustersSplitPaneSessionsOfSameTab() throws {
        let data = Data(
            """
            {
              "type": "snapshot",
              "sequence": 1,
              "windows": [{
                "id": "window-1",
                "number": 1,
                "isActive": true,
                "tabs": [{
                  "id": "tab-1",
                  "title": "Splits",
                  "isSelected": true,
                  "sessions": [{
                    "id": "session-a",
                    "name": "pi one",
                    "path": "/repo",
                    "windowId": "window-1",
                    "tabId": "tab-1",
                    "isActive": true,
                    "isMinimized": false
                  }, {
                    "id": "session-b",
                    "name": "pi two",
                    "path": "/other",
                    "windowId": "window-1",
                    "tabId": "tab-1",
                    "isActive": false,
                    "isMinimized": false
                  }, {
                    "id": "session-c",
                    "name": "pi three",
                    "path": "/repo",
                    "windowId": "window-1",
                    "tabId": "tab-1",
                    "isActive": false,
                    "isMinimized": false
                  }]
                }]
              }]
            }
            """.utf8
        )
        let windows = try JSONDecoder()
            .decode(BridgeMessage.self, from: data).windows ?? []

        let pathGroups = SessionGrouping.groups(from: windows, style: .projectPath)

        XCTAssertEqual(pathGroups.map(\.title), ["/other", "/repo"])
        XCTAssertEqual(
            pathGroups[1].sessions.map(\.session.id),
            ["session-a", "session-c"]
        )
        XCTAssertTrue(pathGroups[1].startsTab(at: 0))
        XCTAssertFalse(pathGroups[1].startsTab(at: 1))
        XCTAssertEqual(pathGroups[1].sessions(inTab: "tab-1").count, 2)
    }

    func testStoreIgnoresOlderSnapshots() throws {
        let store = ItermStore()
        store.apply(try hello())
        store.apply(try snapshot(sequence: 2, title: "New"))
        store.apply(try snapshot(sequence: 1, title: "Old"))

        XCTAssertEqual(store.windows.first?.tabs.first?.title, "New")
    }

    func testStoreClearsSessionsWhenBridgeDisconnects() throws {
        let store = ItermStore()
        store.apply(try hello())
        store.apply(try snapshot(sequence: 2, title: "Old"))

        store.updateConnectionState(.disconnected("iTerm2 restarted"))

        XCTAssertTrue(store.windows.isEmpty)

        store.apply(try hello())
        store.apply(try snapshot(sequence: 1, title: "New"))
        XCTAssertEqual(store.windows.first?.tabs.first?.title, "New")
    }

    func testActionFailureDoesNotDisconnectBridge() throws {
        let store = ItermStore()
        store.apply(try hello())
        let data = Data(
            """
            {
              "type": "actionResult",
              "requestId": "request-1",
              "ok": false,
              "error": "Session not found"
            }
            """.utf8
        )

        store.apply(try JSONDecoder().decode(BridgeMessage.self, from: data))

        XCTAssertEqual(store.connectionState, .connected)
        XCTAssertEqual(store.actionError, "Session not found")
    }

    func testBridgeResourceIsBundled() {
        XCTAssertNotNil(
            Bundle.main.url(forResource: "iTermateBridge", withExtension: "py")
        )
    }

    func testSparkleConfigurationIsBundled() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            "https://ssbun.github.io/iTermate/appcast.xml"
        )
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            "L5Q2dHra6pBCxeGReTg3uOslFt/VFO9QVbxM2aCB6XA="
        )
    }

    private func hello() throws -> BridgeMessage {
        let data = Data(
            """
            {
              "type": "hello"
            }
            """.utf8
        )
        return try JSONDecoder().decode(BridgeMessage.self, from: data)
    }

    private func hierarchySnapshot() throws -> [TerminalWindowSnapshot] {
        try hierarchyMessage().windows ?? []
    }

    private func hierarchyMessage() throws -> BridgeMessage {
        let data = Data(
            """
            {
              "type": "snapshot",
              "sequence": 1,
              "windows": [{
                "id": "window-1",
                "number": 1,
                "isActive": true,
                "tabs": [{
                  "id": "tab-1",
                  "title": "One",
                  "isSelected": true,
                  "sessions": [{
                    "id": "session-1",
                    "name": "zsh",
                    "path": "/repo",
                    "windowId": "window-1",
                    "tabId": "tab-1",
                    "isActive": true,
                    "isMinimized": false,
                    "status": "running",
                    "activityKind": "agent"
                  }]
                }, {
                  "id": "tab-2",
                  "title": "Two",
                  "isSelected": false,
                  "sessions": [{
                    "id": "session-2",
                    "name": "build",
                    "path": "/repo/subdirectory",
                    "windowId": "window-1",
                    "tabId": "tab-2",
                    "isActive": true,
                    "isMinimized": false,
                    "status": "finished",
                    "activityKind": "command",
                    "exitStatus": 0
                  }]
                }]
              }, {
                "id": "window-2",
                "number": 2,
                "isActive": false,
                "tabs": [{
                  "id": "tab-3",
                  "title": "Three",
                  "isSelected": true,
                  "sessions": [{
                    "id": "session-3",
                    "name": "tests",
                    "path": "/repo",
                    "windowId": "window-2",
                    "tabId": "tab-3",
                    "isActive": true,
                    "isMinimized": false
                  }, {
                    "id": "session-4",
                    "name": "remote",
                    "path": null,
                    "windowId": "window-2",
                    "tabId": "tab-3",
                    "isActive": false,
                    "isMinimized": true
                  }]
                }]
              }]
            }
            """.utf8
        )
        return try JSONDecoder().decode(BridgeMessage.self, from: data)
    }

    private func statusAnimations(in view: NSView) -> [SessionStatusAnimation] {
        let current = (view as? SessionStatusMatrixView).map { [$0.animation] } ?? []
        return current + view.subviews.flatMap(statusAnimations)
    }

    private func snapshot(sequence: Int, title: String) throws -> BridgeMessage {
        let data = Data(
            """
            {
              "type": "snapshot",
              "sequence": \(sequence),
              "windows": [{
                "id": "window-1",
                "number": 1,
                "isActive": true,
                "tabs": [{
                  "id": "tab-1",
                  "title": "\(title)",
                  "isSelected": true,
                  "sessions": []
                }]
              }]
            }
            """.utf8
        )
        return try JSONDecoder().decode(BridgeMessage.self, from: data)
    }
}
