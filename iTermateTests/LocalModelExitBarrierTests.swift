import Darwin
import Foundation
import XCTest
@testable import iTermate

final class LocalModelExitBarrierTests: XCTestCase {
    /// Creates only a test-owned worker, with SIGTERM ignored before announcing readiness.
    private func makeSlowExitingWorker() throws -> Process {
        let child = Process()
        let pipe = Pipe()
        child.executableURL = URL(fileURLWithPath: "/bin/sh")
        child.arguments = ["-c", "trap '' TERM; printf ready; exec /bin/sleep 30"]
        child.standardOutput = pipe
        try child.run()
        XCTAssertEqual(pipe.fileHandleForReading.readData(ofLength: 5), Data("ready".utf8))
        return child
    }

    private func finish(_ child: Process) {
        if child.isRunning { kill(child.processIdentifier, SIGKILL) }
        child.waitUntilExit()
    }

    @MainActor
    func testStopThenSwitchAndStartWaitsForTheTerminatingWorker() async throws {
        let child = try makeSlowExitingWorker()
        defer { finish(child) }
        let barrier = LocalModelExitBarrier()
        barrier.stop(child)
        // A second stop after clearing the service's current-process slot must retain the first worker.
        barrier.stop(nil)
        var passed = false
        let nextStart = Task { @MainActor in
            try await barrier.waitForExit { true }
            passed = true
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(child.isRunning)
        XCTAssertFalse(passed)
        finish(child)
        try await nextStart.value
        XCTAssertTrue(passed)
    }

    @MainActor
    func testCancelledSwitchDoesNotDiscardTheExitBarrierForTheNextStart() async throws {
        let child = try makeSlowExitingWorker()
        defer { finish(child) }
        let barrier = LocalModelExitBarrier()
        barrier.stop(child)
        var current = true
        let cancelledStart = Task { @MainActor in
            try await barrier.waitForExit { current }
        }
        await Task.yield()
        current = false
        do {
            try await cancelledStart.value
            XCTFail("Obsolete start must not pass the barrier")
        } catch is CancellationError {
        }
        XCTAssertTrue(child.isRunning)
        barrier.stop(nil)
        var passed = false
        let nextStart = Task { @MainActor in
            try await barrier.waitForExit { true }
            passed = true
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(passed)
        finish(child)
        try await nextStart.value
        XCTAssertTrue(passed)
    }
}
