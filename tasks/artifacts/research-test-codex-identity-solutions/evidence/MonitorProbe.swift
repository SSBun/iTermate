import Foundation
import CryptoKit

@main
struct MonitorProbe {
    static func main() {
        let monitor = CodexSessionMonitor()
        while let line = readLine() {
            do {
                let data = Data(line.utf8)
                let request = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                let ttys = Set(request["ttys"] as? [String] ?? [])
                let expected = request["expected"] as? [String: String] ?? [:]
                let prefixes = request["terminalThreadPrefixes"] as? [String: String] ?? [:]
                let observations = monitor.observations(in: ttys, terminalThreadPrefixes: prefixes)
                let rows: [[String: Any]] = ttys.sorted().map { tty in
                    let observation = observations[tty]
                    let expectedID = expected[tty]?.lowercased()
                    let actualID = observation?.sessionID?.lowercased()
                    return [
                        "tty": tty,
                        "detected": observation != nil,
                        "pid": observation?.processIdentity?.pid as Any? ?? NSNull(),
                        "hasThread": actualID != nil,
                        "matchesExpected": actualID == expectedID,
                        "threadHash": actualID.map {
                            SHA256.hash(data: Data($0.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
                        } as Any? ?? NSNull(),
                        "status": observation?.status?.rawValue as Any? ?? NSNull(),
                        "hasTitleExcerpt": observation?.titleExcerpt != nil,
                        "requiresRuntimeStatus": observation?.requiresRuntimeStatus ?? false,
                        "isAlive": observation?.isProcessAlive ?? false
                    ]
                }
                let output = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
                print(String(decoding: output, as: UTF8.self))
                fflush(stdout)
            } catch {
                print("{\"error\":\"invalid_probe_request\"}")
                fflush(stdout)
            }
        }
    }
}
