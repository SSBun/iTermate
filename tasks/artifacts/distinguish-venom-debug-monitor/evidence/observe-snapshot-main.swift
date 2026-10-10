import Foundation

let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let windows = try JSONDecoder().decode([TerminalWindowSnapshot].self, from: data)
let sessions = windows.flatMap(\.tabs).flatMap(\.sessions)
let ttyCounts = Dictionary(grouping: sessions.compactMap(\.tty), by: { $0 }).mapValues(\.count)
let candidates = sessions.filter {
    $0.status == .running && $0.activityKind == .command
        && $0.tty.map { ttyCounts[$0] == 1 } == true
}
let monitoringTTYs = VenomDebugMonitor.monitoringTTYs(in: Set(candidates.compactMap(\.tty)))
print("Swift decoded sessions: \(sessions.count)")
print("Sessions with real TTY: \(sessions.filter { $0.tty != nil }.count)")
print("Running command candidates with unique TTY: \(candidates.count)")
print("Confirmed monitoring candidates: \(monitoringTTYs.count)")
print("Other running command candidates: \(candidates.count - monitoringTTYs.count)")
for tty in monitoringTTYs.sorted() { print("\(tty): monitoring") }
