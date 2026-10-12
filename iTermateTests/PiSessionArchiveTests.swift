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
