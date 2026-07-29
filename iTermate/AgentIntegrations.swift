import Foundation
import SwiftUI

enum CodingAgent: String, CaseIterable, Identifiable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case openCode = "OpenCode"
    case cursorCLI = "Cursor CLI"
    case kimiCode = "Kimi Code"
    case pi = "Pi"
    case omp = "omp"

    var id: String { rawValue }

    var isSupported: Bool {
        self == .codex || self == .pi
    }

    var symbolName: String {
        switch self {
        case .claudeCode:
            "sparkles"
        case .codex:
            "chevron.left.forwardslash.chevron.right"
        case .openCode:
            "square"
        case .cursorCLI:
            "cursorarrow"
        case .kimiCode:
            "k.square"
        case .pi:
            "p.square"
        case .omp:
            "t.square"
        }
    }
}

@MainActor
final class AgentIntegrationManager: ObservableObject {
    @Published private(set) var installedAgents: Set<CodingAgent> = []
    @Published private(set) var errors: [CodingAgent: String] = [:]

    private let fileManager: FileManager
    private let homeDirectory: URL
    private let piResourceURL: URL?
    private let codexResourceURL: URL?

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        piResourceURL: URL? = Bundle.main.url(
            forResource: "iTermate-integration",
            withExtension: "ts"
        ),
        codexResourceURL: URL? = Bundle.main.url(
            forResource: "iTermate-hook",
            withExtension: "py"
        )
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.piResourceURL = piResourceURL
        self.codexResourceURL = codexResourceURL
        refresh()
    }

    func isInstalled(_ agent: CodingAgent) -> Bool {
        installedAgents.contains(agent)
    }

    func setInstalled(_ installed: Bool, for agent: CodingAgent) {
        guard agent.isSupported else { return }

        do {
            switch (agent, installed) {
            case (.pi, true):
                try installPi()
            case (.pi, false):
                try removeIfPresent(at: piExtensionURL)
            case (.codex, true):
                try installCodex()
            case (.codex, false):
                try uninstallCodex()
            default:
                return
            }
            errors[agent] = nil
        } catch {
            errors[agent] = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        var installed: Set<CodingAgent> = []
        if fileManager.fileExists(atPath: piExtensionURL.path) {
            installed.insert(.pi)
        }
        if codexIntegrationIsInstalled {
            installed.insert(.codex)
        }
        installedAgents = installed
    }

    private var piExtensionURL: URL {
        homeDirectory
            .appendingPathComponent(".pi/agent/extensions", isDirectory: true)
            .appendingPathComponent("iTermate-integration.ts")
    }

    private var codexHooksURL: URL {
        homeDirectory.appendingPathComponent(".codex/hooks.json")
    }

    private var codexHookURL: URL {
        homeDirectory
            .appendingPathComponent(
                "Library/Application Support/iTermate/integrations",
                isDirectory: true
            )
            .appendingPathComponent("iTermate-hook.py")
    }

    private var codexIntegrationIsInstalled: Bool {
        guard
            fileManager.fileExists(atPath: codexHookURL.path),
            let root = try? codexHooksRoot(),
            let hooks = root["hooks"] as? [String: Any]
        else {
            return false
        }

        return Self.codexEvents.allSatisfy { event, _ in
            let entries = hooks[event] as? [[String: Any]] ?? []
            return entries.contains(where: Self.isManagedEntry)
        }
    }

    private func installPi() throws {
        guard let piResourceURL else {
            throw IntegrationError.missingResource("Pi integration")
        }
        try installResource(from: piResourceURL, to: piExtensionURL, permissions: 0o600)
    }

    private func installCodex() throws {
        guard let codexResourceURL else {
            throw IntegrationError.missingResource("Codex hook")
        }
        var root = try codexHooksRoot()
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        try installResource(from: codexResourceURL, to: codexHookURL, permissions: 0o700)
        let quotedHookPath = Self.shellQuoted(codexHookURL.path)

        for (event, status) in Self.codexEvents {
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.removeAll(where: Self.isManagedEntry)
            entries.append([
                "_iTermate": true,
                "hooks": [[
                    "type": "command",
                    "command": "\(quotedHookPath) \(status)",
                    "timeout": 3,
                ]],
            ])
            hooks[event] = entries
        }

        root["hooks"] = hooks
        try writeCodexHooks(root)
    }

    private func uninstallCodex() throws {
        if fileManager.fileExists(atPath: codexHooksURL.path) {
            var root = try codexHooksRoot()
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            for event in Self.codexEvents.keys {
                var entries = hooks[event] as? [[String: Any]] ?? []
                entries.removeAll(where: Self.isManagedEntry)
                hooks[event] = entries
            }
            root["hooks"] = hooks
            try writeCodexHooks(root)
        }
        try removeIfPresent(at: codexHookURL)
    }

    private func codexHooksRoot() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: codexHooksURL.path) else {
            return ["hooks": [String: Any]()]
        }

        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: codexHooksURL))
        guard var root = object as? [String: Any] else {
            throw IntegrationError.invalidCodexHooks
        }
        if let hooks = root["hooks"], !(hooks is [String: Any]) {
            throw IntegrationError.invalidCodexHooks
        }
        if root["hooks"] == nil {
            root["hooks"] = [String: Any]()
        }
        return root
    }

    private func writeCodexHooks(_ root: [String: Any]) throws {
        try fileManager.createDirectory(
            at: codexHooksURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: codexHooksURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: codexHooksURL.path
        )
    }

    private func installResource(
        from sourceURL: URL,
        to destinationURL: URL,
        permissions: Int
    ) throws {
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contentsOf: sourceURL).write(to: destinationURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: destinationURL.path
        )
    }

    private func removeIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private static func isManagedEntry(_ entry: [String: Any]) -> Bool {
        entry["_iTermate"] as? Bool == true
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static let codexEvents = [
        "SessionStart": "idle",
        "UserPromptSubmit": "running",
        "Stop": "finished",
        "SessionEnd": "detached",
    ]
}

private enum IntegrationError: LocalizedError {
    case missingResource(String)
    case invalidCodexHooks

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            "Missing bundled \(name)."
        case .invalidCodexHooks:
            "Codex hooks.json is not a valid hooks configuration."
        }
    }
}

struct AgentSettingsView: View {
    @StateObject private var integrations = AgentIntegrationManager()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Manage coding-agent integrations. Supported agents can report working and completion status to iTermate.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)

                ForEach(CodingAgent.allCases) { agent in
                    row(for: agent)
                    if agent != CodingAgent.allCases.last {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding(16)
        }
        .onAppear(perform: integrations.refresh)
    }

    private func row(for agent: CodingAgent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: agent.symbolName)
                .font(.title2)
                .frame(width: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(agent.rawValue)
                    .font(.body.weight(.medium))
                Text(detail(for: agent))
                    .font(.caption)
                    .foregroundStyle(
                        integrations.errors[agent] == nil ? Color.secondary : Color.red
                    )
                    .lineLimit(2)
            }

            Spacer()

            Text(status(for: agent))
                .foregroundStyle(integrations.isInstalled(agent) ? .green : .secondary)

            Toggle(
                "\(agent.rawValue) integration",
                isOn: Binding(
                    get: { integrations.isInstalled(agent) },
                    set: { integrations.setInstalled($0, for: agent) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(!agent.isSupported)
        }
        .padding(.vertical, 11)
    }

    private func detail(for agent: CodingAgent) -> String {
        if let error = integrations.errors[agent] {
            return error
        }
        guard agent.isSupported else {
            return "Not supported yet"
        }
        guard integrations.isInstalled(agent) else {
            return "Not installed"
        }
        return agent == .codex
            ? "Approve the new hooks with /hooks"
            : "Reload existing sessions with /reload"
    }

    private func status(for agent: CodingAgent) -> String {
        integrations.isInstalled(agent) ? "Installed" : "Off"
    }
}
