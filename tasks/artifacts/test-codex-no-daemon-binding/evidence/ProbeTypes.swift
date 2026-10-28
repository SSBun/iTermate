import Foundation

enum TerminalSessionStatus: String, Codable {
    case idle, running, awaitingInput, finished, interrupted
}

struct SessionCompletion: Equatable {
    let id: String
    let completedAt: TimeInterval
    let exitStatus: Int?
}
