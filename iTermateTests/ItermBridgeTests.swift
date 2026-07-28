import XCTest
@testable import iTermate

final class ItermBridgeTests: XCTestCase {
    func testDecodesSnapshotHierarchy() throws {
        let data = Data(
            """
            {
              "version": 2,
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
                    "isMinimized": false
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
    }

    func testGroupsSessionsByWindowOrExactPath() throws {
        let windows = try hierarchySnapshot()

        let windowGroups = SessionGrouping.groups(from: windows, style: .window)
        let pathGroups = SessionGrouping.groups(from: windows, style: .projectPath)

        XCTAssertEqual(windowGroups.map(\.title), ["Window 1", "Window 2"])
        XCTAssertEqual(
            windowGroups[0].sessions.map(\.session.id),
            ["session-1", "session-2"]
        )
        XCTAssertEqual(
            windowGroups[0].sessions.map(\.session.name),
            ["zsh", "build"]
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
    }

    func testStoreIgnoresOlderSnapshots() throws {
        let store = ItermStore()
        store.apply(try hello())
        store.apply(try snapshot(sequence: 2, title: "New"))
        store.apply(try snapshot(sequence: 1, title: "Old"))

        XCTAssertEqual(store.windows.first?.tabs.first?.title, "New")
        XCTAssertEqual(store.connectionState, .connected)
    }

    func testActionFailureDoesNotDisconnectBridge() throws {
        let store = ItermStore()
        store.apply(try hello())
        let data = Data(
            """
            {
              "version": 2,
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

    func testOlderProtocolPromptsRestartAndStillDecodesSnapshots() throws {
        let store = ItermStore()
        let data = Data(
            """
            {
              "version": 1,
              "type": "snapshot",
              "sequence": 1,
              "windows": [{
                "id": "window-1",
                "number": 1,
                "isActive": true,
                "tabs": [{
                  "id": "tab-1",
                  "title": "Old",
                  "isSelected": true,
                  "sessions": [{
                    "id": "session-1",
                    "name": "zsh",
                    "isActive": true
                  }]
                }]
              }]
            }
            """.utf8
        )

        store.apply(try JSONDecoder().decode(BridgeMessage.self, from: data))

        XCTAssertEqual(
            store.connectionState,
            .disconnected("Restart iTerm2 to update the Bridge")
        )
    }

    func testIncompatibleBridgeCannotPublishSnapshots() throws {
        let store = ItermStore()
        store.apply(try hello(bridgeVersion: 3))
        store.apply(try snapshot(sequence: 1, title: "Ignored"))

        XCTAssertTrue(store.windows.isEmpty)
        XCTAssertEqual(
            store.connectionState,
            .disconnected("Restart iTerm2 to update the Bridge")
        )
    }

    func testBridgeResourceIsBundled() {
        XCTAssertNotNil(
            Bundle.main.url(forResource: "iTermateBridge", withExtension: "py")
        )
    }

    private func hello(bridgeVersion: Int = 2) throws -> BridgeMessage {
        let data = Data(
            """
            {
              "version": 2,
              "type": "hello",
              "bridgeVersion": \(bridgeVersion)
            }
            """.utf8
        )
        return try JSONDecoder().decode(BridgeMessage.self, from: data)
    }

    private func hierarchySnapshot() throws -> [TerminalWindowSnapshot] {
        let data = Data(
            """
            {
              "version": 2,
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
                    "isMinimized": false
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
                    "isMinimized": false
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
        return try JSONDecoder().decode(BridgeMessage.self, from: data).windows ?? []
    }

    private func snapshot(sequence: Int, title: String) throws -> BridgeMessage {
        let data = Data(
            """
            {
              "version": 2,
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
