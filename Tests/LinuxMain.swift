// Generated using Sourcery 0.15.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


import XCTest

@testable import APIConnectTests;@testable import AppTests

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

extension GithubWebhookTests {
  static var allTests: [(String, (GithubWebhookTests) -> () throws -> Void)] = [
    ("testVerify", testVerify),
    ("testCheck", testCheck),
    ("testCheckFailure", testCheckFailure)
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
    ("testGithubWebhookRequest", testGithubWebhookRequest),
    ("testApiWithGithubWebhook", testApiWithGithubWebhook),
    ("testApiWithGithubWebhookFailure", testApiWithGithubWebhookFailure),
    ("testResponseToGithubWebhook", testResponseToGithubWebhook)
  ]
}

XCTMain([
  testCase(APIConnectTests.allTests),
  testCase(CircleCiTests.allTests),
  testCase(EitherTests.allTests),
  testCase(GithubWebhookTests.allTests),
  testCase(IOTests.allTests),
  testCase(RouterGithubToYoutrackTests.allTests),
  testCase(RouterSlackToCircleCiTests.allTests),
  testCase(SlackTests.allTests),
  testCase(YoutrackTests.allTests),
])
