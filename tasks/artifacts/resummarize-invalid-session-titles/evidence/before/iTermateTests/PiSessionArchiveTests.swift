import CryptoKit
import Foundation
import XCTest
@testable import iTermate

final class PiSessionArchiveTests: XCTestCase {
    private func fixture(summary: String? = nil) throws -> (URL, PiArchiveRecord) {
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString
        let data = try JSONSerialization.data(withJSONObject: [
            "type": "session", "version": 3, "id": sessionID, "cwd": folder.path,
            "timestamp": "2026-01-01T00:00:00.000Z",
        ]) + Data([0x0a])
        let record = PiArchiveRecord(version: 1, id: folder.lastPathComponent, sessionId: sessionID,
            name: "Fixture", cwd: folder.path, archivedAt: 1, filename: "archive_\(sessionID).jsonl",
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            originalSessionFile: folder.appendingPathComponent("original.jsonl").path, terminal: "iTerm2", summary: summary)
        try data.write(to: folder.appendingPathComponent(record.filename))
        try JSONEncoder().encode(record).write(to: folder.appendingPathComponent("manifest.json"))
        return (folder, record)
    }

    private func terminalSession(id: String = "pane", tty: String? = "/dev/ttys001", name: String = "π - project (zsh)") -> TerminalSessionSnapshot {
        TerminalSessionSnapshot(id: id, name: name, path: "/same/project", tty: tty,
            windowId: "window", tabId: "tab", isActive: false, isMinimized: false,
            status: .idle, activityKind: .agent, exitStatus: nil, statusChangedAt: nil)
    }

    private func liveFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @discardableResult
    private func writeLiveDescriptor(at root: URL, summary: Any? = "修复分页逻辑", terminal: String = "iTerm2",
                                     pane: String = "pane", tty: String = "/dev/ttys001",
                                     updatedAt: TimeInterval = Date().timeIntervalSince1970,
                                     supportsTitleRefresh: Bool? = nil, canRefreshTitle: Bool? = nil) throws -> URL {
        let id = UUID().uuidString
        var descriptor: [String: Any] = [
            "version": 1, "id": id, "pid": ProcessInfo.processInfo.processIdentifier, "parentPid": 2,
            "token": String(repeating: "a", count: 64),
            "socketPath": root.appendingPathComponent(String(id.prefix(16)) + ".sock").path,
            "terminal": terminal, "terminalSessionId": pane, "tty": tty,
            "sessionId": "native-session", "sessionFile": "/unused/session.jsonl", "cwd": "/same/project",
            "name": "Pi session", "canArchive": true, "supportsSummary": true, "updatedAt": updatedAt,
        ]
        descriptor["taskSummary"] = summary
        descriptor["supportsTitleRefresh"] = supportsTitleRefresh
        descriptor["canRefreshTitle"] = canRefreshTitle
        let file = root.appendingPathComponent(id + ".json")
        try JSONSerialization.data(withJSONObject: descriptor).write(to: file)
        return file
    }

    func testManualTitleRefreshRequiresCapabilityAndIdleIdentity() throws {
        let root = try liveFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let archives = PiSessionArchives(liveRoot: root)
        for supported: Bool? in [nil, false, true] {
            for ready: Bool? in [nil, false, true] {
                let file = try writeLiveDescriptor(at: root, supportsTitleRefresh: supported, canRefreshTitle: ready)
                archives.refresh()
                XCTAssertEqual(
                    archives.supportsTitleRefresh(terminalSession(), terminal: .iTerm2),
                    supported == true
                )
                XCTAssertEqual(archives.canRefreshTitle(terminalSession(), terminal: .iTerm2), supported == true && ready == true)
                XCTAssertFalse(archives.canRefreshTitle(terminalSession(id: "other-pane"), terminal: .iTerm2))
                XCTAssertFalse(archives.canRefreshTitle(terminalSession(), terminal: .ghostty))
                XCTAssertFalse(archives.isRefreshingTitle(terminalSession(), terminal: .iTerm2))
                try FileManager.default.removeItem(at: file)
            }
        }
        try writeLiveDescriptor(at: root, updatedAt: Date().timeIntervalSince1970 - 30,
                                supportsTitleRefresh: true, canRefreshTitle: true)
        archives.refresh()
        XCTAssertFalse(archives.canRefreshTitle(terminalSession(), terminal: .iTerm2))
    }

    func testGhosttyManualTitleRefreshUsesUniqueTTY() throws {
        let root = try liveFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeLiveDescriptor(at: root, terminal: "Ghostty", supportsTitleRefresh: true, canRefreshTitle: true)
        let archives = PiSessionArchives(liveRoot: root)
        archives.refresh()
        XCTAssertTrue(archives.canRefreshTitle(terminalSession(), terminal: .ghostty))
        XCTAssertFalse(archives.canRefreshTitle(terminalSession(tty: nil), terminal: .ghostty))
        try writeLiveDescriptor(at: root, terminal: "Ghostty", supportsTitleRefresh: true, canRefreshTitle: true)
        archives.refresh()
        XCTAssertFalse(archives.canRefreshTitle(terminalSession(), terminal: .ghostty))
    }

    func testLiveTaskTitleUsesExactTerminalIdentityNotPathOrName() throws {
        let root = try liveFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeLiveDescriptor(at: root)
        let archives = PiSessionArchives(liveRoot: root)
        archives.refresh()
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(), terminal: .iTerm2), "修复分页逻辑")
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(id: "other-pane"), terminal: .iTerm2), "π - project (zsh)")
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(), terminal: .ghostty), "π - project (zsh)")
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(), terminal: nil), "π - project (zsh)")
    }

    func testGhosttyTaskTitleRequiresUniquePiTTY() throws {
        let root = try liveFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeLiveDescriptor(at: root, terminal: "Ghostty", pane: "inherited-iterm-pane")
        let archives = PiSessionArchives(liveRoot: root)
        archives.refresh()
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(), terminal: .ghostty), "修复分页逻辑")
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(tty: nil), terminal: .ghostty), "π - project (zsh)")
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(tty: "/dev/other"), terminal: .ghostty), "π - project (zsh)")
        try writeLiveDescriptor(at: root, terminal: "Ghostty")
        archives.refresh()
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(), terminal: .ghostty), "π - project (zsh)")
    }

    func testDuplicatePiDescriptorsDoNotChooseAnArbitraryTitle() throws {
        let root = try liveFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeLiveDescriptor(at: root)
        try writeLiveDescriptor(at: root, summary: "另一个任务")
        let archives = PiSessionArchives(liveRoot: root)
        archives.refresh()
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(), terminal: .iTerm2), "π - project (zsh)")
    }

    func testLiveTitlesPreserveModelOutputWithoutStyleFiltering() throws {
        let root = try liveFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let archives = PiSessionArchives(liveRoot: root)
        for title in ["控制 Tab 切换会话跳过 Codex 故障", " 修复 HTTP429 重试。\n",
                      String(repeating: "字", count: 81), "Fix pagination", "已完成", "修复🔔"] {
            let file = try writeLiveDescriptor(at: root, summary: title)
            archives.refresh()
            XCTAssertEqual(archives.sessionTitle(for: terminalSession(), terminal: .iTerm2), title)
            try FileManager.default.removeItem(at: file)
        }
    }

    func testMissingMalformedAndExpiredTaskTitlesFallBack() throws {
        let root = try liveFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let archives = PiSessionArchives(liveRoot: root)
        for summary: Any? in [nil, "", " \n\t", String(repeating: "x", count: 16385), 42] {
            let file = try writeLiveDescriptor(at: root, summary: summary)
            archives.refresh()
            XCTAssertEqual(archives.sessionTitle(for: terminalSession(), terminal: .iTerm2), "π - project (zsh)")
            try FileManager.default.removeItem(at: file)
        }
        try writeLiveDescriptor(at: root, updatedAt: Date().timeIntervalSince1970 - 30)
        archives.refresh()
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(), terminal: .iTerm2), "π - project (zsh)")
        XCTAssertEqual(archives.sessionTitle(for: terminalSession(name: " \n "), terminal: .iTerm2), "Session")
    }

    func testTaskTitleRefreshReplacesAndClearsWithoutStatusChanges() throws {
        let root = try liveFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        var file = try writeLiveDescriptor(at: root)
        let archives = PiSessionArchives(liveRoot: root)
        let session = terminalSession()
        archives.refresh()
        XCTAssertEqual(archives.sessionTitle(for: session, terminal: .iTerm2), "修复分页逻辑")
        try FileManager.default.removeItem(at: file)
        file = try writeLiveDescriptor(at: root, summary: "添加会话摘要")
        archives.refresh()
        XCTAssertEqual(archives.sessionTitle(for: session, terminal: .iTerm2), "添加会话摘要")
        try FileManager.default.removeItem(at: file)
        archives.refresh()
        XCTAssertEqual(archives.sessionTitle(for: session, terminal: .iTerm2), session.name)
    }

    func testNativeHeaderAndChecksumAreRequired() throws {
        let (folder, record) = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertEqual(try PiSessionArchives.validatedArchive(at: folder), record)
        try Data("corrupted\n".utf8).write(to: folder.appendingPathComponent(record.filename))
        XCTAssertThrowsError(try PiSessionArchives.validatedArchive(at: folder))
    }

    func testSummaryIsPreservedAndLegacyArchivesRemainReadable() throws {
        let (folder, record) = try fixture(summary: "修复列表分页解析，已保存修改，尚未运行测试。")
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertEqual(try PiSessionArchives.validatedArchive(at: folder).summary, record.summary)
        let manifest = folder.appendingPathComponent("manifest.json")
        var contents = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
        contents.removeValue(forKey: "summary")
        try JSONSerialization.data(withJSONObject: contents).write(to: manifest)
        XCTAssertNil(try PiSessionArchives.validatedArchive(at: folder).summary)
    }

    func testEmptyOrOversizedSummaryIsRejected() throws {
        for summary in ["  ", String(repeating: "x", count: 4801)] {
            let (folder, _) = try fixture(summary: summary)
            defer { try? FileManager.default.removeItem(at: folder) }
            XCTAssertThrowsError(try PiSessionArchives.validatedArchive(at: folder))
        }
    }

    func testTranscriptSymlinksAreRejected() throws {
        let (folder, record) = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let transcript = folder.appendingPathComponent(record.filename)
        let other = folder.appendingPathComponent("other.jsonl")
        try FileManager.default.moveItem(at: transcript, to: other)
        try FileManager.default.createSymbolicLink(at: transcript, withDestinationURL: other)
        XCTAssertThrowsError(try PiSessionArchives.validatedArchive(at: folder))
    }

    func testManifestCannotRedirectTranscriptOutsideArchive() throws {
        let (folder, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let manifest = folder.appendingPathComponent("manifest.json")
        var contents = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
        contents["filename"] = "../original.jsonl"
        try JSONSerialization.data(withJSONObject: contents).write(to: manifest)
        XCTAssertThrowsError(try PiSessionArchives.validatedArchive(at: folder))
    }
}
