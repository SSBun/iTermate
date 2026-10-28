import XCTest
@testable import iTermate

final class ItermBridgeTests: XCTestCase {
    func testCodexScanSessionSnapshotChangesWhenTTYIsReused() {
        func windows(sessionID: String) -> [TerminalWindowSnapshot] {
            [TerminalWindowSnapshot(
                id: "window",
                number: 1,
                isActive: true,
                tabs: [TerminalTabSnapshot(
                    id: "tab",
                    title: "Terminal",
                    isSelected: true,
                    sessions: [TerminalSessionSnapshot(
                        id: sessionID,
                        name: "zsh",
                        path: nil,
                        tty: "/dev/ttys002",
                        windowId: "window",
                        tabId: "tab",
                        isActive: true,
                        isMinimized: false,
                        status: .running,
                        activityKind: .command,
                        exitStatus: nil,
                        statusChangedAt: nil
                    )]
                )]
            )]
        }

        let accepted = ItermStore.codexSessionIdentityByTTY(in: windows(sessionID: "old"))
        let replacement = ItermStore.codexSessionIdentityByTTY(
            in: windows(sessionID: "replacement")
        )

        XCTAssertEqual(
            ItermStore.staleCodexObservationTTYs(accepted: accepted, current: replacement),
            ["/dev/ttys002"]
        )
        let replacementSession = windows(sessionID: "replacement")[0].tabs[0].sessions[0]
        let merged = ItermStore.mergingCodexObservation(
            CodexSessionObservation(status: .running, changedAt: 42),
            acceptedSessionID: "old",
            into: replacementSession
        )
        XCTAssertEqual(merged.activityKind, .command)
        XCTAssertNil(merged.agentKind)
    }

    func testCodexIdentityRejectsAmbiguousTTYs() throws {
        let windows = try JSONDecoder().decode([TerminalWindowSnapshot].self, from: Data("""
        [{"id":"w","number":1,"isActive":true,"tabs":[
          {"id":"t","title":"Terminal","isSelected":true,"sessions":[
            {"id":"one","name":"codex","tty":"/dev/ttys001","isActive":true},
            {"id":"two","name":"codex","tty":"/dev/ttys001","isActive":false}]}]}]
        """.utf8))
        XCTAssertTrue(ItermStore.codexSessionIdentityByTTY(in: windows).isEmpty)
    }

    func testCodexSnapshotDriftResetsOnlyChangedTTY() {
        XCTAssertEqual(
            ItermStore.changedCodexSessionTTYs(
                captured: ["/dev/ttys001": "codex", "/dev/ttys002": "shell-old"],
                current: ["/dev/ttys001": "codex", "/dev/ttys002": "shell-new"]
            ),
            ["/dev/ttys002"]
        )
    }

    func testRolloutCannotCreateAutomaticCodexBindingBeforeDaemonLookup() {
        let thread = "11111111-2222-3333-4444-555555555555"
        let process = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 10)
        let shared = CodexSessionObservation(
            status: .running, changedAt: 20, processIdentity: process,
            sessionID: thread.uppercased(), requiresRuntimeStatus: true
        )
        let exact = CodexSessionObservation(
            status: .running, changedAt: 20, processIdentity: process, sessionID: thread
        )
        let invalid = CodexSessionObservation(
            status: nil, changedAt: nil, processIdentity: process,
            sessionID: "invalid", requiresRuntimeStatus: true
        )
        let bindings = ItermStore.reconciledCodexBindings(
            [:], observations: ["auto": shared, "file": exact, "invalid": invalid, "detached": shared],
            identities: ["auto": "pane", "file": "file-pane", "invalid": "invalid-pane"]
        )
        XCTAssertTrue(bindings.isEmpty)
        let verified = ItermStore.CodexThreadBinding(
            terminalSessionID: "pane", processIdentity: process, threadID: thread, isManual: false
        )
        let blank = CodexSessionObservation(status: nil, changedAt: nil, processIdentity: process)
        XCTAssertEqual(ItermStore.reconciledCodexBindings(
            ["auto": verified], observations: ["auto": blank], identities: ["auto": "pane"],
            terminalThreadPrefixes: ["auto": String(thread.prefix(29))]
        )["auto"], verified)
        XCTAssertTrue(ItermStore.reconciledCodexBindings(
            ["auto": verified], observations: ["auto": blank], identities: ["auto": "pane"],
            terminalThreadPrefixes: ["auto": ""]
        ).isEmpty)
        XCTAssertTrue(ItermStore.reconciledCodexBindings(
            [:], observations: ["one": shared, "two": shared], identities: ["one": "one", "two": "two"]
        ).isEmpty)
    }

    func testAutomaticCodexBindingChangesWithThreadProcessAndTerminalIdentity() throws {
        let thread = "11111111-2222-3333-4444-555555555555"
        let replacement = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        let process = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 10)
        let old = ItermStore.CodexThreadBinding(
            terminalSessionID: "old-pane", processIdentity: process, threadID: thread, isManual: false
        )
        let observation = CodexSessionObservation(
            status: .running, changedAt: 20,
            processIdentity: .init(pid: 42, startedAt: 11),
            sessionID: replacement, requiresRuntimeStatus: true
        )
        XCTAssertTrue(ItermStore.reconciledCodexBindings(
            ["tty": old], observations: ["tty": observation], identities: ["tty": "new-pane"],
            terminalThreadPrefixes: ["tty": replacement]
        ).isEmpty)
        XCTAssertTrue(ItermStore.reconciledCodexBindings(
            ["tty": old], observations: ["tty": observation], identities: [:]
        ).isEmpty)
    }

    func testManualCodexBindingRemainsAnOverrideAndFinalReadKeepsItsAssociation() {
        let thread = "11111111-2222-3333-4444-555555555555"
        let process = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 10)
        let manual = ItermStore.CodexThreadBinding(
            terminalSessionID: "manual-pane", processIdentity: process, threadID: thread
        )
        let shared = CodexSessionObservation(
            status: .running, changedAt: 20, processIdentity: process,
            sessionID: thread, requiresRuntimeStatus: true
        )
        let bindings = ItermStore.reconciledCodexBindings(
            ["manual": manual], observations: ["manual": shared, "auto": shared],
            identities: ["manual": "manual-pane", "auto": "auto-pane"]
        )
        XCTAssertEqual(bindings, ["manual": manual])
        let automatic = ItermStore.CodexThreadBinding(
            terminalSessionID: "pane", processIdentity: process, threadID: thread, isManual: false
        )
        let stopped = CodexSessionObservation(
            status: .interrupted, changedAt: 21, processIdentity: process,
            sessionID: thread, isProcessAlive: false, requiresRuntimeStatus: true
        )
        XCTAssertEqual(ItermStore.reconciledCodexBindings(
            ["tty": automatic], observations: ["tty": stopped], identities: ["tty": "pane"],
            terminalThreadPrefixes: ["tty": thread]
        )["tty"], automatic)
        XCTAssertTrue(ItermStore.reconciledCodexBindings(
            [:], observations: ["tty": stopped], identities: ["tty": "pane"]
        ).isEmpty)
    }

    func testUnknownCodexRuntimePreservesTheAutomaticRolloutStateAndTitle() {
        let process = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 10)
        let completion = SessionCompletion(id: "done", completedAt: 20, exitStatus: 0)
        let native = CodexSessionObservation(
            status: .finished, changedAt: 20, processIdentity: process,
            titleExcerpt: "current conversation", sessionID: "thread", latestCompletion: completion,
            recentCompletions: [completion], requiresRuntimeStatus: true
        )
        let unknown = CodexSessionObservation(
            status: nil, changedAt: nil, processIdentity: process, titleExcerpt: "older excerpt", sessionID: "thread"
        )
        let merged = ItermStore.mergingCodexRuntimeObservation(
            .init(observation: unknown, sampledFrom: native), into: native
        )
        XCTAssertEqual(merged, native)
    }

    func testCodexRuntimeWaitingOverlayAppliesOnlyToTheSampledTurn() {
        let process = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 10)
        func running(turn: String, excerpt: String = "current conversation") -> CodexSessionObservation {
            CodexSessionObservation(
                status: .running, changedAt: 20, processIdentity: process,
                titleExcerpt: excerpt, sessionID: "thread", completionInProgressID: turn,
                requiresRuntimeStatus: true
            )
        }
        let native = running(turn: "turn-one")
        let waiting = CodexSessionObservation(
            status: .awaitingInput, changedAt: nil, processIdentity: process,
            sessionID: "thread", completionInProgressID: "turn-one"
        )
        let overlay = ItermStore.CodexRuntimeOverlay(observation: waiting, sampledFrom: native)
        XCTAssertEqual(ItermStore.mergingCodexRuntimeObservation(overlay, into: native).status, .awaitingInput)
        let updatedText = running(turn: "turn-one", excerpt: "new conversation text")
        XCTAssertEqual(ItermStore.mergingCodexRuntimeObservation(overlay, into: updatedText).titleExcerpt,
                       "new conversation text")
        let nextTurn = running(turn: "turn-two")
        XCTAssertEqual(ItermStore.mergingCodexRuntimeObservation(overlay, into: nextTurn), nextTurn)
        let completion = SessionCompletion(id: "turn-one", completedAt: 21, exitStatus: 0)
        let finished = CodexSessionObservation(
            status: .finished, changedAt: 21, processIdentity: process,
            sessionID: "thread", latestCompletion: completion, recentCompletions: [completion]
        )
        XCTAssertEqual(ItermStore.mergingCodexRuntimeObservation(overlay, into: finished), finished)
    }

    func testCodexRuntimeOverlayCannotCrossThreadProcessOrExit() {
        let process = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 10)
        let baseline = CodexSessionObservation(
            status: .running, changedAt: 20, processIdentity: process, sessionID: "thread"
        )
        let runtime = CodexSessionObservation(
            status: .awaitingInput, changedAt: nil, processIdentity: process, sessionID: "thread"
        )
        let overlay = ItermStore.CodexRuntimeOverlay(observation: runtime, sampledFrom: baseline)
        for replacement in [
            CodexSessionObservation(status: .running, changedAt: 20, processIdentity: process, sessionID: "new-thread"),
            CodexSessionObservation(status: .running, changedAt: 20,
                                    processIdentity: .init(pid: 42, startedAt: 11), sessionID: "thread"),
            CodexSessionObservation(status: .running, changedAt: 20, processIdentity: process,
                                    sessionID: "thread", isProcessAlive: false),
        ] {
            XCTAssertEqual(ItermStore.mergingCodexRuntimeObservation(overlay, into: replacement), replacement)
        }
    }

    func testOlderCodexRuntimeCompletionDoesNotReplaceANewerRunningTurn() {
        let process = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 10)
        let native = CodexSessionObservation(
            status: .running, changedAt: 20.8, processIdentity: process,
            sessionID: "thread", completionInProgressID: "new-turn"
        )
        let completion = SessionCompletion(id: "old-turn", completedAt: 20, exitStatus: 0)
        let runtime = CodexSessionObservation(
            status: .finished, changedAt: 20, processIdentity: process,
            sessionID: "thread", latestCompletion: completion, recentCompletions: [completion]
        )
        let merged = ItermStore.mergingCodexRuntimeObservation(
            .init(observation: runtime, sampledFrom: native), into: native
        )
        XCTAssertEqual(merged.status, .running)
        XCTAssertEqual(merged.completionInProgressID, "new-turn")
        XCTAssertEqual(merged.recentCompletions, [completion])
    }

    func testCodexRuntimeHistoryAugmentsTheLongerRolloutWindow() {
        let process = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 10)
        let older = SessionCompletion(id: "older", completedAt: 18, exitStatus: 0)
        let nativeLast = SessionCompletion(id: "native", completedAt: 19, exitStatus: nil)
        let completed = SessionCompletion(id: "native", completedAt: 19, exitStatus: 0)
        let newest = SessionCompletion(id: "new", completedAt: 20, exitStatus: 1)
        let native = CodexSessionObservation(
            status: nil, changedAt: nil, processIdentity: process, sessionID: "thread",
            latestCompletion: nativeLast, recentCompletions: [older, nativeLast]
        )
        let runtime = CodexSessionObservation(
            status: nil, changedAt: nil, processIdentity: process, titleExcerpt: "daemon excerpt", sessionID: "thread",
            latestCompletion: newest, recentCompletions: [completed, newest]
        )
        let merged = ItermStore.mergingCodexRuntimeObservation(
            .init(observation: runtime, sampledFrom: native), into: native
        )
        XCTAssertEqual(merged.recentCompletions, [older, completed, newest])
        XCTAssertEqual(merged.latestCompletion, newest)
        XCTAssertEqual(merged.titleExcerpt, "daemon excerpt")
    }

    func testCodexRuntimeKeepsRolloutCompletionPrecisionAndViewedAcknowledgement() throws {
        let process = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 10)
        let completion = SessionCompletion(id: "turn", completedAt: 20.9, exitStatus: 0)
        let native = CodexSessionObservation(
            status: .finished, changedAt: 20.9, processIdentity: process, sessionID: "thread",
            latestCompletion: completion, recentCompletions: [completion]
        )
        let rounded = SessionCompletion(id: "turn", completedAt: 20, exitStatus: 0)
        let runtime = CodexSessionObservation(
            status: .finished, changedAt: 20, processIdentity: process, sessionID: "thread",
            latestCompletion: rounded, recentCompletions: [rounded]
        )
        let merged = ItermStore.mergingCodexRuntimeObservation(
            .init(observation: runtime, sampledFrom: native), into: native
        )
        XCTAssertEqual(merged.latestCompletion, completion)
        XCTAssertEqual(merged.changedAt, 20.9)
        let acknowledgement = try XCTUnwrap(ItermStore.CodexCompletionAcknowledgement(
            observation: native, sessionID: "pane"
        ))
        XCTAssertEqual(ItermStore.CodexCompletionAcknowledgement(observation: merged, sessionID: "pane"),
                       acknowledgement)
    }

    func testCodexThreadTitleHintDecodesAndSurvivesAgentOverlay() throws {
        let session = try JSONDecoder().decode(TerminalSessionSnapshot.self, from: Data("""
        {"id":"pane","name":"codex","tty":"tty","isActive":true,"codexThreadIDPrefix":"12345678"}
        """.utf8))
        let merged = ItermStore.mergingCodexObservation(
            .init(status: .running, changedAt: 20), into: session
        )
        XCTAssertEqual(merged.codexThreadIDPrefix, "12345678")
        let windows = try JSONDecoder().decode([TerminalWindowSnapshot].self, from: Data("""
        [{"id":"w","number":1,"isActive":true,"tabs":[
          {"id":"t","title":"Terminal","isSelected":true,"sessions":[
            {"id":"one","name":"codex","tty":"ambiguous","isActive":false,"codexThreadIDPrefix":"12345678"},
            {"id":"two","name":"codex","tty":"ambiguous","isActive":false,"codexThreadIDPrefix":"87654321"},
            {"id":"new","name":"codex","tty":"new","isActive":true,"codexThreadIDPrefix":""}]}]}]
        """.utf8))
        XCTAssertEqual(ItermStore.codexThreadPrefixesByTTY(in: windows), ["new": ""])
    }

    func testCodexOverlayCountsAsRunningAgent() {
        let session = TerminalSessionSnapshot(
            id: "session",
            name: "codex",
            path: nil,
            tty: "/dev/ttys001",
            windowId: "window",
            tabId: "tab",
            isActive: true,
            isMinimized: false,
            status: nil,
            activityKind: nil,
            exitStatus: nil,
            statusChangedAt: nil
        )
        let overlaid = ItermStore.mergingCodexObservation(
            CodexSessionObservation(status: .running, changedAt: 42),
            into: session
        )
        let windows = [TerminalWindowSnapshot(
            id: "window",
            number: 1,
            isActive: true,
            tabs: [TerminalTabSnapshot(
                id: "tab",
                title: "Codex",
                isSelected: true,
                sessions: [overlaid]
            )]
        )]

        XCTAssertEqual(ItermStore.runningAgentCount(in: windows), 1)
    }

    func testViewedCodexCompletionStaysIdleOnlyForTheSameTurnAndIdentity() throws {
        let session = try JSONDecoder().decode(TerminalSessionSnapshot.self, from: Data("""
        {"id":"pane","name":"codex","tty":"/dev/ttys001","isActive":true}
        """.utf8))
        let identity = CodexSessionMonitor.ProcessIdentity(pid: 123, startedAt: 10)
        let finished = CodexSessionObservation(
            status: .finished, changedAt: 42, processIdentity: identity
        )
        let acknowledgement = try XCTUnwrap(ItermStore.CodexCompletionAcknowledgement(
            observation: finished, sessionID: session.id
        ))
        let viewed = ItermStore.mergingCodexObservation(
            finished, acknowledgement: acknowledgement, into: session
        )
        XCTAssertEqual(viewed.status, .idle)
        XCTAssertEqual(viewed.agentKind, .codex)
        XCTAssertEqual(viewed.activityKind, .agent)
        XCTAssertNil(viewed.exitStatus)
        XCTAssertEqual(viewed.statusChangedAt, 42)
        XCTAssertEqual(ItermStore.mergingCodexObservation(finished, into: session).status, .finished)

        for observation in [
            CodexSessionObservation(status: .finished, changedAt: 43, processIdentity: identity),
            CodexSessionObservation(status: .finished, changedAt: 42,
                                    processIdentity: .init(pid: 123, startedAt: 11)),
            CodexSessionObservation(status: .finished, changedAt: 42, processIdentity: identity, sessionID: "new-thread"),
            CodexSessionObservation(status: .running, changedAt: 43, processIdentity: identity),
            CodexSessionObservation(status: .awaitingInput, changedAt: 42, processIdentity: identity),
            CodexSessionObservation(status: .interrupted, changedAt: 42, processIdentity: identity),
            CodexSessionObservation(status: nil, changedAt: nil, processIdentity: identity),
        ] {
            XCTAssertEqual(ItermStore.mergingCodexObservation(
                observation, acknowledgement: acknowledgement, into: session
            ).status, observation.status)
        }
        let anotherSession = try JSONDecoder().decode(TerminalSessionSnapshot.self, from: Data("""
        {"id":"replacement","name":"codex","tty":"/dev/ttys001","isActive":true}
        """.utf8))
        XCTAssertEqual(ItermStore.mergingCodexObservation(
            finished, acknowledgement: acknowledgement, into: anotherSession
        ).status, .finished)
        XCTAssertNil(ItermStore.CodexCompletionAcknowledgement(
            observation: .init(status: .awaitingInput, changedAt: 42, processIdentity: identity),
            sessionID: session.id
        ))
        XCTAssertNil(ItermStore.CodexCompletionAcknowledgement(
            observation: .init(status: .finished, changedAt: nil, processIdentity: identity),
            sessionID: session.id
        ))
    }

    func testCodexFocusRequiresForegroundWindowSelectedTabAndActiveSession() throws {
        let windows = try JSONDecoder().decode([TerminalWindowSnapshot].self, from: Data("""
        [{"id":"background","number":1,"isActive":false,"tabs":[
          {"id":"background-tab","title":"Background","isSelected":true,"sessions":[
            {"id":"background-pane","name":"codex","isActive":true}]}]},
         {"id":"foreground","number":2,"isActive":true,"tabs":[
          {"id":"hidden-tab","title":"Hidden","isSelected":false,"sessions":[
            {"id":"hidden-pane","name":"codex","isActive":true}]},
          {"id":"visible-tab","title":"Visible","isSelected":true,"sessions":[
            {"id":"other-split","name":"codex","isActive":false},
            {"id":"visible-pane","name":"codex","isActive":true}]}]}]
        """.utf8))
        XCTAssertNil(ItermStore.focusedCodexSession(in: windows, isFrontmost: false))
        XCTAssertEqual(ItermStore.focusedCodexSession(in: windows, isFrontmost: true)?.id, "visible-pane")
    }

    func testCodexTitleOverlayChangesOnlyTheDisplayedSessionName() {
        let session = TerminalSessionSnapshot(
            id: "session",
            name: "zsh",
            path: "/tmp/project",
            tty: "/dev/ttys001",
            windowId: "window",
            tabId: "tab",
            isActive: true,
            isMinimized: false,
            status: nil,
            activityKind: .command,
            exitStatus: nil,
            statusChangedAt: nil
        )

        let overlaid = ItermStore.mergingCodexObservation(
            CodexSessionObservation(status: .finished, changedAt: 42),
            title: "修复Codex会话标题",
            into: session
        )

        XCTAssertEqual(overlaid.name, "修复Codex会话标题")
        XCTAssertEqual(overlaid.path, session.path)
        XCTAssertEqual(overlaid.id, session.id)
        XCTAssertEqual(overlaid.agentKind, .codex)
    }

    @MainActor
    func testRunningCodexManualTitleRefreshKeepsReplacementRequestOwnership() async throws {
        let suite = "iTermate-title-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var continuations: [CheckedContinuation<String, Error>] = []
        let store = ItermStore(titleDefaults: defaults, generateCodexTitle: { _ in
            try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
            }
        })
        defer { store.stop() }
        let identity = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 42)
        let session = TerminalSessionSnapshot(
            id: "session",
            name: "zsh",
            path: "/tmp/project",
            tty: "/dev/ttys001",
            windowId: "window",
            tabId: "tab",
            isActive: true,
            isMinimized: false,
            status: .running,
            activityKind: .agent,
            exitStatus: nil,
            statusChangedAt: 42,
            agentKind: .codex
        )
        store.prepareCodexTitleRefreshForTesting(
            session,
            observation: CodexSessionObservation(
                status: .running,
                changedAt: 42,
                processIdentity: identity,
                titleExcerpt: "[user]\n刷新标题", sessionID: "thread-one"
            )
        )

        store.refreshCodexTitle(session)
        for _ in 0..<100 where continuations.count < 1 { await Task.yield() }
        XCTAssertEqual(continuations.count, 1)
        guard continuations.count == 1 else { return }
        store.refreshCodexTitle(session)
        for _ in 0..<100 where continuations.count < 2 { await Task.yield() }
        XCTAssertEqual(continuations.count, 2)
        guard continuations.count == 2 else { return }
        continuations[0].resume(returning: "旧标题")
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(store.codexTitleForTesting(session))
        XCTAssertTrue(store.isRefreshingCodexTitle(session))

        continuations[1].resume(returning: "新标题")
        for _ in 0..<100 where store.codexTitleForTesting(session) == nil { await Task.yield() }
        XCTAssertEqual(store.codexTitleForTesting(session), "新标题")
    }

    @MainActor
    func testCodexTitleResultCannotPublishOrCacheAfterNativeThreadHintChanges() async throws {
        for replacementPrefix: String? in ["new-thread-prefix", "", nil] {
            let suite = "iTermate-title-\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            var pending: CheckedContinuation<String, Error>?
            let store = ItermStore(titleDefaults: defaults, generateCodexTitle: { _ in
                try await withCheckedThrowingContinuation { pending = $0 }
            })
            defer { store.stop() }
            var session = titleFixtureSession()
            session.codexThreadIDPrefix = "old-thread-prefix"
            store.prepareCodexTitleRefreshForTesting(session, observation: CodexSessionObservation(
                status: .finished, changedAt: 20, processIdentity: .init(pid: 42, startedAt: 10),
                titleExcerpt: "old conversation", sessionID: "old-thread"
            ))
            store.refreshCodexTitle(session)
            for _ in 0..<100 where pending == nil { await Task.yield() }
            let continuation = try XCTUnwrap(pending)
            // The accepted observation still belongs to the old scan while the Bridge has a newer hint.
            session.codexThreadIDPrefix = replacementPrefix
            store.replaceCodexTerminalSnapshotForTesting(session)
            continuation.resume(returning: "旧对话标题")
            for _ in 0..<100 where store.isRefreshingCodexTitle(session) { await Task.yield() }
            XCTAssertNil(store.codexTitleForTesting(session))
            XCTAssertNil(defaults.data(forKey: "codexSessionTitles"))
        }
    }

    @MainActor
    func testCodexTitleSurvivesAppRelaunchWithBackfillDisabled() async throws {
        let suite = "iTermate-title-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = titleFixtureSession()
        let identity = CodexSessionMonitor.ProcessIdentity(pid: 42, startedAt: 100)
        let observation = CodexSessionObservation(status: .finished, changedAt: 1,
            processIdentity: identity, titleExcerpt: "[user]\n修复分页", sessionID: "thread-one")
        let first = ItermStore(titleDefaults: defaults, generateCodexTitle: { _ in "修复分页" })
        first.prepareCodexTitleRefreshForTesting(session, observation: observation)
        first.refreshCodexTitle(session)
        for _ in 0..<100 where first.isRefreshingCodexTitle(session) { await Task.yield() }
        XCTAssertEqual(first.codexTitleForTesting(session), "修复分页")
        first.stop()

        var calls = 0
        let reopened = ItermStore(titleDefaults: defaults, fillsMissingTitles: { false }, generateCodexTitle: { _ in
            calls += 1
            return "不应生成"
        })
        defer { reopened.stop() }
        reopened.prepareCodexTitleRefreshForTesting(session, observation: CodexSessionObservation(
            status: .running, changedAt: 2, processIdentity: identity, sessionID: "thread-one"
        ))
        reopened.scheduleCodexTitlesForTesting()
        XCTAssertEqual(reopened.codexTitleForTesting(session), "修复分页")
        XCTAssertEqual(calls, 0)

        let reused = ItermStore(titleDefaults: defaults, fillsMissingTitles: { false })
        defer { reused.stop() }
        reused.prepareCodexTitleRefreshForTesting(session, observation: CodexSessionObservation(
            status: .finished, changedAt: 2,
            processIdentity: .init(pid: 42, startedAt: 101), titleExcerpt: observation.titleExcerpt
        ))
        reused.scheduleCodexTitlesForTesting()
        XCTAssertNil(reused.codexTitleForTesting(session))

        let switchedThread = ItermStore(titleDefaults: defaults, fillsMissingTitles: { false })
        defer { switchedThread.stop() }
        switchedThread.prepareCodexTitleRefreshForTesting(session, observation: CodexSessionObservation(
            status: .running, changedAt: 2, processIdentity: identity, sessionID: "thread-two"
        ))
        switchedThread.scheduleCodexTitlesForTesting()
        XCTAssertNil(switchedThread.codexTitleForTesting(session))
    }

    @MainActor
    func testMissingCodexTitleBackfillHonorsPreferenceAndPreservesExistingTitle() async throws {
        let suite = "iTermate-title-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var enabled = false
        var calls = 0
        let store = ItermStore(titleDefaults: defaults, fillsMissingTitles: { enabled }, generateCodexTitle: { _ in
            calls += 1
            return "补全标题"
        })
        defer { store.stop() }
        let session = titleFixtureSession()
        let identity = CodexSessionMonitor.ProcessIdentity(pid: 43, startedAt: 100)
        store.prepareCodexTitleRefreshForTesting(session, observation: CodexSessionObservation(
            status: .idle, changedAt: 1, processIdentity: identity, titleExcerpt: "[user]\n修复分页", sessionID: "thread-one"
        ))
        store.scheduleCodexTitlesForTesting()
        XCTAssertFalse(store.isRefreshingCodexTitle(session))
        enabled = true
        store.scheduleCodexTitlesForTesting()
        store.scheduleCodexTitlesForTesting()
        for _ in 0..<100 where store.isRefreshingCodexTitle(session) { await Task.yield() }
        XCTAssertEqual(store.codexTitleForTesting(session), "补全标题")
        XCTAssertEqual(calls, 1)
        store.prepareCodexTitleRefreshForTesting(session, observation: CodexSessionObservation(
            status: .idle, changedAt: 1, processIdentity: identity, titleExcerpt: "[user]\n新的对话", sessionID: "thread-one"
        ))
        store.scheduleCodexTitlesForTesting()
        XCTAssertFalse(store.isRefreshingCodexTitle(session))
        XCTAssertEqual(store.codexTitleForTesting(session), "补全标题")
    }

    @MainActor
    func testMissingCodexTitleBackfillWorksWithUnknownOrRunningStatus() async throws {
        for status: TerminalSessionStatus? in [nil, .running] {
            let suite = "iTermate-title-\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            var enabled = false
            var calls = 0
            let store = ItermStore(titleDefaults: defaults, fillsMissingTitles: { enabled }, generateCodexTitle: { _ in
                calls += 1
                return "恢复任务标题"
            })
            defer { store.stop() }
            let session = titleFixtureSession()
            store.prepareCodexTitleRefreshForTesting(session, observation: CodexSessionObservation(
                status: status, changedAt: nil, processIdentity: .init(pid: 44, startedAt: 100),
                titleExcerpt: "[user]\n修复分页", sessionID: "thread-one"
            ))
            store.scheduleCodexTitlesForTesting()
            XCTAssertFalse(store.isRefreshingCodexTitle(session))
            enabled = true
            store.scheduleCodexTitlesForTesting()
            for _ in 0..<100 where store.isRefreshingCodexTitle(session) { await Task.yield() }
            XCTAssertEqual(store.codexTitleForTesting(session), "恢复任务标题")
            XCTAssertEqual(calls, 1)
            store.scheduleCodexTitlesForTesting()
            XCTAssertFalse(store.isRefreshingCodexTitle(session))
        }
    }

    @MainActor
    func testTitlePreferencePersistsAndDoesNotOverwriteStaleModelSelection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = LocalLLMService(directory: directory)
        let stale = LocalLLMService(directory: directory)
        XCTAssertTrue(first.autoFillMissingTitles)
        first.setAutoFillMissingTitles(false)
        stale.selectModel(.fourB)
        let reopened = LocalLLMService(directory: directory)
        XCTAssertFalse(reopened.autoFillMissingTitles)
        XCTAssertEqual(reopened.selectedModel, .fourB)
        first.setAutoFillMissingTitles(true)
        XCTAssertEqual(LocalLLMService(directory: directory).selectedModel, .fourB)
        XCTAssertTrue(LocalLLMService.fillsMissingTitles(directory: directory))

        let file = directory.appendingPathComponent("configuration.json")
        let invalid = Data("invalid configuration".utf8)
        try invalid.write(to: file)
        first.setAutoFillMissingTitles(false)
        stale.selectModel(.twoB)
        XCTAssertEqual(try Data(contentsOf: file), invalid)
        XCTAssertFalse(LocalLLMService.fillsMissingTitles(directory: directory))
        XCTAssertTrue(first.configurationNeedsRepair)
        first.repairConfiguration()
        XCTAssertFalse(first.configurationNeedsRepair)
        XCTAssertEqual(first.selectedModel, .twoB)
        XCTAssertFalse(first.autoFillMissingTitles)
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("configuration-invalid-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), invalid)
    }

    private func titleFixtureSession() -> TerminalSessionSnapshot {
        TerminalSessionSnapshot(id: "title-pane", name: "zsh", path: "/tmp/project", tty: "/dev/title-test",
            windowId: "window", tabId: "tab", isActive: false, isMinimized: false,
            status: .idle, activityKind: .agent, exitStatus: nil, statusChangedAt: nil, agentKind: .codex)
    }

    func testDecodesEnvironmentIdentityWithoutInferringFromTitle() throws {
        for kind in ["pi", "codex", "unknown"] {
            let data = Data("""
            {"id":"pane","name":"a different Agent name","isActive":true,"agentKind":"\(kind)"}
            """.utf8)
            let session = try JSONDecoder().decode(TerminalSessionSnapshot.self, from: data)
            XCTAssertEqual(session.environmentAgentKind?.rawValue, kind)
            XCTAssertNil(session.status)
        }
        let shell = try JSONDecoder().decode(TerminalSessionSnapshot.self, from: Data("""
        {"id":"pane","name":"Pi Codex","isActive":false}
        """.utf8))
        XCTAssertNil(shell.environmentAgentKind)
        let legacyAgent = try JSONDecoder().decode(TerminalSessionSnapshot.self, from: Data("""
        {"id":"pane","name":"codex","isActive":false,"activityKind":"agent","status":"idle"}
        """.utf8))
        XCTAssertEqual(legacyAgent.environmentAgentKind, .unknown)
        XCTAssertEqual(legacyAgent.environmentAgentKind?.displayName, "Unknown Agent")
        XCTAssertEqual(SessionAgentKind.pi.displayName, "Pi")
        XCTAssertEqual(SessionAgentKind.codex.displayName, "Codex")
    }

    func testOnlyRecognizesIterm2() {
        XCTAssertEqual(TerminalApp(bundleIdentifier: "com.googlecode.iterm2"), .iTerm2)
        XCTAssertNil(TerminalApp(bundleIdentifier: "org.example.terminal"))
    }

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
                    "activityKind": "agent",
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
            message.windows?.first?.tabs.first?.sessions.first?.activityKind,
            .agent
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

    func testMapsSessionStatusAnimationsByActivityKindAndResult() {
        func animation(
            kind: SessionActivityKind,
            status: TerminalSessionStatus,
            exitStatus: Int? = nil
        ) -> SessionStatusAnimation? {
            SessionStatusAnimation(
                session: TerminalSessionSnapshot(
                    id: "session",
                    name: "Session",
                    path: nil,
                    tty: nil,
                    windowId: "window",
                    tabId: "tab",
                    isActive: false,
                    isMinimized: false,
                    status: status,
                    activityKind: kind,
                    exitStatus: exitStatus,
                    statusChangedAt: nil
                )
            )
        }

        XCTAssertEqual(animation(kind: .agent, status: .running), .agentRunning)
        XCTAssertEqual(animation(kind: .command, status: .running), .commandRunning)
        XCTAssertEqual(
            animation(kind: .agent, status: .finished, exitStatus: 0),
            .agentSucceeded
        )
        XCTAssertEqual(
            animation(kind: .agent, status: .finished, exitStatus: 1),
            .agentFailed
        )
        XCTAssertEqual(
            animation(kind: .command, status: .finished, exitStatus: 0),
            .commandSucceeded
        )
        XCTAssertEqual(
            animation(kind: .command, status: .finished, exitStatus: 1),
            .commandFailed
        )
        XCTAssertEqual(
            animation(kind: .command, status: .finished),
            .commandFinished
        )
    }

    @MainActor
    func testPanelResizeKeepsStatusAnimationScopedToEachSession() throws {
        let configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("config.toml")
        defer {
            try? FileManager.default.removeItem(
                at: configURL.deletingLastPathComponent()
            )
        }

        let store = ItermStore()
        store.apply(try hello())
        store.apply(try hierarchyMessage())
        let panel = ComradePanel(
            store: store,
            settings: AppSettings(configURL: configURL)
        )

        for height in [500, 120, 500] {
            panel.setFrame(
                CGRect(x: 20, y: 20, width: 320, height: height),
                display: true
            )
            panel.contentView?.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }

        let animations = statusAnimations(in: try XCTUnwrap(panel.contentView))
        XCTAssertEqual(animations.count, 2)
        XCTAssertEqual(animations.filter { $0 == .agentRunning }.count, 1)
        XCTAssertEqual(animations.filter { $0 == .commandSucceeded }.count, 1)
    }

    func testSessionStatusPixelColorsStayOpaqueAndBrighten() throws {
        for animation in SessionStatusAnimation.allCases {
            let base = try XCTUnwrap(
                animation.pixelColor(brightness: 0.35).usingColorSpace(.deviceRGB)
            )
            let highlight = try XCTUnwrap(
                animation.pixelColor(brightness: 1).usingColorSpace(.deviceRGB)
            )

            XCTAssertEqual(base.alphaComponent, 1, accuracy: 0.001)
            XCTAssertEqual(highlight.alphaComponent, 1, accuracy: 0.001)
            XCTAssertGreaterThan(
                highlight.redComponent
                    + highlight.greenComponent
                    + highlight.blueComponent,
                base.redComponent + base.greenComponent + base.blueComponent,
                "\(animation)"
            )
        }
    }

    func testEverySessionStatusAnimationKeepsPixelsVisibleAndChangesFrames() {
        var signatures = Set<[CGFloat]>()

        for animation in SessionStatusAnimation.allCases where animation.isAnimated {
            let frames = (0..<24).map { frame in
                (0..<8).flatMap { row in
                    (0..<18).map {
                        animation.brightness(column: $0, row: row, frame: frame)
                    }
                }
            }

            XCTAssertTrue(
                frames.allSatisfy { $0.contains { $0 > 0 } },
                "\(animation)"
            )
            XCTAssertGreaterThan(Set(frames).count, 1, "\(animation)")
            XCTAssertTrue(
                signatures.insert(frames.flatMap { $0 }).inserted,
                "\(animation)"
            )

            for frame in 0..<24 {
                XCTAssertTrue(
                    (0..<8).contains { row in
                        (0...10).contains {
                            animation.brightness(
                                column: $0,
                                row: row,
                                frame: frame
                            ) > 0
                        }
                    },
                    "\(animation) avatar frame \(frame)"
                )
                XCTAssertTrue(
                    (1...6).contains { row in
                        animation.brightness(
                            column: 14,
                            row: row,
                            frame: frame
                        ) > 0
                    },
                    "\(animation) status bar frame \(frame)"
                )
                XCTAssertTrue(
                    (0..<8).allSatisfy { row in
                        (11...13).allSatisfy {
                            animation.brightness(
                                column: $0,
                                row: row,
                                frame: frame
                            ) == 0
                        }
                    },
                    "\(animation) transparent gap frame \(frame)"
                )
            }
        }
    }

    func testWaitingStylesStayVisibleAndStatic() {
        let animation = SessionStatusAnimation.agentAwaitingInput
        XCTAssertFalse(animation.isAnimated)
        XCTAssertEqual(animation.defaultStyle, .questionMark)
        XCTAssertTrue(SessionStatusAnimation.agentAnimations.contains(animation))
        XCTAssertFalse(SessionStatusAnimation.commandRunning.availableStyles.contains(.questionMark))
        for style in animation.availableStyles {
            let frames = (0..<24).map { frame in
                (0..<8).flatMap { row in
                    (0..<18).map { column in
                        animation.brightness(column: column, row: row, frame: frame, style: style)
                    }
                }
            }
            XCTAssertTrue(frames.allSatisfy { $0.contains { $0 > 0 } }, "\(style)")
            XCTAssertEqual(Set(frames).count, 1, "\(style)")
        }
    }

    func testEveryStatusAnimationStyleKeepsPixelsVisibleAndChangesFrames() {
        for animation in SessionStatusAnimation.allCases where animation.isAnimated {
            for style in animation.availableStyles {
                let frames = (0..<24).map { frame in
                    (0..<8).flatMap { row in
                        (0..<18).map {
                            animation.brightness(
                                column: $0,
                                row: row,
                                frame: frame,
                                style: style
                            )
                        }
                    }
                }

                XCTAssertTrue(
                    frames.allSatisfy { $0.contains { $0 > 0 } },
                    "\(animation) \(style)"
                )
                XCTAssertGreaterThan(
                    Set(frames).count,
                    1,
                    "\(animation) \(style)"
                )
            }
        }
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
        let pinnedPathGroups = SessionGrouping.groups(
            from: windows,
            style: .projectPath,
            pinnedProjectPaths: ["/repo/subdirectory"]
        )

        XCTAssertEqual(windowGroups.map(\.title), ["Window 1", "Window 2"])
        XCTAssertEqual(
            windowGroups[0].sessions.map(\.session.id),
            ["session-1", "session-2"]
        )
        XCTAssertEqual(
            windowGroups[0].sessions.map(\.session.name),
            ["zsh", "build"]
        )
        XCTAssertEqual(windowGroups[0].tabIDs, ["tab-1", "tab-2"])
        XCTAssertEqual(windowGroups[1].tabIDs, ["tab-3"])
        XCTAssertEqual(windowGroups[0].sessions.map(\.tabTitle), ["One", "Two"])
        XCTAssertEqual(
            windowGroups[0].sessions(inTab: "tab-2").map(\.session.id),
            ["session-2"]
        )
        XCTAssertEqual(
            windowGroups[1].sessions(inTab: "tab-3").map(\.session.id),
            ["session-3", "session-4"]
        )

        XCTAssertEqual(
            pathGroups.map(\.title),
            ["/repo", "/repo/subdirectory", "Unknown Path"]
        )
        XCTAssertEqual(
            pathGroups[0].sessions.map(\.session.id),
            ["session-1", "session-3"]
        )
        XCTAssertEqual(pathGroups[2].sessions.map(\.session.id), ["session-4"])
        XCTAssertEqual(
            pinnedPathGroups.map(\.title),
            ["/repo/subdirectory", "/repo", "Unknown Path"]
        )
    }

    func testSeparatesCommandSessionsAfterAgentGroups() throws {
        let groups = SessionGrouping.groups(
            from: try hierarchySnapshot(),
            style: .projectPath,
            separatesCommandSessions: true
        )

        XCTAssertEqual(groups.map(\.title), ["/repo", "Commands"])
        XCTAssertEqual(groups[0].sessions.map(\.session.id), ["session-1"])
        XCTAssertEqual(
            groups[1].sessions.map(\.session.id),
            ["session-3", "session-2", "session-4"]
        )
        XCTAssertEqual(groups[1].tabIDs, ["tab-3", "tab-2"])
    }

    func testCommandSessionsSortByDirectoryAndKeepMatchingPathsTogether() throws {
        let message = try JSONDecoder().decode(
            BridgeMessage.self,
            from: Data(
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
                      "sessions": [
                        {"id":"zeta","name":"zsh","path":"/work/Zeta","isActive":true},
                        {"id":"work-alpha-1","name":"zsh","path":"/work/alpha","isActive":false}
                      ]
                    }, {
                      "id": "tab-2",
                      "title": "Two",
                      "isSelected": false,
                      "sessions": [
                        {"id":"work-alpha-2","name":"zsh","path":"/work/alpha","isActive":true}
                      ]
                    }, {
                      "id": "tab-3",
                      "title": "Three",
                      "isSelected": false,
                      "sessions": [
                        {"id":"other-alpha","name":"zsh","path":"/other/Alpha","isActive":true}
                      ]
                    }]
                  }]
                }
                """.utf8
            )
        )

        let commands = try XCTUnwrap(SessionGrouping.groups(
            from: message.windows ?? [],
            style: .window,
            separatesCommandSessions: true
        ).last)

        XCTAssertEqual(
            commands.sessions.map(\.session.id),
            ["other-alpha", "work-alpha-1", "work-alpha-2", "zeta"]
        )
        XCTAssertEqual(
            commands.blocks(groupedByPath: true).flatMap(\.sessions).map(\.session.id),
            ["other-alpha", "work-alpha-1", "work-alpha-2", "zeta"]
        )
    }

    func testWorkingDirectoryNameUsesFinalPathComponentAndPreservesRoot() throws {
        let directory = try JSONDecoder().decode(
            TerminalSessionSnapshot.self,
            from: Data(#"{"id":"directory","name":"zsh","path":"/Users/test/project","isActive":true}"#.utf8)
        )
        let root = try JSONDecoder().decode(
            TerminalSessionSnapshot.self,
            from: Data(#"{"id":"root","name":"zsh","path":"/","isActive":true}"#.utf8)
        )

        XCTAssertEqual(directory.workingDirectoryName, "project")
        XCTAssertEqual(root.workingDirectoryName, "/")
    }

    func testProjectPathClustersSplitPaneSessionsOfSameTab() throws {
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
                  "title": "Splits",
                  "isSelected": true,
                  "sessions": [{
                    "id": "session-a",
                    "name": "pi one",
                    "path": "/repo",
                    "windowId": "window-1",
                    "tabId": "tab-1",
                    "isActive": true,
                    "isMinimized": false
                  }, {
                    "id": "session-b",
                    "name": "pi two",
                    "path": "/other",
                    "windowId": "window-1",
                    "tabId": "tab-1",
                    "isActive": false,
                    "isMinimized": false
                  }, {
                    "id": "session-c",
                    "name": "pi three",
                    "path": "/repo",
                    "windowId": "window-1",
                    "tabId": "tab-1",
                    "isActive": false,
                    "isMinimized": false
                  }]
                }]
              }]
            }
            """.utf8
        )
        let windows = try JSONDecoder()
            .decode(BridgeMessage.self, from: data).windows ?? []

        let pathGroups = SessionGrouping.groups(from: windows, style: .projectPath)

        XCTAssertEqual(pathGroups.map(\.title), ["/other", "/repo"])
        XCTAssertEqual(
            pathGroups[1].sessions.map(\.session.id),
            ["session-a", "session-c"]
        )
        XCTAssertEqual(pathGroups[1].tabIDs, ["tab-1"])
        XCTAssertEqual(pathGroups[1].sessions(inTab: "tab-1").count, 2)
    }

    func testTabBlocksKeepSplitSessionsTogetherForInterleavedInput() throws {
        let sessions = try hierarchySnapshot().flatMap { $0.tabs.flatMap(\.sessions) }
        let group = SessionListGroup(
            id: "path:/repo",
            title: "/repo",
            sessions: sessions.enumerated().map { index, session in
                SessionListItem(
                    session: session,
                    tabID: index == 1 ? "other-tab" : "split-tab",
                    tabTitle: "Tab",
                    isFocused: false
                )
            }
        )

        XCTAssertEqual(group.tabIDs, ["split-tab", "other-tab"])
        XCTAssertEqual(
            group.tabIDs.flatMap { group.sessions(inTab: $0) }.map(\.id),
            ["session-1", "session-3", "session-4", "session-2"]
        )
    }

    func testManualIdleSurvivesStoreRecreationAndStartupGaps() throws {
        let suite = "iTermateTests.manualIdle.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = ItermStore(statusDefaults: defaults)
        first.apply(try hello())
        first.apply(try manualIdleSnapshot(sequence: 1, status: .awaitingInput))
        first.markSessionIdle(sessionID: "pane")
        XCTAssertEqual(first.windows.first?.tabs.first?.sessions.first?.status, .idle)
        XCTAssertEqual(first.lifecycleWindows.first?.tabs.first?.sessions.first?.status, .awaitingInput)
        first.stop()

        let reopened = ItermStore(statusDefaults: defaults)
        reopened.setActiveTerminalApp(.iTerm2)
        reopened.updateConnectionState(.connecting)
        reopened.apply(try hello())
        reopened.apply(try manualIdleSnapshot(sequence: 1, status: nil))
        XCTAssertNil(reopened.windows.first?.tabs.first?.sessions.first?.status)
        reopened.apply(try manualIdleSnapshot(sequence: 2, status: .awaitingInput))
        XCTAssertEqual(reopened.windows.first?.tabs.first?.sessions.first?.status, .idle)
        XCTAssertEqual(reopened.lifecycleWindows.first?.tabs.first?.sessions.first?.status, .awaitingInput)
    }

    func testManualIdleReleasesForNewActivityAndPersistsRemoval() throws {
        let suite = "iTermateTests.manualIdle.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ItermStore(statusDefaults: defaults)
        store.apply(try hello())
        store.apply(try manualIdleSnapshot(sequence: 1, status: .finished))
        store.markSessionIdle(sessionID: "pane")
        store.apply(try manualIdleSnapshot(sequence: 2, status: .running, changedAt: 21))
        XCTAssertEqual(store.windows.first?.tabs.first?.sessions.first?.status, .running)
        store.markSessionIdle(sessionID: "pane")
        XCTAssertEqual(store.windows.first?.tabs.first?.sessions.first?.status, .running)

        let reopened = ItermStore(statusDefaults: defaults)
        reopened.apply(try hello())
        reopened.apply(try manualIdleSnapshot(sequence: 1, status: .finished))
        XCTAssertEqual(reopened.windows.first?.tabs.first?.sessions.first?.status, .finished)
    }

    func testManualIdleRejectsNewWaitingEventAndRemovedSession() throws {
        let suite = "iTermateTests.manualIdle.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ItermStore(statusDefaults: defaults)
        store.apply(try hello())
        store.apply(try manualIdleSnapshot(sequence: 1, status: .awaitingInput))
        store.markSessionIdle(sessionID: "pane")
        store.apply(try manualIdleSnapshot(sequence: 2, status: .awaitingInput, changedAt: 21))
        XCTAssertEqual(store.windows.first?.tabs.first?.sessions.first?.status, .awaitingInput)
        store.markSessionIdle(sessionID: "pane")
        store.apply(try snapshot(sequence: 3, title: "Empty"))
        let reopened = ItermStore(statusDefaults: defaults)
        reopened.apply(try hello())
        reopened.apply(try manualIdleSnapshot(sequence: 1, status: .awaitingInput, changedAt: 21))
        XCTAssertEqual(reopened.windows.first?.tabs.first?.sessions.first?.status, .awaitingInput)
    }

    func testCodexManualIdleWaitsForMonitorAndRejectsReplacementProcess() throws {
        let suite = "iTermateTests.manualIdle.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let raw = try manualIdleSnapshot(sequence: 1, status: .running, agentKind: nil)
        let session = try XCTUnwrap(raw.windows?.first?.tabs.first?.sessions.first)
        let observed = CodexSessionObservation(
            status: .awaitingInput, changedAt: 20,
            processIdentity: .init(pid: 42, startedAt: 10), sessionID: "thread"
        )
        let first = ItermStore(statusDefaults: defaults)
        first.apply(try hello())
        first.apply(raw)
        first.prepareCodexTitleRefreshForTesting(session, observation: observed)
        first.markSessionIdle(sessionID: "pane")
        XCTAssertEqual(first.windows.first?.tabs.first?.sessions.first?.status, .idle)

        let reopened = ItermStore(statusDefaults: defaults)
        reopened.updateConnectionState(.connecting)
        reopened.apply(try hello())
        reopened.apply(raw)
        XCTAssertEqual(reopened.windows.first?.tabs.first?.sessions.first?.status, .running)
        reopened.prepareCodexTitleRefreshForTesting(session, observation: observed)
        reopened.apply(try manualIdleSnapshot(sequence: 2, status: .running, agentKind: nil))
        XCTAssertEqual(reopened.windows.first?.tabs.first?.sessions.first?.status, .idle)
        reopened.prepareCodexTitleRefreshForTesting(session, observation: CodexSessionObservation(
            status: .awaitingInput, changedAt: 20,
            processIdentity: .init(pid: 42, startedAt: 11), sessionID: "thread"
        ))
        reopened.apply(try manualIdleSnapshot(sequence: 3, status: .running, agentKind: nil))
        XCTAssertEqual(reopened.windows.first?.tabs.first?.sessions.first?.status, .awaitingInput)
    }

    private func manualIdleSnapshot(
        sequence: Int,
        status: TerminalSessionStatus?,
        changedAt: TimeInterval = 20,
        agentKind: SessionAgentKind? = .pi
    ) throws -> BridgeMessage {
        let session = TerminalSessionSnapshot(
            id: "pane", name: "Pi", path: nil, tty: "/dev/ttys001", windowId: "window", tabId: "tab",
            isActive: false, isMinimized: false, status: status, activityKind: agentKind == nil ? .command : .agent,
            exitStatus: status == .finished ? 0 : nil, statusChangedAt: status == nil ? nil : changedAt,
            hasRunningSubagents: false, agentKind: agentKind
        )
        let windows = [TerminalWindowSnapshot(
            id: "window", number: 1, isActive: false,
            tabs: [TerminalTabSnapshot(id: "tab", title: "Pi", isSelected: false, sessions: [session])]
        )]
        let encoded = String(decoding: try JSONEncoder().encode(windows), as: UTF8.self)
        return try JSONDecoder().decode(BridgeMessage.self, from: Data("""
        {"type":"snapshot","sequence":\(sequence),"windows":\(encoded)}
        """.utf8))
    }

    func testStoreIgnoresOlderSnapshots() throws {
        let store = ItermStore()
        store.apply(try hello())
        store.apply(try snapshot(sequence: 2, title: "New"))
        store.apply(try snapshot(sequence: 1, title: "Old"))

        XCTAssertEqual(store.windows.first?.tabs.first?.title, "New")
    }

    func testStoreClearsSessionsWhenBridgeDisconnects() throws {
        let store = ItermStore()
        store.apply(try hello())
        store.apply(try snapshot(sequence: 2, title: "Old"))

        store.updateConnectionState(.disconnected("iTerm2 restarted"))

        XCTAssertTrue(store.windows.isEmpty)

        store.apply(try hello())
        store.apply(try snapshot(sequence: 1, title: "New"))
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
        try hierarchyMessage().windows ?? []
    }

    private func hierarchyMessage() throws -> BridgeMessage {
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
                    "isMinimized": false,
                    "status": "running",
                    "activityKind": "agent"
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
                    "isMinimized": false,
                    "status": "finished",
                    "activityKind": "command",
                    "exitStatus": 0
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
        return try JSONDecoder().decode(BridgeMessage.self, from: data)
    }

    private func statusAnimations(in view: NSView) -> [SessionStatusAnimation] {
        let current = (view as? SessionStatusMatrixView).map { [$0.animation] } ?? []
        return current + view.subviews.flatMap(statusAnimations)
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
