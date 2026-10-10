import Foundation
let ttys = Set(CommandLine.arguments.dropFirst())
let observed = VenomDebugMonitor.monitoringTTYs(in: ttys)
for tty in ttys.sorted() {
    print("\(tty): \(observed.contains(tty) ? "monitoring" : "not monitoring")")
}
