import Foundation
@testable import iTermate

@main
struct TitleExample {
    @MainActor
    static func main() async throws {
        // Calls only the production local model service; never starts NSApplication or a Session.
        let service = LocalLLMService()
        let started = Date()
        let title = try await service.generateSessionTitle(from: """
        [user]
        排查终端会话自动标题因为模型生成预算不足而失败的问题，扩大输出预算。首轮生成内容冗长时再概括一次，最终不要强制字数限制。
        [assistant]
        将保留取消、模型身份和会话所有权保护，不修改其他会话状态。
        [user]
        yes
        """)
        let observation: [String: Any] = [
            "model": service.selectedModel?.rawValue ?? "unavailable",
            "title": title,
            "elapsed_seconds": Date().timeIntervalSince(started),
        ]
        print(String(decoding: try JSONSerialization.data(withJSONObject: observation, options: [.sortedKeys]), as: UTF8.self))
    }
}
