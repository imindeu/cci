// Generated using Sourcery 0.15.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import XCTest

@testable import APIConnectTests; @testable import AppTests

extension APIConnectTests {
  static var allTests: [(String, (APIConnectTests) -> () throws -> Void)] = [
    ("testCheckFail", testCheckFail),
    ("testNormalRun", testNormalRun),
    ("testDelayedRun", testDelayedRun),
    ("testDelayedRunWithoutResponseURL", testDelayedRunWithoutResponseURL),
    ("testCheckConfigs", testCheckConfigs)
  ]
}

extension CircleCiTests {
  static var allTests: [(String, (CircleCiTests) -> () throws -> Void)] = [
    ("testTestJob", testTestJob),
    ("testDeployJob", testDeployJob),
    ("testSlackRequest", testSlackRequest),
    ("testApiWithSlack", testApiWithSlack),
    ("testApiWithSlackMessage", testApiWithSlackMessage),
    ("testResponseToSlack", testResponseToSlack)
  ]
}

extension EitherTests {
  static var allTests: [(String, (EitherTests) -> () throws -> Void)] = [
    ("testEither", testEither),
    ("testLeft", testLeft),
    ("testRight", testRight),
    ("testIsLeft", testIsLeft),
    ("testIsRight", testIsRight),
    ("testMap", testMap),
    ("testFlatMap", testFlatMap),
    ("testCodable", testCodable)
  ]
}

extension GithubTests {
  static var allTests: [(String, (GithubTests) -> () throws -> Void)] = [
    ("testVerify", testVerify),
    ("testCheck", testCheck),
    ("testCheckFailure", testCheckFailure),
    ("testType", testType)
  ]
}

extension IOTests {
  static var allTests: [(String, (IOTests) -> () throws -> Void)] = [
    ("testPure", testPure),
    ("testMapEither", testMapEither)
  ]
}

extension RouterGithubToYoutrackTests {
  static var allTests: [(String, (RouterGithubToYoutrackTests) -> () throws -> Void)] = [
    ("testCheckConfigsFail", testCheckConfigsFail),
    ("testCheckConfigs", testCheckConfigs),
    ("testFullRun", testFullRun),
    ("testNoRegexRun", testNoRegexRun),
    ("testEmptyRun", testEmptyRun)
  ]
}

extension RouterSlackToCircleCiTests {
  static var allTests: [(String, (RouterSlackToCircleCiTests) -> () throws -> Void)] = [
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

extension YoutrackTests {
  static var allTests: [(String, (YoutrackTests) -> () throws -> Void)] = [
    ("testGithubRequest", testGithubRequest),
    ("testApiWithGithub", testApiWithGithub),
    ("testApiWithGithubFailure", testApiWithGithubFailure),
    ("testResponseToGithub", testResponseToGithub)
  ]
}

XCTMain([
  testCase(APIConnectTests.allTests),
  testCase(CircleCiTests.allTests),
  testCase(EitherTests.allTests),
  testCase(GithubTests.allTests),
  testCase(IOTests.allTests),
  testCase(RouterGithubToYoutrackTests.allTests),
  testCase(RouterSlackToCircleCiTests.allTests),
  testCase(SlackTests.allTests),
  testCase(YoutrackTests.allTests),
])
