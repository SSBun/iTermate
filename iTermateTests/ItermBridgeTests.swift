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
            message.windows?.first?.tabs.first?.sessions.first?.exitStatus,
            0
        )
        XCTAssertEqual(
            message.windows?.first?.tabs.first?.sessions.first?.statusChangedAt,
            1_753_833_600
        )
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
