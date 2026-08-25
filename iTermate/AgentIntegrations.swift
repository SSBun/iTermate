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

enum ShellStatusIntegration: String, CaseIterable, Identifiable {
    case zsh
    case bash
    case fish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zsh:
            "zsh"
        case .bash:
            "Bash"
        case .fish:
            "fish"
        }
    }

    var symbolName: String {
        switch self {
        case .zsh:
            "z.square"
        case .bash:
            "b.square"
        case .fish:
            "fish"
        }
    }
}

@MainActor
final class AgentIntegrationManager: ObservableObject {
    @Published private(set) var installedAgents: Set<CodingAgent> = []
    @Published private(set) var installedShells: Set<ShellStatusIntegration> = []
    @Published private(set) var errors: [CodingAgent: String] = [:]
    @Published private(set) var shellErrors: [ShellStatusIntegration: String] = [:]

    private let fileManager: FileManager
    private let homeDirectory: URL
    private let piResourceURL: URL?
    private let statusResourceURL: URL?
    private let zshResourceURL: URL?
    private let bashResourceURL: URL?
    private let fishResourceURL: URL?

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        piResourceURL: URL? = Bundle.main.url(
            forResource: "iTermate-integration",
            withExtension: "ts"
        ),
        statusResourceURL: URL? = Bundle.main.url(
            forResource: "iTermate-status",
            withExtension: "py"
        ),
        zshResourceURL: URL? = Bundle.main.url(
            forResource: "iTermate",
            withExtension: "zsh"
        ),
        bashResourceURL: URL? = Bundle.main.url(
            forResource: "iTermate",
            withExtension: "bash"
        ),
        fishResourceURL: URL? = Bundle.main.url(
            forResource: "iTermate",
            withExtension: "fish"
        )
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.piResourceURL = piResourceURL
        self.statusResourceURL = statusResourceURL
        self.zshResourceURL = zshResourceURL
        self.bashResourceURL = bashResourceURL
        self.fishResourceURL = fishResourceURL
        refresh()
    }

    func isInstalled(_ agent: CodingAgent) -> Bool {
        installedAgents.contains(agent)
    }

    func isInstalled(_ shell: ShellStatusIntegration) -> Bool {
        installedShells.contains(shell)
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

    func setInstalled(_ installed: Bool, for shell: ShellStatusIntegration) {
        do {
            if installed {
                try installShell(shell)
            } else {
                try uninstallShell(shell)
            }
            shellErrors[shell] = nil
        } catch {
            shellErrors[shell] = error.localizedDescription
        }
        refresh()
    }

    func updateInstalledIntegrations() {
        updateInstalledPiIntegration()
        updateInstalledStatusResources()
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

    private func updateInstalledStatusResources() {
        defer { refresh() }
        do {
            if codexConfigurationIsInstalled {
                try installCodex()
            } else if fileManager.fileExists(atPath: statusReporterURL.path) {
                guard let statusResourceURL else {
                    throw IntegrationError.missingResource("status reporter")
                }
                try updateResourceIfNeeded(
                    from: statusResourceURL,
                    to: statusReporterURL,
                    permissions: 0o700
                )
            }
            for shell in installedShells {
                let (resource, destination) = try shellResourceAndDestination(shell)
                try updateResourceIfNeeded(
                    from: resource,
                    to: destination,
                    permissions: 0o600
                )
            }
        } catch {
            NSLog(
                "iTermate failed to update status integration: %@",
                error.localizedDescription
            )
        }
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
        installedShells = Set(
            ShellStatusIntegration.allCases.filter(shellIntegrationIsInstalled)
        )
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

    private var statusReporterURL: URL {
        integrationDirectoryURL.appendingPathComponent("iTermate-status.py")
    }

    private var legacyCodexHookURL: URL {
        integrationDirectoryURL.appendingPathComponent("iTermate-hook.py")
    }

    private var zshHookURL: URL {
        integrationDirectoryURL.appendingPathComponent("iTermate.zsh")
    }

    private var bashHookURL: URL {
        integrationDirectoryURL.appendingPathComponent("iTermate.bash")
    }

    private var fishHookURL: URL {
        homeDirectory.appendingPathComponent(".config/fish/conf.d/iTermate.fish")
    }

    private var codexConfigurationIsInstalled: Bool {
        guard
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

    private var codexIntegrationIsInstalled: Bool {
        codexConfigurationIsInstalled
            && (
                fileManager.fileExists(atPath: statusReporterURL.path)
                    || fileManager.fileExists(atPath: legacyCodexHookURL.path)
            )
    }

    private func installPi() throws {
        guard let piResourceURL else {
            throw IntegrationError.missingResource("Pi integration")
        }
        try installResource(from: piResourceURL, to: piExtensionURL, permissions: 0o600)
    }

    private func installCodex() throws {
        var root = try codexHooksRoot()
        try installStatusReporter()
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let quotedReporterPath = Self.shellQuoted(statusReporterURL.path)

        for (event, status) in Self.codexEvents {
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.removeAll(where: Self.isManagedEntry)
            entries.append([
                "_iTermate": true,
                "hooks": [[
                    "type": "command",
                    "command": "\(quotedReporterPath) agent \(status)",
                    "timeout": 3,
                ]],
            ])
            hooks[event] = entries
        }

        root["hooks"] = hooks
        try writeCodexHooks(root)
        try removeIfPresent(at: legacyCodexHookURL)
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
        try removeIfPresent(at: legacyCodexHookURL)
        try removeStatusReporterIfUnused()
    }

    private func installShell(_ shell: ShellStatusIntegration) throws {
        switch shell {
        case .zsh:
            try validateManagedSource(in: zshConfigURL)
        case .bash:
            try validateManagedSource(in: bashRCURL)
            try validateManagedSource(in: bashLoginURL)
        case .fish:
            try validateManagedFishHook()
        }

        try installStatusReporter()
        let (resource, destination) = try shellResourceAndDestination(shell)
        try installResource(from: resource, to: destination, permissions: 0o600)

        switch shell {
        case .zsh:
            try addManagedSource(to: zshConfigURL, sourceURL: zshHookURL)
        case .bash:
            try addManagedSource(to: bashRCURL, sourceURL: bashHookURL)
            let loginURL = bashLoginURL
            try addManagedSource(
                to: loginURL,
                sourceURL: bashHookURL,
                bashOnly: loginURL.lastPathComponent == ".profile"
            )
        case .fish:
            break
        }
    }

    private func uninstallShell(_ shell: ShellStatusIntegration) throws {
        switch shell {
        case .zsh:
            try removeManagedSource(from: zshConfigURL)
            try removeIfPresent(at: zshHookURL)
        case .bash:
            try removeManagedSource(from: bashRCURL)
            for url in bashLoginURLs {
                try removeManagedSource(from: url)
            }
            try removeIfPresent(at: bashHookURL)
        case .fish:
            try validateManagedFishHook()
            try removeIfPresent(at: fishHookURL)
        }
        try removeStatusReporterIfUnused()
    }

    private func installStatusReporter() throws {
        guard let statusResourceURL else {
            throw IntegrationError.missingResource("status reporter")
        }
        try installResource(
            from: statusResourceURL,
            to: statusReporterURL,
            permissions: 0o700
        )
    }

    private func shellResourceAndDestination(
        _ shell: ShellStatusIntegration
    ) throws -> (URL, URL) {
        switch shell {
        case .zsh:
            guard let zshResourceURL else {
                throw IntegrationError.missingResource("zsh hook")
            }
            return (zshResourceURL, zshHookURL)
        case .bash:
            guard let bashResourceURL else {
                throw IntegrationError.missingResource("Bash hook")
            }
            return (bashResourceURL, bashHookURL)
        case .fish:
            guard let fishResourceURL else {
                throw IntegrationError.missingResource("fish hook")
            }
            return (fishResourceURL, fishHookURL)
        }
    }

    private func shellIntegrationIsInstalled(
        _ shell: ShellStatusIntegration
    ) -> Bool {
        guard fileManager.fileExists(atPath: statusReporterURL.path) else {
            return false
        }
        switch shell {
        case .zsh:
            return fileManager.fileExists(atPath: zshHookURL.path)
                && hasManagedSource(in: zshConfigURL)
        case .bash:
            return fileManager.fileExists(atPath: bashHookURL.path)
                && hasManagedSource(in: bashRCURL)
                && hasManagedSource(in: bashLoginURL)
        case .fish:
            return fishHookIsManaged
        }
    }

    private func removeStatusReporterIfUnused() throws {
        guard
            !codexIntegrationIsInstalled,
            !ShellStatusIntegration.allCases.contains(where: shellIntegrationIsInstalled)
        else {
            return
        }
        try removeIfPresent(at: statusReporterURL)
    }

    private var zshConfigURL: URL {
        homeDirectory.appendingPathComponent(".zshrc")
    }

    private var bashRCURL: URL {
        homeDirectory.appendingPathComponent(".bashrc")
    }

    private var bashLoginURLs: [URL] {
        [".bash_profile", ".bash_login", ".profile"].map {
            homeDirectory.appendingPathComponent($0)
        }
    }

    private var bashLoginURL: URL {
        bashLoginURLs.first(where: { fileManager.fileExists(atPath: $0.path) })
            ?? bashLoginURLs[0]
    }

    private func validateManagedSource(in configURL: URL) throws {
        let configURL = resolvedConfigURL(configURL)
        guard fileManager.fileExists(atPath: configURL.path) else { return }
        let contents = try String(contentsOf: configURL, encoding: .utf8)
        let startCount = contents.components(separatedBy: Self.shellBlockStart).count - 1
        let endCount = contents.components(separatedBy: Self.shellBlockEnd).count - 1
        guard startCount == endCount, startCount <= 1 else {
            throw IntegrationError.invalidShellConfig(configURL.lastPathComponent)
        }
        if startCount == 1, !hasManagedSource(in: configURL) {
            throw IntegrationError.invalidShellConfig(configURL.lastPathComponent)
        }
    }

    private func hasManagedSource(in configURL: URL) -> Bool {
        let configURL = resolvedConfigURL(configURL)
        guard
            let contents = try? String(contentsOf: configURL, encoding: .utf8),
            let start = contents.range(of: Self.shellBlockStart),
            let end = contents.range(
                of: Self.shellBlockEnd,
                range: start.upperBound..<contents.endIndex
            )
        else {
            return false
        }
        return start.upperBound <= end.lowerBound
    }

    private var fishHookIsManaged: Bool {
        guard
            let contents = try? String(contentsOf: fishHookURL, encoding: .utf8)
        else {
            return false
        }
        return contents.hasPrefix(Self.fishFileMarker)
    }

    private func validateManagedFishHook() throws {
        guard fileManager.fileExists(atPath: fishHookURL.path) else { return }
        guard fishHookIsManaged else {
            throw IntegrationError.invalidShellConfig(fishHookURL.lastPathComponent)
        }
    }

    private func addManagedSource(
        to configURL: URL,
        sourceURL: URL,
        bashOnly: Bool = false
    ) throws {
        let configURL = resolvedConfigURL(configURL)
        let exists = fileManager.fileExists(atPath: configURL.path)
        var contents = exists
            ? try String(contentsOf: configURL, encoding: .utf8)
            : ""
        let hasStart = contents.contains(Self.shellBlockStart)
        let hasEnd = contents.contains(Self.shellBlockEnd)
        guard hasStart == hasEnd else {
            throw IntegrationError.invalidShellConfig(configURL.lastPathComponent)
        }
        if hasManagedSource(in: configURL) { return }
        guard !hasStart else {
            throw IntegrationError.invalidShellConfig(configURL.lastPathComponent)
        }

        if !contents.isEmpty, !contents.hasSuffix("\n") {
            contents.append("\n")
        }
        let sourceCommand = "source \(Self.shellQuoted(sourceURL.path))"
        contents += """
        \(Self.shellBlockStart)
        \(bashOnly ? "[ -n \"${BASH_VERSION:-}\" ] && \(sourceCommand)" : sourceCommand)
        \(Self.shellBlockEnd)

        """
        try writeShellConfig(contents, to: configURL, existed: exists)
    }

    private func removeManagedSource(from configURL: URL) throws {
        let configURL = resolvedConfigURL(configURL)
        guard fileManager.fileExists(atPath: configURL.path) else { return }
        var contents = try String(contentsOf: configURL, encoding: .utf8)
        let startCount = contents.components(separatedBy: Self.shellBlockStart).count - 1
        let endCount = contents.components(separatedBy: Self.shellBlockEnd).count - 1
        guard startCount == endCount else {
            throw IntegrationError.invalidShellConfig(configURL.lastPathComponent)
        }
        guard startCount == 1, let start = contents.range(of: Self.shellBlockStart) else {
            if startCount == 0 { return }
            throw IntegrationError.invalidShellConfig(configURL.lastPathComponent)
        }
        guard
            let end = contents.range(
                of: Self.shellBlockEnd,
                range: start.upperBound..<contents.endIndex
            ),
            start.upperBound <= end.lowerBound
        else {
            throw IntegrationError.invalidShellConfig(configURL.lastPathComponent)
        }

        var lowerBound = start.lowerBound
        var upperBound = end.upperBound
        if upperBound < contents.endIndex, contents[upperBound] == "\n" {
            upperBound = contents.index(after: upperBound)
        } else if lowerBound > contents.startIndex {
            let previous = contents.index(before: lowerBound)
            if contents[previous] == "\n" {
                lowerBound = previous
            }
        }
        contents.removeSubrange(lowerBound..<upperBound)
        try writeShellConfig(contents, to: configURL, existed: true)
    }

    private func writeShellConfig(
        _ contents: String,
        to configURL: URL,
        existed: Bool
    ) throws {
        let permissions = existed
            ? try fileManager.attributesOfItem(atPath: configURL.path)[.posixPermissions]
            : nil
        try fileManager.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: configURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.posixPermissions: permissions ?? 0o600],
            ofItemAtPath: configURL.path
        )
    }

    private func resolvedConfigURL(_ url: URL) -> URL {
        fileManager.fileExists(atPath: url.path) ? url.resolvingSymlinksInPath() : url
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

    private func updateResourceIfNeeded(
        from sourceURL: URL,
        to destinationURL: URL,
        permissions: Int
    ) throws {
        guard
            try Data(contentsOf: sourceURL)
                != Data(contentsOf: destinationURL)
        else {
            return
        }
        try installResource(
            from: sourceURL,
            to: destinationURL,
            permissions: permissions
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

    private static let shellBlockStart = "# >>> iTermate shell status >>>"
    private static let shellBlockEnd = "# <<< iTermate shell status <<<"
    private static let fishFileMarker = "# Managed by iTermate.\n"
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
    case invalidShellConfig(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            "Missing bundled \(name)."
        case .invalidCodexHooks:
            "Codex hooks.json is not a valid hooks configuration."
        case .invalidShellConfig(let name):
            "\(name) has an incomplete or duplicate iTermate block."
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

            Section {
                ForEach(ShellStatusIntegration.allCases) { shell in
                    row(for: shell)
                }
            } header: {
                Text("Shell Commands")
            } footer: {
                Text(
                    "Opt in to report top-level command status. Restart the shell after changing this setting."
                )
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
        .onAppear(perform: integrations.refresh)
    }

    private func row(for agent: CodingAgent) -> some View {
        Toggle(
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
    }

    private func row(for shell: ShellStatusIntegration) -> some View {
        Toggle(
            isOn: Binding(
                get: { integrations.isInstalled(shell) },
                set: { integrations.setInstalled($0, for: shell) }
            )
        ) {
            Label(shell.title, systemImage: shell.symbolName)
        }
        .help(detail(for: shell))
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

    private func detail(for shell: ShellStatusIntegration) -> String {
        if let error = integrations.shellErrors[shell] {
            return error
        }
        return integrations.isInstalled(shell)
            ? "Restart this shell to apply changes"
            : "Not installed"
    }

}
