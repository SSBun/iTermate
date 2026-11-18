import SwiftUI

struct AISettingsView: View {
    @ObservedObject var local: LocalLLMService
    @ObservedObject var models: AIModelService
    @State private var llmKey = ""
    @State private var decisionKey = ""
    @State private var confirmsRepair = false
    @State private var showsTestResult = false
    @State private var testTitle = "Provider Test"

    var body: some View {
        Form {
            Section("LLM models") {
                Picker("Provider", selection: Binding(
                    get: { models.configuration.provider },
                    set: { provider in models.selectProvider(provider); llmKey = "" }
                )) {
                    ForEach(AIProvider.allCases) { Text($0.title).tag($0) }
                }
                if models.configuration.provider == .ollama {
                    OllamaDeploymentSettingsView(service: local, confirmsRepair: $confirmsRepair)
                } else {
                    HStack {
                        TextField(models.configuration.provider == .codex ? "Model ID (optional)" : "Model ID", text: Binding(
                            get: { models.configuration.model(for: models.configuration.provider) },
                            set: { value in models.selectModel(value, provider: models.configuration.provider) }
                        ))
                        if models.configuration.provider == .codex {
                            Menu("Choose Model") {
                                Button("Codex Default") { models.update { $0.models["codex"] = ""; $0.codexThinkingLevel = nil } }
                                ForEach(models.codexModels) { model in
                                    Button(model.id) { models.update { $0.models["codex"] = model.id; $0.codexThinkingLevel = nil } }
                                }
                            }
                            .fixedSize()
                        } else {
                            Menu("Choose Model") {
                                ForEach(models.remoteModels[models.configuration.provider.rawValue] ?? []) { model in
                                    Button(model.id) { models.selectModel(model.id, provider: models.configuration.provider) }
                                }
                            }
                            .disabled((models.remoteModels[models.configuration.provider.rawValue] ?? []).isEmpty)
                            .fixedSize()
                        }
                    }
                    if models.configuration.provider == .codex {
                        Picker("Thinking level", selection: Binding(
                            get: { models.configuration.codexThinkingLevel },
                            set: { value in models.update { $0.codexThinkingLevel = value } }
                        )) {
                            Text("Codex Default").tag(Optional<CodexThinkingLevel>.none)
                            ForEach(models.codexThinkingLevels) { level in
                                Text(level.rawValue).tag(Optional(level))
                            }
                        }
                        Text("Model options come from the local Codex catalog. You can also enter a model ID. Thinking levels follow the selected model; changing the model resets thinking to Codex Default.")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("Codex CLI path", text: Binding(
                            get: { models.configuration.codexExecutable.isEmpty
                                ? models.detectedCodexExecutable ?? "" : models.configuration.codexExecutable },
                            set: { value in models.update { $0.codexExecutable = value } }
                        ))
                        if models.configuration.codexExecutable.isEmpty {
                            Text(models.detectedCodexExecutable == nil
                                ? "Codex CLI was not found. Install it or enter its absolute path."
                                : "Automatically detected. You can enter a different path to override it.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Uses your local Codex CLI login. Run codex login first. Requests use an isolated temporary directory with shell tools and web search disabled.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        SecureField("New API key", text: $llmKey)
                        Button("Save API Key") {
                            if models.saveKey(llmKey, account: models.configuration.provider.rawValue) { llmKey = "" }
                        }
                        .disabled(llmKey.isEmpty || models.isTesting || models.fetchingModelProvider != nil)
                        Button(models.fetchingModelProvider == models.configuration.provider ? "Fetching Models…" : "Fetch Models") {
                            models.fetchModels()
                        }
                        .disabled(models.fetchingModelProvider != nil || models.isTesting)
                        if let status = models.modelListStatus[models.configuration.provider.rawValue] {
                            Text(status).font(.caption).textSelection(.enabled)
                        }
                        Picker("Thinking level", selection: Binding(
                            get: { models.remoteThinkingLevel },
                            set: { models.selectRemoteThinkingLevel($0) }
                        )) {
                            Text("Provider Default").tag(Optional<RemoteThinkingLevel>.none)
                            ForEach(models.remoteThinkingLevels) { level in
                                Text(level.title).tag(Optional(level))
                            }
                        }
                        .disabled(models.remoteThinkingLevels.isEmpty)
                        Text(models.remoteThinkingLevels.isEmpty
                            ? "No verified thinking options for this model. Provider Default sends no thinking override."
                            : "Thinking options follow the selected model. Changing the model resets thinking to Provider Default.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Fetch uses your saved API key and sends no conversation. The list shows API-visible text model candidates; endpoint support may still need a provider test.")
                            .font(.caption).foregroundStyle(.secondary)
                        if !models.message.isEmpty { Text(models.message).font(.caption).textSelection(.enabled) }
                    }
                }
                Menu("Test LLM Provider") {
                    Button("Generate a Sample Title") {
                        showTest(title: "LLM Title Test") { models.test(decision: false, local: local) }
                    }
                    Button("Check a Reply Requiring a Response") {
                        showTest(title: "LLM Question Test") { models.testLLMQuestion(question: true, local: local) }
                    }
                    Button("Check a Completion Report") {
                        showTest(title: "LLM Completion Report Test") { models.testLLMQuestion(question: false, local: local) }
                    }
                }
                .disabled(models.isTesting || local.isBusy || models.fetchingModelProvider != nil)
            }
            Section("Decision models") {
                LabeledContent("Provider", value: "OpenAI Decision API")
                LabeledContent("Model", value: AIConfiguration.defaultDecisionModel)
                SecureField("New API key", text: $decisionKey)
                Button("Save Decision API Key") {
                    models.saveKey(decisionKey, account: "decision")
                    decisionKey = ""
                }
                .disabled(decisionKey.isEmpty || models.isTesting)
                Menu("Test Decision Model") {
                    Button("Check a Reply Requiring a Response") {
                        showTest(title: "Decision Question Test") { models.test(decision: true, local: local) }
                    }
                    Button("Check a Completion Report") {
                        showTest(title: "Decision Completion Report Test") { models.test(decision: true, question: false, local: local) }
                    }
                }
                .disabled(models.isTesting || models.fetchingModelProvider != nil)
            }
            Section("Title generation") {
                Toggle("Automatically Fill Missing Titles", isOn: Binding(
                    get: { local.autoFillMissingTitles },
                    set: { local.setAutoFillMissingTitles($0) }
                ))
                LabeledContent("Provider", value: models.configuration.provider.title)
                Text("Titles automatically use the selected LLM provider and model. Existing titles and manual refresh remain available when automatic backfill is off.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Question checking") {
                Picker("Use", selection: Binding(
                    get: { models.configuration.questionEngine },
                    set: { value in models.update { $0.questionEngine = value } }
                )) {
                    ForEach(QuestionEngine.allCases) { Text($0.title).tag($0) }
                }
                Text(models.configuration.questionEngine == .llm
                    ? "Uses the selected LLM provider to classify replies as question or normal."
                    : "Uses the built-in OpenAI Decision model. A valid probability of 0.5 or higher means a response is required.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Unavailable, timed-out, or invalid results retain the existing normal-reply default. Providers are never changed automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy & testing") {
                Text("Remote providers receive the conversation excerpt for titles and the assistant reply for question checking. API keys are saved in macOS Keychain. Keep iTermate running for Pi remote AI requests. Background reads never show Keychain prompts; if access fails, save the key again in this app. Tests send fixed examples only and can incur provider usage.")
                    .font(.caption).foregroundStyle(.secondary)
                if !models.message.isEmpty { Text(models.message).textSelection(.enabled) }
                if !models.testResult.isEmpty { Text(models.testResult).textSelection(.enabled) }
            }
        }
        .formStyle(.grouped)
        .onAppear { models.reload() }
        .sheet(isPresented: $showsTestResult) {
            VStack(alignment: .leading, spacing: 16) {
                Text(testTitle).font(.headline)
                Text(models.testResult)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("provider-test-result")
                Text("Tests use fixed examples only. Remote providers may charge for usage.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Close") { showsTestResult = false }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(24)
            .frame(width: 440, alignment: .leading)
        }
        .alert("Repair Saved Configuration?", isPresented: $confirmsRepair) {
            Button("Cancel", role: .cancel) {}
            Button("Back Up & Reset") { local.repairConfiguration() }
        } message: {
            Text("Save a private copy of the damaged local-model file, then reset it to Qwen3.5 · 2B with automatic title backfill off. No model will be downloaded or started.")
        }
    }

    private func showTest(title: String, perform action: () -> Void) {
        testTitle = title
        action()
        showsTestResult = true
    }
}

private struct OllamaDeploymentSettingsView: View {
    @ObservedObject var service: LocalLLMService
    @Binding var confirmsRepair: Bool

    var body: some View {
        Picker("Local Model", selection: Binding(get: { service.selectedModel }, set: { value in
            if let value { service.selectModel(value) }
        })) {
            if service.selectedModel == nil { Text("Choose a model").tag(Optional<LocalLLMModel>.none) }
            ForEach(LocalLLMModel.allCases) { Text($0.title).tag(Optional($0)) }
        }
        .disabled(service.isBusy)
        Label {
            Text(service.status).foregroundStyle(.secondary)
        } icon: {
            LocalModelInstallationIcon(installed: service.isReady)
                .frame(width: 14, height: 14).accessibilityHidden(true)
        }
        if service.configurationNeedsRepair {
            Button("Repair Saved Configuration…") { confirmsRepair = true }.disabled(service.isBusy)
        }
        HStack {
            Button("Check & Warm Model") { service.refresh() }
            Button("Deploy Selected Model…") { service.installModel() }
        }
        .disabled(service.isBusy || service.selectedModel == nil)
        Text("Deploy downloads the selected model through an installed Ollama runtime and can use several GB of disk space and network data. iTermate starts Ollama when needed and leaves it running on quit.")
            .font(.caption).foregroundStyle(.secondary)
    }
}
