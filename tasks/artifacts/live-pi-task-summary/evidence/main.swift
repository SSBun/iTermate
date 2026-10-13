import Foundation
import XCTest

let suite = XCTestSuite(name: "Pi task summary and archive regression")
suite.addTest(XCTestSuite(forTestCaseClass: PiSessionArchiveTests.self))
suite.addTest(XCTestSuite(forTestCaseClass: PiStatusRecoveryTests.self))
suite.run()
guard let result = suite.testRun else { exit(2) }
print("Executed \(result.executionCount) tests, \(result.totalFailureCount) failures")
exit(result.hasSucceeded ? 0 : 1)
