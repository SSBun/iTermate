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

final class LocalLLMSelectionTests: XCTestCase {
    @MainActor
    func testSelectionDefaultsToTwoBAndPersistsFourBWithoutInference() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = LocalLLMService(directory: directory)
        XCTAssertEqual(service.selectedModel, .twoB)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        service.selectModel(.fourB)
        XCTAssertEqual(service.selectedModel, .fourB)
        XCTAssertFalse(service.isBusy)
        XCTAssertFalse(service.isReady)
        XCTAssertEqual(LocalLLMService(directory: directory).selectedModel, .fourB)
        let data = try Data(contentsOf: directory.appendingPathComponent("configuration.json"))
        let configuration = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(configuration["model"], "qwen3.5:4b")
        XCTAssertNotNil(configuration["revision"].flatMap(UUID.init(uuidString:)))
        service.selectModel(.twoB)
        XCTAssertEqual(LocalLLMService(directory: directory).selectedModel, .twoB)
    }

    @MainActor
    func testMalformedSelectionDoesNotFallBackToTwoB() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"model\":\"qwen3.5:4b\"}".utf8).write(to: directory.appendingPathComponent("configuration.json"))
        XCTAssertNil(LocalLLMService(directory: directory).selectedModel)
    }

    func testInventoryIdentitiesNeverSubstituteAnotherModel() {
        let twoB = ["name": "qwen3.5:2b", "digest": LocalDecisionProvider.localLLMRevision]
        let fourB = ["name": "qwen3.5:4b", "digest": String(repeating: "a", count: 64)]
        XCTAssertEqual(LocalLLMModel.twoB.installedRevision(in: [twoB, fourB]), twoB["digest"])
        XCTAssertEqual(LocalLLMModel.fourB.installedRevision(in: [twoB, fourB]), fourB["digest"])
        XCTAssertNil(LocalLLMModel.fourB.installedRevision(in: [twoB]))
        XCTAssertNil(LocalLLMModel.twoB.installedRevision(in: [["name": "qwen3.5:2b", "digest": fourB["digest"] ?? ""]]))
        XCTAssertNil(LocalLLMModel.fourB.installedRevision(in: [["name": "qwen3.5:4b", "digest": "invalid"]]))
    }
}
