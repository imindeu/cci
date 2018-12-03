import XCTest
@testable import APIConnectTests
@testable import AppTests

// MARK: - APIConnectTests
extension APIConnectTests {
  static var allTests: [(String, (APIConnectTests) -> () throws -> Void)] = [
    ("testCheckFail", testTestCheckFail),
    ("testRunWithResponseURL", testRunWithResponseURL),
    ("testRunWithoutResponseURL", testRunWithoutResponseURL),
    ("testCheckConfigs", testCheckConfigs)
  ]
}

extension IOTests {
  static var allTests: [(String, (IOTests) -> () throws -> Void)] = [
    ("testPure", testPure),
    ("testMapEither", testMapEither)
  ]
}

extension PreludeTests {
  static var allTests: [(String, (PreludeTests) -> () throws -> Void)] = [
    ("testEither", testEither),
    ("testLeft", testLeft),
    ("testIsLeft", testIsLeft),
    ("testRight", testRight),
    ("testIsRight", testIsRight),
    ("testMap", testMap),
    ("testFlatMap", testFlatMap)
  ]
}

// MARK: - APPTests
extension CircleciTests {
  static var allTests: [(String, (CircleciTests) -> () throws -> Void)] = [
    ("testTestJob", testTestJob),
    ("testDeployJob", testDeployJob),
    ("testSlackRequest", testSlackRequest),
    ("testApiWithSlack", testApiWithSlack),
    ("testResponseToSlack", testResponseToSlack)
  ]
}

extension RouterTests {
  static var allTests: [(String, (RouterTests) -> () throws -> Void)] = [
    ("testCheckConfigsFail", testCheckConfigsFail),
    ("testCheckConfigs", testCheckConfigs),
    ("testFullRun", testFullRun)
  ]
}

extension SlackTests {
  static var allTests: [(String, (SlackTests) -> () throws -> Void)] = [
    ("testCheck", testCheck),
    ("testApi", testApi),
    ("testInstant", testInstant)
  ]
}

XCTMain([
  testCase(CircleciTests.allTests),
  testCase(CommandTests.allTests),
  testCase(RouterTests.allTests)
])
