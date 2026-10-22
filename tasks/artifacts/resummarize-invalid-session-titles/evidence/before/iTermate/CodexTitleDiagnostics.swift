import Darwin
import Foundation

/// Identifies a local title failure without carrying prompts or model output.
struct SessionTitleGenerationError: LocalizedError {
    enum Reason: String {
        case noConversation = "no_conversation"
        case sessionUnavailable = "session_unavailable"
        case invalidConfiguration = "invalid_configuration"
        case modelUnavailable = "model_unavailable"
        case modelMismatch = "response_model_mismatch"
        case incompleteResponse = "incomplete_response"
        case tokenLimit = "token_limit"
        case unexpectedFinishReason = "unexpected_finish_reason"
        case missingMessage = "missing_message"
        case unexpectedThinking = "unexpected_thinking"
        case invalidContent = "invalid_content"
        case emptyTitle = "empty_title"
        case modelChanged = "model_changed"
        case httpStatus = "http_status"
        case redirectedResponse = "redirected_response"
        case oversizedResponse = "oversized_response"
        case invalidJSON = "invalid_json"
    }

    let reason: Reason
    let statusCode: Int?

    init(_ reason: Reason, statusCode: Int? = nil) {
        self.reason = reason
        self.statusCode = statusCode
    }

    var errorDescription: String? {
        switch reason {
        case .noConversation: "No conversation is available for a title"
        case .invalidConfiguration: "Invalid model selection"
        case .modelUnavailable: "Selected local model is unavailable"
        case .modelChanged: "Local model changed during title generation"
        case .httpStatus, .redirectedResponse, .oversizedResponse, .invalidJSON:
            "Invalid local model response"
        default: "Invalid local title response"
        }
    }
}

/// Records Codex title failures in a private, bounded pair shared across App launches.
@MainActor
final class CodexTitleDiagnostics {
    static let shared = CodexTitleDiagnostics()

    private let directory: URL
    private let maximumBytes = 1_048_576

    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/iTermate", isDirectory: true)) {
        self.directory = directory
    }

    /// Writes only allowlisted failure metadata; arbitrary error descriptions are never persisted.
    func recordFailure(
        _ error: Error,
        manual: Bool,
        requestID: UUID? = nil,
        codexPID: pid_t? = nil,
        attempt: Int? = nil
    ) {
        var fields: [String: Any] = ["manual": manual]
        let reason: String
        if let failure = error as? SessionTitleGenerationError {
            reason = failure.reason.rawValue
            if let status = failure.statusCode { fields["http_status"] = status }
        } else if error is CancellationError {
            reason = "cancelled"
        } else if (error as NSError).domain == NSURLErrorDomain {
            let code = (error as NSError).code
            reason = code == NSURLErrorTimedOut ? "timeout"
                : code == NSURLErrorCancelled ? "cancelled" : "network"
            fields["network_code"] = code
        } else if error is DecodingError || (error as NSError).domain == NSCocoaErrorDomain {
            reason = "configuration_or_decoding"
            fields["error_code"] = (error as NSError).code
        } else {
            reason = "unknown"
            fields["error_code"] = (error as NSError).code
        }
        if let requestID { fields["request_id"] = requestID.uuidString }
        if let codexPID { fields["codex_pid"] = codexPID }
        if let attempt { fields["attempt"] = attempt }
        append(event: reason == "cancelled" ? "session_title_generation_cancelled" : "session_title_generation_failed",
               reason: reason, fields: fields, level: reason == "cancelled" ? "info" : "error")
    }

    /// Explains a successful model response that was not safe to apply to the current Session.
    func recordDiscard(manual: Bool, requestID: UUID, codexPID: pid_t) {
        append(event: "session_title_result_discarded", reason: "session_identity_or_state_changed",
               fields: ["manual": manual, "request_id": requestID.uuidString, "codex_pid": codexPID],
               level: "info")
    }

    private func append(event: String, reason: String, fields: [String: Any], level: String) {
        do {
            let manager = FileManager.default
            try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
            var directoryInfo = stat()
            guard lstat(directory.path, &directoryInfo) == 0,
                  directoryInfo.st_mode & S_IFMT == S_IFDIR,
                  directoryInfo.st_uid == getuid() else { return }
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

            // A separate, stable lock protects rotation across simultaneous App instances.
            let lock = open(directory.appendingPathComponent("codex-titles.lock").path,
                            O_CREAT | O_WRONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
            guard lock >= 0 else { return }
            defer { close(lock) }
            guard isPrivateRegularFile(lock), flock(lock, LOCK_EX | LOCK_NB) == 0 else { return }
            defer { flock(lock, LOCK_UN) }

            let current = directory.appendingPathComponent("codex-titles.log")
            let previous = directory.appendingPathComponent("codex-titles.previous.log")
            var descriptor = open(current.path, O_CREAT | O_WRONLY | O_APPEND | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
            guard descriptor >= 0 else { return }
            defer { close(descriptor) }
            guard isPrivateRegularFile(descriptor) else { return }
            var info = stat()
            guard fstat(descriptor, &info) == 0 else { return }
            if info.st_size >= maximumBytes {
                guard unlink(previous.path) == 0 || errno == ENOENT else { return }
                try manager.moveItem(at: current, to: previous)
                close(descriptor)
                descriptor = open(current.path, O_CREAT | O_WRONLY | O_APPEND | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
                guard descriptor >= 0, isPrivateRegularFile(descriptor) else { return }
            }

            var record = fields
            record["timestamp"] = ISO8601DateFormatter().string(from: Date())
            record["level"] = level
            record["component"] = "codex"
            record["event"] = event
            record["reason"] = reason
            record["app_pid"] = getpid()
            var data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            data.append(0x0A)
            try FileHandle(fileDescriptor: descriptor, closeOnDealloc: false).write(contentsOf: data)
        } catch {
            // Diagnostics must never alter title generation, fallback, or Session state.
        }
    }

    private func isPrivateRegularFile(_ descriptor: Int32) -> Bool {
        var info = stat()
        return fstat(descriptor, &info) == 0 && info.st_mode & S_IFMT == S_IFREG
            && info.st_uid == getuid() && info.st_nlink == 1 && fchmod(descriptor, 0o600) == 0
    }
}
