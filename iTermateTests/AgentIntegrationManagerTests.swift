import Foundation
import XCTest
@testable import iTermate

final class AgentIntegrationManagerTests: XCTestCase {
    @MainActor
    func testInstallsAndUninstallsPiExtension() throws {
        let fixture = try Fixture(testCase: self)
        let manager = fixture.makeManager()

        manager.setInstalled(true, for: .pi)

        let installedURL = fixture.homeDirectory
            .appendingPathComponent(".pi/agent/extensions/iTermate-integration.ts")
        XCTAssertEqual(try String(contentsOf: installedURL), "pi integration")
        XCTAssertEqual(try permissions(at: installedURL), 0o600)
        XCTAssertTrue(manager.isInstalled(.pi))

        manager.setInstalled(false, for: .pi)

        XCTAssertFalse(FileManager.default.fileExists(atPath: installedURL.path))
        XCTAssertFalse(manager.isInstalled(.pi))
    }

    @MainActor
    func testUpdatesPiIntegrationOnlyWhenAlreadyInstalled() throws {
        let fixture = try Fixture(testCase: self)
        let manager = fixture.makeManager()
        let installedURL = fixture.homeDirectory
            .appendingPathComponent(".pi/agent/extensions/iTermate-integration.ts")

        manager.updateInstalledIntegrations()
        XCTAssertFalse(FileManager.default.fileExists(atPath: installedURL.path))

        try FileManager.default.createDirectory(
            at: installedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "old integration".write(
            to: installedURL,
            atomically: true,
            encoding: .utf8
        )

        manager.updateInstalledIntegrations()

        XCTAssertEqual(try String(contentsOf: installedURL), "pi integration")
        XCTAssertEqual(try permissions(at: installedURL), 0o600)
        XCTAssertTrue(manager.isInstalled(.pi))
    }

    @MainActor
    func testCodexInstallPreservesOtherHooksAndUninstallRemovesOnlyItermate() throws {
        let fixture = try Fixture(testCase: self)
        let hooksURL = fixture.homeDirectory.appendingPathComponent(".codex/hooks.json")
        try FileManager.default.createDirectory(
            at: hooksURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        {
          "custom": "keep",
          "hooks": {
            "Stop": [{
              "hooks": [{"type": "command", "command": "other-tool"}]
            }]
          }
        }
        """.write(to: hooksURL, atomically: true, encoding: .utf8)

        let manager = fixture.makeManager()
        let installedHookURL = fixture.homeDirectory.appendingPathComponent(
            "Library/Application Support/iTermate/integrations/iTermate-status.py"
        )
        manager.setInstalled(true, for: .codex)

        XCTAssertTrue(manager.isInstalled(.codex))
        XCTAssertTrue(FileManager.default.fileExists(atPath: installedHookURL.path))
        XCTAssertEqual(try permissions(at: installedHookURL), 0o700)
        XCTAssertEqual(try permissions(at: hooksURL), 0o600)
        var root = try jsonObject(at: hooksURL)
        XCTAssertEqual(root["custom"] as? String, "keep")
        var hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        for event in ["SessionStart", "UserPromptSubmit", "Stop", "SessionEnd"] {
            let entries = try XCTUnwrap(hooks[event] as? [[String: Any]])
            XCTAssertTrue(entries.contains { $0["_iTermate"] as? Bool == true })
        }
        let stopEntries = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])
        XCTAssertTrue(stopEntries.contains { entry in
            let commands = entry["hooks"] as? [[String: Any]]
            return commands?.first?["command"] as? String == "other-tool"
        })

        manager.setInstalled(false, for: .codex)

        XCTAssertFalse(manager.isInstalled(.codex))
        root = try jsonObject(at: hooksURL)
        hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        for event in ["SessionStart", "UserPromptSubmit", "Stop", "SessionEnd"] {
            let entries = try XCTUnwrap(hooks[event] as? [[String: Any]])
            XCTAssertFalse(entries.contains { $0["_iTermate"] as? Bool == true })
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: installedHookURL.path))
    }

    @MainActor
    func testCodexInstallDoesNotReplaceInvalidHooksFile() throws {
        let fixture = try Fixture(testCase: self)
        let hooksURL = fixture.homeDirectory.appendingPathComponent(".codex/hooks.json")
        try FileManager.default.createDirectory(
            at: hooksURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "not json".write(to: hooksURL, atomically: true, encoding: .utf8)

        let manager = fixture.makeManager()
        manager.setInstalled(true, for: .codex)

        XCTAssertFalse(manager.isInstalled(.codex))
        XCTAssertNotNil(manager.errors[.codex])
        XCTAssertEqual(try String(contentsOf: hooksURL), "not json")
    }

    @MainActor
    func testShellIntegrationsPreserveConfigsAndShareReporter() throws {
        let fixture = try Fixture(testCase: self)
        let zshConfig = fixture.homeDirectory.appendingPathComponent(".zshrc")
        let bashRC = fixture.homeDirectory.appendingPathComponent(".bashrc")
        let profile = fixture.homeDirectory.appendingPathComponent(".profile")
        try "export KEEP_ZSH=1\n".write(
            to: zshConfig,
            atomically: true,
            encoding: .utf8
        )
        try "export KEEP_BASH=1\n".write(
            to: bashRC,
            atomically: true,
            encoding: .utf8
        )
        try "export KEEP_PROFILE=1\n".write(
            to: profile,
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: zshConfig.path
        )

        let manager = fixture.makeManager()
        for shell in ShellStatusIntegration.allCases {
            manager.setInstalled(true, for: shell)
            XCTAssertTrue(manager.isInstalled(shell))
        }
        manager.setInstalled(true, for: .zsh)

        let zshContents = try String(contentsOf: zshConfig)
        XCTAssertTrue(zshContents.contains("export KEEP_ZSH=1"))
        XCTAssertEqual(
            zshContents.components(separatedBy: ">>> iTermate shell status >>>").count,
            2
        )
        XCTAssertEqual(try permissions(at: zshConfig), 0o644)
        XCTAssertTrue(try String(contentsOf: bashRC).contains("export KEEP_BASH=1"))
        let profileContents = try String(contentsOf: profile)
        XCTAssertTrue(profileContents.contains("export KEEP_PROFILE=1"))
        XCTAssertTrue(profileContents.contains("${BASH_VERSION:-}"))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: fixture.homeDirectory.appendingPathComponent(".bash_profile").path
            )
        )

        let reporter = fixture.homeDirectory.appendingPathComponent(
            "Library/Application Support/iTermate/integrations/iTermate-status.py"
        )
        manager.setInstalled(false, for: .zsh)
        XCTAssertTrue(FileManager.default.fileExists(atPath: reporter.path))
        XCTAssertFalse(try String(contentsOf: zshConfig).contains("iTermate shell status"))
        manager.setInstalled(false, for: .bash)
        manager.setInstalled(false, for: .fish)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reporter.path))
    }

    @MainActor
    func testFishInstallDoesNotReplaceAnUnmanagedFile() throws {
        let fixture = try Fixture(testCase: self)
        let fishHook = fixture.homeDirectory.appendingPathComponent(
            ".config/fish/conf.d/iTermate.fish"
        )
        try FileManager.default.createDirectory(
            at: fishHook.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "user file\n".write(to: fishHook, atomically: true, encoding: .utf8)

        let manager = fixture.makeManager()
        manager.setInstalled(true, for: .fish)

        XCTAssertFalse(manager.isInstalled(.fish))
        XCTAssertNotNil(manager.shellErrors[.fish])
        XCTAssertEqual(try String(contentsOf: fishHook), "user file\n")
    }

    private func jsonObject(at url: URL) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
    }

    private func permissions(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue
    }
}

private struct Fixture {
    let homeDirectory: URL
    let piResourceURL: URL
    let statusResourceURL: URL
    let zshResourceURL: URL
    let bashResourceURL: URL
    let fishResourceURL: URL

    init(testCase: XCTestCase) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iTermateTests-\(UUID().uuidString)", isDirectory: true)
        homeDirectory = directory
        let resources = directory.appendingPathComponent("resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        piResourceURL = resources.appendingPathComponent("iTermate-integration.ts")
        statusResourceURL = resources.appendingPathComponent("iTermate-status.py")
        zshResourceURL = resources.appendingPathComponent("iTermate.zsh")
        bashResourceURL = resources.appendingPathComponent("iTermate.bash")
        fishResourceURL = resources.appendingPathComponent("iTermate.fish")
        try "pi integration".write(to: piResourceURL, atomically: true, encoding: .utf8)
        try "status reporter".write(to: statusResourceURL, atomically: true, encoding: .utf8)
        try "zsh hook".write(to: zshResourceURL, atomically: true, encoding: .utf8)
        try "bash hook".write(to: bashResourceURL, atomically: true, encoding: .utf8)
        try "# Managed by iTermate.\nfish hook".write(
            to: fishResourceURL,
            atomically: true,
            encoding: .utf8
        )
        testCase.addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    @MainActor
    func makeManager() -> AgentIntegrationManager {
        AgentIntegrationManager(
            homeDirectory: homeDirectory,
            piResourceURL: piResourceURL,
            statusResourceURL: statusResourceURL,
            zshResourceURL: zshResourceURL,
            bashResourceURL: bashResourceURL,
            fishResourceURL: fishResourceURL
        )
    }
}
