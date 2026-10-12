import AppKit
import Darwin
import Foundation
import SwiftUI

/// Available local decision engines; selection never implies a fallback to another engine.
enum LocalDecisionProvider: String, CaseIterable, Identifiable {
    /// Existing multilingual MLX engine.
    case laya
    /// Vela's pinned CPU decision engine.
    case vela

    var id: String { rawValue }
    var title: String { self == .laya ? "Laya" : "Vela 2.0 · 0.3B" }
    var modelID: String { self == .laya ? "aac6fef/laya-multilingual-mlx" : "vllm-sr/Vela-2.0-0.3B" }
    var dependencies: [String] {
        self == .laya ? ["laya-mlx==0.2.0"] : ["torch==2.14.1", "transformers==5.19.0", "safetensors", "numpy"]
    }
}

/// Retains terminating workers until every later launch can safely acquire the service lock.
@MainActor
final class LocalModelExitBarrier {
    private var terminating: [Process] = []

    /// Stops only an owned child, retaining its identity even if a UI operation is cancelled.
    func stop(_ child: Process?) {
        guard let child, child.isRunning else { return }
        if !terminating.contains(where: { $0 === child }) { terminating.append(child) }
        child.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if child.isRunning, child.processIdentifier > 0 { kill(child.processIdentifier, SIGKILL) }
        }
    }

    /// Cancellation abandons this waiter, not the processes another waiter must still observe.
    func waitForExit(isCurrent: () -> Bool) async throws {
        while true {
            guard isCurrent() else { throw CancellationError() }
            terminating.removeAll { !$0.isRunning }
            if terminating.isEmpty { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

/// Owns the optional local model worker for the lifetime of iTermate.
@MainActor
final class LocalModelService: ObservableObject {
    nonisolated static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/iTermate/Laya", isDirectory: true)

    @Published private(set) var provider: LocalDecisionProvider
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
    private let exitBarrier = LocalModelExitBarrier()
    private var ownsAnalysisMarker = false
    private var generation = UUID()
    private let defaults: UserDefaults
    private let directory: URL
    private var configurationRevision = UUID()
    private var configurationIsCurrent = false

    init(defaults: UserDefaults = .standard, directory: URL = LocalModelService.directory) {
        self.defaults = defaults
        self.directory = directory
        provider = LocalDecisionProvider(rawValue: defaults.string(forKey: "decisionModelProvider") ?? "") ?? .vela
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
        let markerURL = modelDirectory.appendingPathComponent("model.json")
        let marker = (try? Data(contentsOf: markerURL)).flatMap {
            try? JSONDecoder().decode(InstalledModel.self, from: $0)
        }
        let requiredFiles = provider == .laya ? [
            "model.safetensors", "mlx_config.json", "rl_agent_config.json",
            "encoder/config.json", "tokenizer/tokenizer.json", "tokenizer/tokenizer_config.json",
        ] : [
            "model.safetensors", "config.json", "calibration.json", "tokenizer.json",
            "configuration_vela2.py", "modeling_vela2.py", "vela2_inference.py",
        ]
        let modelFilesPresent = marker.map { model in
            guard model.model == provider.modelID, model.path.hasPrefix("/") else { return false }
            if provider == .vela && model.revision != "d6f03aa9baca4f9017fa8f8e9c2764d3bed3f409" { return false }
            return requiredFiles.allSatisfy { name in
                let file = URL(fileURLWithPath: model.path).appendingPathComponent(name)
                let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize
                return FileManager.default.isReadableFile(atPath: file.path) && (size ?? 0) > 0
            }
        } ?? false
        let modules = provider == .laya ? ["laya_mlx"] : ["torch", "transformers", "safetensors"]
        let runtimePresent = FileManager.default.isExecutableFile(atPath: pythonURL.path)
            && modules.allSatisfy { module in
                FileManager.default.isReadableFile(atPath: modelDirectory
                    .appendingPathComponent("runtime/lib/python3.12/site-packages/\(module)/__init__.py").path)
            }
        modelInstalled = modelFilesPresent && runtimePresent
        if modelInstalled {
            installationDetail = "\(provider.title) · \(provider == .laya ? "GPU / FP16" : "CPU / FP32") · Runtime and model files available"
        } else if marker != nil {
            installationDetail = "Some model or runtime files are missing. Use Repair / Download."
        } else {
            installationDetail = "The model has not been installed. Download it below."
        }
    }

    private struct InstalledModel: Decodable {
        let path: String
        let model: String
        let revision: String?
    }

    var isSupported: Bool {
        #if arch(arm64)
        if #available(macOS 14, *) { return true }
        #endif
        return false
    }

    /// Retains the legacy control directory so existing API clients keep their connection location.
    private var modelDirectory: URL {
        provider == .laya ? directory : directory.appendingPathComponent("Vela", isDirectory: true)
    }

    private var pythonURL: URL {
        modelDirectory.appendingPathComponent("runtime/bin/python")
    }

    /// Publishes a new preference epoch before requests can use a changed configuration.
    @discardableResult
    private func publishConfiguration() -> Bool {
        configurationIsCurrent = false
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let revision = UUID()
            let data = try JSONSerialization.data(withJSONObject: [
                "provider": provider.rawValue, "revision": revision.uuidString,
                "analysisEnabled": analysisEnabled, "serviceEnabled": serviceEnabled,
            ])
            try data.write(to: directory.appendingPathComponent("configuration.json"), options: .atomic)
            configurationRevision = revision
            configurationIsCurrent = true
            return true
        } catch {
            self.error = "Could not publish the selected decision model. No model fallback will be used."
            return false
        }
    }

    /// Changes the selected engine and waits for our old worker to release its shared service lock.
    func setProvider(_ selected: LocalDecisionProvider) {
        guard provider != selected, !isBusy else { return }
        stop()
        provider = selected
        defaults.set(selected.rawValue, forKey: "decisionModelProvider")
        error = nil
        installationError = nil
        refreshInstallationStatus()
        guard publishConfiguration(), serviceEnabled else { return }
        start()
    }

    private var helperURL: URL? {
        Bundle.main.url(forResource: "iTermate-laya", withExtension: "py")
    }

    /// Restores the user's preference without downloading anything automatically.
    func startIfEnabled() {
        clearAbandonedAnalysisPermission()
        guard publishConfiguration() else { return }
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
        guard publishConfiguration() else { stop(); return }
        if enabled { start() } else { stop() }
    }

    func setAnalysisEnabled(_ enabled: Bool) {
        analysisEnabled = enabled
        defaults.set(enabled, forKey: "layaAnalysisEnabled")
        publishConfiguration()
        updateAnalysisMarker()
    }

    /// Installs an isolated runtime and downloads the model only after a settings action.
    func downloadModel() {
        guard isSupported, !isBusy, !isReady else { return }
        installationError = nil
        guard let helperURL else {
            installationError = "The bundled local decision helper is missing."
            return
        }
        let candidates = [
            "/opt/homebrew/bin/uv", "/usr/local/bin/uv",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/uv").path,
        ]
        guard let uv = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            installationError = "Install uv first (brew install uv), then retry. Python 3.12 and the selected model are installed in an isolated environment."
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
                try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true,
                                                        attributes: [.posixPermissions: 0o700])
                if !FileManager.default.isExecutableFile(atPath: pythonURL.path) {
                    try await run(URL(fileURLWithPath: uv), arguments: ["venv", "--python", "3.12", modelDirectory.appendingPathComponent("runtime").path], operation: operation)
                }
                guard generation == operation else { return }
                installationDetail = "Installing \(provider.title) runtime…"
                try await run(URL(fileURLWithPath: uv), arguments: ["pip", "install", "--python", pythonURL.path] + provider.dependencies, operation: operation)
                guard generation == operation else { return }
                installationDetail = "Downloading multilingual model…"
                try await run(pythonURL, arguments: [helperURL.path, "download", "--directory", directory.path, "--provider", provider.rawValue], operation: operation)
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
        guard publishConfiguration() else { return }
        let operation = UUID()
        generation = operation
        isBusy = true
        error = nil
        status = "Loading \(provider.title)…"
        Task { @MainActor in
            do {
                try await run(pythonURL, arguments: [helperURL.path, "serve", "--directory", directory.path,
                                                    "--provider", provider.rawValue, "--parent-pid", String(ProcessInfo.processInfo.processIdentifier)], operation: operation)
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
        exitBarrier.stop(process)
        process = nil
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
                .replacingOccurrences(of: "{{MODEL_NAME}}", with: provider.title)
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
            if analysisEnabled && isReady && configurationIsCurrent {
                try Data(configurationRevision.uuidString.utf8).write(to: marker, options: .atomic)
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
            guard let port = event["port"] as? Int, (1...65535).contains(port),
                  event["provider"] as? String == provider.rawValue else { return }
            isReady = true
            isBusy = false
            status = "Ready · \(provider.title) · \(provider == .laya ? "GPU / FP16" : "CPU / FP32")"
            endpoint = "http://127.0.0.1:\(port)"
            updateAnalysisMarker()
        case "error":
            let message = "\(provider.title) reported \(event["error"] as? String ?? "an error"). Check network access, available disk space and the model download."
            if isInstalling { installationError = message } else { error = message }
        default:
            break
        }
    }

    private func run(_ executable: URL, arguments: [String], operation: UUID) async throws {
        try await exitBarrier.waitForExit { generation == operation }
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

private struct LocalModelInstallationIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let installed: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: reduceMotion)) { timeline in
            let row = Int(timeline.date.timeIntervalSinceReferenceDate / 0.2) % 7
            let glyph = installed ? [0, 1, 2, 68, 40, 16, 0] : [8, 8, 8, 42, 28, 8, 0]
            Canvas { context, _ in
                for y in 0..<7 {
                    for x in 0..<7 where glyph[y] & (1 << (6 - x)) != 0 {
                        context.fill(Path(CGRect(x: CGFloat(x * 2), y: CGFloat(y * 2), width: 1.7, height: 1.7)),
                                     with: .color((installed ? Color.green : Color.secondary)
                                        .opacity(reduceMotion || row == y ? 1 : 0.5)))
                    }
                }
            }
        }
    }
}

struct LocalModelSettingsView: View {
    @ObservedObject var service: LocalModelService
    @State private var connectionPromptCopied = false

    var body: some View {
        Form {
            Section("Local Decisions") {
                Picker("Decision model", selection: Binding(get: { service.provider }, set: { service.setProvider($0) })) {
                    ForEach(LocalDecisionProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .disabled(service.isBusy)
                Text("Switching stops the current worker and loads the selected model if installed. No automatic fallback to another model.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("The multilingual model is downloaded separately. Session text stays on this Mac; model decisions never replace explicit lifecycle events.")
                    .font(.caption).foregroundStyle(.secondary)
                if !service.isSupported {
                    Text("Requires Apple Silicon and macOS 14 or later.")
                }
                HStack {
                    Text("Installation status")
                    Spacer()
                    Label {
                        Text(service.installationStatus)
                    } icon: {
                        LocalModelInstallationIcon(installed: service.modelInstalled && !service.isInstalling && service.installationError == nil)
                            .frame(width: 14, height: 14).accessibilityHidden(true)
                    }
                    .foregroundStyle(service.modelInstalled && !service.isInstalling && service.installationError == nil ? .green : .secondary)
                }
                Text(service.installationDetail).font(.caption).foregroundStyle(.secondary)
                if let error = service.installationError {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
                Button(service.modelInstalled ? "Repair / Download" : "Download Model") { service.downloadModel() }
                    .disabled(!service.isSupported || service.isBusy || service.isReady)
                Text(service.provider == .laya
                     ? "Downloads Python dependencies and Laya (~650 MB plus runtime). Requires uv. No weights are bundled with the App."
                     : "Downloads Vela (~1.3 GB plus runtime). Allow 2–3 GB of memory for short inputs. Requires uv. Weights/code: Apache-2.0; tokenizer: Gemma terms.")
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
                Text("POST /v1/decide · POST /v1/session · POST /v1/question · GET /health")
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
                Text("Pi classifies whether the last assistant reply asks or waits for your participation, including confirmation, choices, authorization or missing information. Requests and implicit approval gates count even without a question mark; completion reports and autonomous progress do not. Model errors/timeouts keep explicit lifecycle status; no other model is used. Disabling assistance retains legacy rules. Classification is experimental and is not guaranteed to exceed 90% accuracy. Classification runs only after the Agent finishes answering through its lifecycle hook. Terminal screens are never scanned; sessions without this hook are not classified.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { service.refreshInstallationStatus() }
        .onChange(of: service.endpoint) { _ in connectionPromptCopied = false }
    }
}
