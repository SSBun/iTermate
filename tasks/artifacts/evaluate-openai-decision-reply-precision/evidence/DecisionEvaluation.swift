import Foundation
import Security
import CryptoKit

struct ReplySample: Decodable {
    let id: String
    let expected: String
    let text: String
}

final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@main
struct DecisionEvaluation {
    static func main() async throws {
        guard CommandLine.arguments.count == 5, let limit = Int(CommandLine.arguments[4]), limit > 0 else {
            throw NSError(domain: "evaluation_arguments", code: 1)
        }
        let corpusURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let contractURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
        let corpus = try Data(contentsOf: corpusURL)
        let contractBytes = try Data(contentsOf: contractURL)
        guard let contract = try JSONSerialization.jsonObject(with: contractBytes) as? [String: Any],
              let endpointText = contract["endpoint"] as? String,
              endpointText == "https://api.openai.com/v1/decisions", let endpoint = URL(string: endpointText),
              let model = contract["model"] as? String,
              let predicate = contract["predicate"] as? String,
              let threshold = contract["threshold"] as? Double,
              let timeout = contract["timeoutSeconds"] as? Double,
              contract["corpusSHA256"] as? String == digest(corpus) else {
            throw NSError(domain: "evaluation_contract", code: 1)
        }
        let samples = try JSONDecoder().decode([ReplySample].self, from: corpus)
        guard samples.count == 38, Set(samples.map(\.id)).count == samples.count,
              samples.allSatisfy({ ["normal", "question"].contains($0.expected) }) else {
            throw NSError(domain: "evaluation_corpus", code: 1)
        }
        var report: [String: Any] = ["contractSHA256": digest(contractBytes), "rows": [[String: Any]](),
            "transport": "direct_https", "requestsRetried": 0]
        if FileManager.default.fileExists(atPath: outputURL.path) {
            guard let previous = try JSONSerialization.jsonObject(with: Data(contentsOf: outputURL)) as? [String: Any],
                  previous["contractSHA256"] as? String == digest(contractBytes),
                  previous["halted"] as? Bool != true else {
                throw NSError(domain: "evaluation_checkpoint", code: 1)
            }
            report = previous
        }
        var rows = report["rows"] as? [[String: Any]] ?? []
        let completed = Set(rows.compactMap { $0["id"] as? String })
        guard completed.count == rows.count, completed.isSubset(of: Set(samples.map(\.id))) else {
            throw NSError(domain: "evaluation_checkpoint", code: 2)
        }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.caishilin.iTermate.ai", kSecAttrAccount as String: "decision",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]
        var item: CFTypeRef?
        let credentialStatus = SecItemCopyMatching(query as CFDictionary, &item)
        guard credentialStatus == errSecSuccess, let keyData = item as? Data,
              let key = String(data: keyData, encoding: .utf8), !key.isEmpty else {
            report["credentialStatus"] = credentialStatus
            report["halted"] = true
            report["haltReason"] = "decision_credential_unavailable"
            try save(report, to: outputURL)
            print("decision_credential_unavailable; no requests sent in this batch")
            return
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var failuresInARow = 0
        for sample in samples.filter({ !completed.contains($0.id) }).prefix(limit) {
            let start = ProcessInfo.processInfo.systemUptime
            var row: [String: Any] = ["id": sample.id, "expected": sample.expected,
                "startedAt": ISO8601DateFormatter().string(from: Date())]
            var halt = false
            do {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.timeoutInterval = timeout
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: [
                    "model": model, "input": sample.text,
                    "questions": [["type": "predicate", "instructions": predicate]],
                ])
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse, response.url == endpoint else {
                    throw NSError(domain: "invalid_http_response", code: 1)
                }
                row["httpStatus"] = response.statusCode
                guard response.statusCode == 200 else {
                    halt = [400, 401, 403, 404, 429].contains(response.statusCode)
                    throw NSError(domain: "provider_http", code: response.statusCode)
                }
                guard data.count <= 2 * 1024 * 1024,
                      let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let answers = value["answers"] as? [[String: Any]], answers.count == 1,
                      answers[0]["type"] as? String == "predicate",
                      let probability = answers[0]["probability"] as? NSNumber,
                      CFGetTypeID(probability) != CFBooleanGetTypeID(), probability.doubleValue.isFinite,
                      (0...1).contains(probability.doubleValue) else {
                    throw NSError(domain: "invalid_predicate_response", code: 1)
                }
                row["outcome"] = "model_result"
                row["probability"] = probability.doubleValue
                let predicted = probability.doubleValue >= threshold ? "question" : "normal"
                row["predicted"] = predicted
                row["correct"] = predicted == sample.expected
                if let actualModel = value["model"] as? String, actualModel.utf8.count <= 200 {
                    row["reportedModel"] = actualModel
                }
                if let usage = value["usage"] as? [String: Any] {
                    var counts: [String: Int] = [:]
                    for name in ["input_tokens", "output_tokens", "total_tokens"] {
                        if let count = usage[name] as? NSNumber, CFGetTypeID(count) != CFBooleanGetTypeID(),
                           count.doubleValue.isFinite, count.intValue >= 0 { counts[name] = count.intValue }
                    }
                    row["usage"] = counts
                }
                failuresInARow = 0
            } catch {
                let failure = error as NSError
                row["outcome"] = "service_failure"
                row["errorType"] = failure.domain
                row["errorCode"] = failure.code
                failuresInARow += 1
                if failuresInARow >= 3 { halt = true }
            }
            row["elapsedMilliseconds"] = Int((ProcessInfo.processInfo.systemUptime - start) * 1000)
            rows.append(row)
            report["rows"] = rows
            report["requestsAttempted"] = rows.count
            report["updatedAt"] = ISO8601DateFormatter().string(from: Date())
            if halt { report["halted"] = true; report["haltReason"] = "service_failure_requires_attention" }
            try save(report, to: outputURL)
            print(String(data: try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]), encoding: .utf8) ?? "recorded")
            if halt { break }
        }
    }

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func save(_ value: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
    }
}
