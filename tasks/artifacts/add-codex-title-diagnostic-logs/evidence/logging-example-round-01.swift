import Foundation

@main
struct LoggingExample {
    @MainActor
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let diagnostics = CodexTitleDiagnostics(directory: directory)
        let request = UUID()
        diagnostics.recordFailure(SessionTitleGenerationError(.tokenLimit), manual: false,
                                  requestID: request, codexPID: 42, attempt: 1)
        diagnostics.recordFailure(SessionTitleGenerationError(.emptyTitle), manual: true,
                                  requestID: UUID(), codexPID: 42, attempt: 1)
        diagnostics.recordFailure(SessionTitleGenerationError(.httpStatus, statusCode: 503), manual: false)
        diagnostics.recordFailure(URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: "PRIVATE_PROMPT_SENTINEL",
                                  NSURLErrorFailingURLErrorKey: URL(fileURLWithPath: "/tmp/PRIVATE_URL_SENTINEL")]),
                                  manual: true)
        diagnostics.recordFailure(NSError(domain: "PRIVATE_DOMAIN_SENTINEL", code: 987,
                                  userInfo: [NSLocalizedDescriptionKey: "PRIVATE_TITLE_SENTINEL"]), manual: false)
        diagnostics.recordFailure(CancellationError(), manual: true)
        diagnostics.recordFailure(SessionTitleGenerationError(.sessionUnavailable), manual: true)
        diagnostics.recordDiscard(manual: false, requestID: UUID(), codexPID: 42)
        print(String(decoding: try Data(contentsOf: directory.appendingPathComponent("codex-titles.log")), as: UTF8.self))
    }
}
