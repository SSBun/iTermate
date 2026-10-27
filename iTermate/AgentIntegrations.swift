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

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        piResourceURL: URL? = Bundle.main.url(
            forResource: "iTermate-integration",
            withExtension: "ts"
        )
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.piResourceURL = piResourceURL
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
            case (.codex, _):
                return
            default:
                return
            }
            errors[agent] = nil
        } catch {
            errors[agent] = error.localizedDescription
        }
        refresh()
    }

    func updateInstalledIntegrations() {
        updateInstalledPiIntegration()
        removeLegacyCodexIntegrations()
    }

    private func updateInstalledPiIntegration() {
        guard fileManager.fileExists(atPath: piExtensionURL.path) else { return }
        defer { refresh() }

        do {
            guard let piResourceURL else {
                throw IntegrationError.missingResource("Pi integration")
            }
            guard
                try Data(contentsOf: piResourceURL)
                    != Data(contentsOf: piExtensionURL)
            else {
                return
            }
            try installResource(
                from: piResourceURL,
                to: piExtensionURL,
                permissions: 0o600
            )
            errors[.pi] = nil
        } catch {
            errors[.pi] = error.localizedDescription
            NSLog(
                "iTermate failed to update Pi integration: %@",
                error.localizedDescription
            )
        }
    }

    private func removeLegacyCodexIntegrations() {
        defer { refresh() }
        do {
            try removeManagedCodexHooks()
        } catch {
            NSLog(
                "iTermate could not remove its legacy Codex hooks: %@",
                error.localizedDescription
            )
        }
        do {
            try removeIfPresent(at: codexLauncherURL)
            try removeIfPresent(at: codexAgentHooksURL)
            try removeIfPresent(at: legacyCodexHookURL)
        } catch {
            NSLog(
                "iTermate failed to remove legacy Codex integration: %@",
                error.localizedDescription
            )
        }
    }

    func refresh() {
        var installed: Set<CodingAgent> = []
        if fileManager.fileExists(atPath: piExtensionURL.path) {
            installed.insert(.pi)
        }
        installed.insert(.codex)
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

    private var integrationDirectoryURL: URL {
        homeDirectory.appendingPathComponent(
            "Library/Application Support/iTermate/integrations",
            isDirectory: true
        )
    }

    private var codexLauncherURL: URL {
        integrationDirectoryURL.appendingPathComponent("iTermate-codex.py")
    }

    private var codexAgentHooksURL: URL {
        integrationDirectoryURL.appendingPathComponent("codex-agent-hooks.json")
    }

    private var legacyCodexHookURL: URL {
        integrationDirectoryURL.appendingPathComponent("iTermate-hook.py")
    }

    private func installPi() throws {
        guard let piResourceURL else {
            throw IntegrationError.missingResource("Pi integration")
        }
        try installResource(from: piResourceURL, to: piExtensionURL, permissions: 0o600)
    }

    private func removeManagedCodexHooks() throws {
        if fileManager.fileExists(atPath: codexHooksURL.path) {
            var root = try codexHooksRoot()
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            var changed = false
            for event in Array(hooks.keys) {
                guard var entries = hooks[event] as? [[String: Any]] else { continue }
                let originalCount = entries.count
                entries.removeAll(where: Self.isManagedEntry)
                if entries.count != originalCount {
                    changed = true
                    hooks[event] = entries
                }
            }
            if changed {
                root["hooks"] = hooks
                try writeCodexHooks(root)
            }
        }
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
        Form {
            Section {
                ForEach(CodingAgent.allCases) { agent in
                    row(for: agent)
                }
            } header: {
                Text("Coding Agents")
            } footer: {
                Text(
                    "Supported agents can report working and completion status to iTermate."
                )
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
        .onAppear(perform: integrations.refresh)
    }

    private func row(for agent: CodingAgent) -> some View {
        if agent == .codex {
            return AnyView(
                LabeledContent {
                    Text("Automatic")
                        .foregroundStyle(.secondary)
                } label: {
                    Label(agent.rawValue, systemImage: agent.symbolName)
                }
                .help("Monitored automatically when you run the original codex command")
            )
        }
        return AnyView(Toggle(
            isOn: Binding(
                get: { integrations.isInstalled(agent) },
                set: { integrations.setInstalled($0, for: agent) }
            )
        ) {
            Label(agent.rawValue, systemImage: agent.symbolName)
        }
        .disabled(!agent.isSupported)
        .opacity(agent.isSupported ? 1 : 0.5)
        .help(detail(for: agent))
        )
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
        return "Reload existing sessions with /reload"
    }
}
