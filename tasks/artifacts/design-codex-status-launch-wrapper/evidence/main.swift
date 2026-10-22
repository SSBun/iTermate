import XCTest
import Darwin

let suite = XCTestSuite(forTestCaseClass: AgentIntegrationManagerTests.self)
suite.run()
guard let result = suite.testRun, result.executionCount == 10 else { exit(2) }
exit(result.totalFailureCount == 0 ? 0 : 1)
