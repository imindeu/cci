import XCTest
@testable import APIConnectTests
@testable import AppTests

// MARK: - APIConnectTests
extension APIConnectTests {
  static var allTests: [(String, (APIConnectTests) -> () throws -> Void)] = [
    ("testCheckFail", testCheckFail),
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

extension EitherTests {
  static var allTests: [(String, (EitherTests) -> () throws -> Void)] = [
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
extension CircleCiTests {
  static var allTests: [(String, (CircleCiTests) -> () throws -> Void)] = [
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
  testCase(APIConnectTests.allTests),
  testCase(IOTests.allTests),
  testCase(EitherTests.allTests),
  testCase(CircleCiTests.allTests),
  testCase(RouterTests.allTests),
  testCase(SlackTests.allTests)
])
