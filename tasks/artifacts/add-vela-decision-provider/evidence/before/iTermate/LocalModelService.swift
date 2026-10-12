import AppKit
import Darwin
import Foundation
import SwiftUI

/// Owns the optional local model worker for the lifetime of iTermate.
@MainActor
final class LocalModelService: ObservableObject {
    nonisolated static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/iTermate/Laya", isDirectory: true)

    @Published private(set) var status = "Stopped"
    @Published private(set) var error: String?
    @Published private(set) var isBusy = false
    @Published private(set) var isReady = false
    @Published private(set) var progress: Double?
    @Published private(set) var endpoint: String?
    @Published private(set) var modelInstalled = false
    @Published private(set) var isInstalling = false
    @Published private(set) var installationDetail = "Download the model to use local decisions."
    @Published private(set) var installationError: String?
    @Published private(set) var serviceEnabled: Bool
    @Published private(set) var analysisEnabled: Bool

    private var process: Process?
    private var ownsAnalysisMarker = false
    private var generation = UUID()
    private let defaults: UserDefaults
    private let directory: URL

    init(defaults: UserDefaults = .standard, directory: URL = LocalModelService.directory) {
        self.defaults = defaults
        self.directory = directory
        serviceEnabled = defaults.bool(forKey: "layaServiceEnabled")
        analysisEnabled = defaults.bool(forKey: "layaAnalysisEnabled")
        refreshInstallationStatus()
    }

    var installationStatus: String {
        if isInstalling { return "Installing…" }
        if installationError != nil { return "Installation failed" }
        return modelInstalled ? "Installed" : "Not installed"
    }

    /// Checks installed files without loading the model or hashing large weights on the UI thread.
    func refreshInstallationStatus() {
        guard !isInstalling else { return }
        let markerURL = directory.appendingPathComponent("model.json")
        let marker = (try? Data(contentsOf: markerURL)).flatMap {
            try? JSONDecoder().decode(InstalledModel.self, from: $0)
        }
        let requiredFiles = [
            "model.safetensors", "mlx_config.json", "rl_agent_config.json",
            "encoder/config.json", "tokenizer/tokenizer.json", "tokenizer/tokenizer_config.json",
        ]
        let modelFilesPresent = marker.map { model in
            guard model.model == "aac6fef/laya-multilingual-mlx", model.path.hasPrefix("/") else { return false }
            return requiredFiles.allSatisfy { name in
                let file = URL(fileURLWithPath: model.path).appendingPathComponent(name)
                let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize
                return FileManager.default.isReadableFile(atPath: file.path) && (size ?? 0) > 0
            }
        } ?? false
        let runtimePresent = FileManager.default.isExecutableFile(atPath: pythonURL.path)
            && FileManager.default.isReadableFile(atPath: directory
                .appendingPathComponent("runtime/lib/python3.12/site-packages/laya_mlx/__init__.py").path)
        modelInstalled = modelFilesPresent && runtimePresent
        if modelInstalled {
            installationDetail = "Laya multilingual · FP16 · Runtime and model files available"
        } else if marker != nil {
            installationDetail = "Some model or runtime files are missing. Use Repair / Download."
        } else {
            installationDetail = "The model has not been installed. Download it below."
        }
    }

    private struct InstalledModel: Decodable {
        let path: String
        let model: String
    }

    var isSupported: Bool {
        #if arch(arm64)
        if #available(macOS 14, *) { return true }
        #endif
        return false
    }

    private var pythonURL: URL {
        directory.appendingPathComponent("runtime/bin/python")
    }

    private var helperURL: URL? {
        Bundle.main.url(forResource: "iTermate-laya", withExtension: "py")
    }

    /// Restores the user's preference without downloading anything automatically.
    func startIfEnabled() {
        clearAbandonedAnalysisPermission()
        if serviceEnabled { start() }
    }

    /// Clears crash leftovers even when this launch keeps the service disabled.
    private func clearAbandonedAnalysisPermission() {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let descriptor = open(directory.appendingPathComponent("service.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { return }
        defer { flock(descriptor, LOCK_UN) }
        do {
            for name in ["analysis-enabled", "endpoint.json"] {
                let file = directory.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: file.path) {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            self.error = "Could not clear an abandoned local model endpoint."
        }
    }

    func setServiceEnabled(_ enabled: Bool) {
        serviceEnabled = enabled
        defaults.set(enabled, forKey: "layaServiceEnabled")
        if enabled { start() } else { stop() }
    }

    func setAnalysisEnabled(_ enabled: Bool) {
        analysisEnabled = enabled
        defaults.set(enabled, forKey: "layaAnalysisEnabled")
        updateAnalysisMarker()
    }

    /// Installs an isolated runtime and downloads the model only after a settings action.
    func downloadModel() {
        guard isSupported, !isBusy, !isReady else { return }
        installationError = nil
        guard let helperURL else {
            installationError = "The bundled Laya helper is missing."
            return
        }
        let candidates = [
            "/opt/homebrew/bin/uv", "/usr/local/bin/uv",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/uv").path,
        ]
        guard let uv = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            installationError = "Install uv first (brew install uv), then retry. Python 3.12 and Laya are installed in an isolated environment."
            return
        }
        let operation = UUID()
        generation = operation
        isBusy = true
        isInstalling = true
        progress = nil
        error = nil
        installationDetail = "Preparing Python runtime…"
        Task { @MainActor in
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                        attributes: [.posixPermissions: 0o700])
                if !FileManager.default.isExecutableFile(atPath: pythonURL.path) {
                    try await run(URL(fileURLWithPath: uv), arguments: ["venv", "--python", "3.12", directory.appendingPathComponent("runtime").path], operation: operation)
                }
                guard generation == operation else { return }
                installationDetail = "Installing Laya-MLX…"
                try await run(URL(fileURLWithPath: uv), arguments: ["pip", "install", "--python", pythonURL.path, "laya-mlx==0.2.0"], operation: operation)
                guard generation == operation else { return }
                installationDetail = "Downloading multilingual model…"
                try await run(pythonURL, arguments: [helperURL.path, "download", "--directory", directory.path], operation: operation)
                guard generation == operation else { return }
                isInstalling = false
                isBusy = false
                progress = nil
                refreshInstallationStatus()
                guard modelInstalled else {
                    throw ServiceError("Download ended but required model or runtime files are missing. Please retry.")
                }
                if serviceEnabled { start() }
            } catch {
                guard generation == operation else { return }
                isInstalling = false
                isBusy = false
                progress = nil
                refreshInstallationStatus()
                installationError = installationError ?? error.localizedDescription
            }
        }
    }

    func start() {
        guard isSupported, !isBusy, !isReady else { return }
        refreshInstallationStatus()
        guard modelInstalled, FileManager.default.isExecutableFile(atPath: pythonURL.path), let helperURL else {
            error = "Download the model and runtime in this tab first."
            return
        }
        let operation = UUID()
        generation = operation
        isBusy = true
        error = nil
        status = "Loading model…"
        Task { @MainActor in
            do {
                try await run(pythonURL, arguments: [helperURL.path, "serve", "--directory", directory.path,
                                                    "--parent-pid", String(ProcessInfo.processInfo.processIdentifier)], operation: operation)
                guard generation == operation else { return }
                finishWithError(ServiceError("The local service stopped. Toggle the service to restart it."), operation: operation)
            } catch {
                finishWithError(error, operation: operation)
            }
        }
    }

    /// Stops only the child process owned by this App instance.
    func stop() {
        generation = UUID()
        let child = process
        process = nil
        if child?.isRunning == true {
            child?.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if let child, child.isRunning { kill(child.processIdentifier, SIGKILL) }
            }
        }
        let installationWasCancelled = isInstalling
        isInstalling = false
        isBusy = false
        isReady = false
        endpoint = nil
        progress = nil
        status = "Stopped"
        refreshInstallationStatus()
        if installationWasCancelled { installationDetail = "Installation cancelled. You can retry the download." }
        updateAnalysisMarker()
    }

    func copyToken() {
        do {
            let token = try String(contentsOf: directory.appendingPathComponent("api-token"), encoding: .utf8)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(token, forType: .string)
        } catch {
            self.error = "Could not read the local API token."
        }
    }

    /// Copies current connection credentials only in response to the user's explicit action.
    func copyConnectionPrompt() -> Bool {
        guard isReady, let endpoint else { return false }
        do {
            guard let templateURL = Bundle.main.url(forResource: "agent-connection-prompt", withExtension: "md") else {
                throw ServiceError("The bundled Agent connection prompt is missing.")
            }
            let token = try String(contentsOf: directory.appendingPathComponent("api-token"), encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
            guard (32...256).contains(token.utf8.count), token.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) else {
                throw ServiceError("The local API token format is invalid.")
            }
            let prompt = try String(contentsOf: templateURL, encoding: .utf8)
                .replacingOccurrences(of: "{{API_URL}}", with: endpoint)
                .replacingOccurrences(of: "{{API_TOKEN}}", with: token)
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(prompt, forType: .string) else {
                throw ServiceError("Could not copy the Agent connection prompt.")
            }
            return true
        } catch {
            self.error = "Could not copy the Agent connection prompt. Check the local service and its bundled resources."
            return false
        }
    }

    private func updateAnalysisMarker() {
        let marker = directory.appendingPathComponent("analysis-enabled")
        do {
            if analysisEnabled && isReady {
                try Data().write(to: marker, options: .atomic)
                ownsAnalysisMarker = true
            } else if ownsAnalysisMarker {
                if FileManager.default.fileExists(atPath: marker.path) {
                    try FileManager.default.removeItem(at: marker)
                }
                ownsAnalysisMarker = false
            }
        } catch {
            self.error = "Could not update session analysis preference."
        }
    }

    private func finishWithError(_ failure: Error, operation: UUID) {
        guard generation == operation else { return }
        process = nil
        isBusy = false
        isReady = false
        endpoint = nil
        progress = nil
        status = "Unavailable"
        error = failure.localizedDescription
        updateAnalysisMarker()
    }

    private func receive(_ line: String, operation: UUID) {
        guard generation == operation, let data = line.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stage = event["stage"] as? String else { return }
        switch stage {
        case "download":
            if let total = event["total"] as? Double, total > 0,
               let completed = event["completed"] as? Double {
                progress = min(1, completed / total)
            }
        case "ready":
            guard let port = event["port"] as? Int, (1...65535).contains(port) else { return }
            isReady = true
            isBusy = false
            status = "Ready · GPU / FP16"
            endpoint = "http://127.0.0.1:\(port)"
            updateAnalysisMarker()
        case "error":
            let message = "Laya reported \(event["error"] as? String ?? "an error"). Check network access, available disk space and the model download."
            if isInstalling { installationError = message } else { error = message }
        default:
            break
        }
    }

    private func run(_ executable: URL, arguments: [String], operation: UUID) async throws {
        guard generation == operation else { throw CancellationError() }
        let child = Process()
        let pipe = Pipe()
        child.executableURL = executable
        child.arguments = arguments
        child.standardOutput = pipe
        child.standardError = pipe
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        environment["HF_HUB_DISABLE_TELEMETRY"] = "1"
        environment["HF_HUB_DISABLE_XET"] = "1"
        environment.removeValue(forKey: "TYPESAFE_API_KEY")
        child.environment = environment
        process = child
        try child.run()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async { [weak self] in
                var pending = Data()
                while true {
                    let data = pipe.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    pending.append(data)
                    while let newline = pending.firstIndex(of: 0x0a) {
                        let line = String(decoding: pending[..<newline], as: UTF8.self)
                        pending.removeSubrange(...newline)
                        DispatchQueue.main.async { self?.receive(line, operation: operation) }
                    }
                    if pending.count > 16384 { pending.removeAll() }
                }
                child.waitUntilExit()
                if child.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ServiceError("Local model operation failed (exit \(child.terminationStatus)). Check uv, network access and disk space, then retry."))
                }
            }
        }
    }
}

private struct ServiceError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct LocalModelSettingsView: View {
    @ObservedObject var service: LocalModelService
    @State private var connectionPromptCopied = false

    var body: some View {
        Form {
            Section("Laya-MLX · Local Decisions") {
                Text("The multilingual model is downloaded separately. Session text stays on this Mac; model decisions never replace explicit lifecycle events.")
                    .font(.caption).foregroundStyle(.secondary)
                if !service.isSupported {
                    Text("Requires Apple Silicon and macOS 14 or later.")
                }
                HStack {
                    Text("Installation status")
                    Spacer()
                    Label(service.installationStatus, systemImage: service.modelInstalled && !service.isInstalling && service.installationError == nil
                          ? "checkmark.circle.fill" : "arrow.down.circle")
                        .foregroundStyle(service.modelInstalled && !service.isInstalling && service.installationError == nil ? .green : .secondary)
                }
                Text(service.installationDetail).font(.caption).foregroundStyle(.secondary)
                if let error = service.installationError {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
                Button(service.modelInstalled ? "Repair / Download" : "Download Model") { service.downloadModel() }
                    .disabled(!service.isSupported || service.isBusy || service.isReady)
                Text("Downloads Python dependencies and a multilingual model (~650 MB plus runtime). Requires uv. No weights are bundled with the App.")
                    .font(.caption).foregroundStyle(.secondary)
                if service.isInstalling {
                    if let progress = service.progress { ProgressView(value: progress) }
                    else { ProgressView().controlSize(.small) }
                    Button("Cancel Installation") { service.stop() }
                }
            }
            Section("Service") {
                Toggle("Enable local API service", isOn: Binding(get: { service.serviceEnabled }, set: { service.setServiceEnabled($0) }))
                    .disabled(!service.isSupported || service.isBusy)
                Toggle("Assist session state and reply detection", isOn: Binding(get: { service.analysisEnabled }, set: { service.setAnalysisEnabled($0) }))
                HStack {
                    Text("Service status")
                    Spacer()
                    Text(service.status).foregroundStyle(.secondary)
                }
                if service.isBusy && !service.isInstalling {
                    ProgressView().controlSize(.small)
                    Button("Cancel Startup") { service.stop() }
                }
                if let error = service.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            Section("Public API · This Mac Only") {
                Text(service.endpoint ?? "Start the service to obtain its loopback address.")
                    .textSelection(.enabled)
                Text("POST /v1/decide · POST /v1/session · GET /health")
                    .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                Button(connectionPromptCopied ? "Connection Prompt Copied" : "Copy Agent Connection Prompt") {
                    connectionPromptCopied = service.copyConnectionPrompt()
                }
                .disabled(!service.isReady)
                .help("Copies the current API address and real Bearer token. Share only with trusted clients.")
                Text("The connection prompt includes your real API token. Share it only with trusted agents or clients.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Copy API Token") { service.copyToken() }.disabled(!service.isReady)
                if let documentation = URL(string: "https://github.com/SSBun/iTermate/blob/main/docs/local-model-api.md") {
                    Link("API Documentation & Example", destination: documentation)
                }
                Text("Bearer authentication required. The port may change on restart. Clients can read endpoint.json and api-token in the Laya support directory. Quitting iTermate stops the service.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Pi uses the last assistant message. iTerm2 can estimate unknown states from its visible text. Ghostty without an Agent integration remains unknown.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { service.refreshInstallationStatus() }
        .onChange(of: service.endpoint) { _ in connectionPromptCopied = false }
    }
}
