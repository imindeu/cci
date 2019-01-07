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
    ("testResponseToSlack", testResponseToSlack),
    ("testGithubRequest", testGithubRequest),
    ("testApiWithGithub", testApiWithGithub),
    ("testResponseToGithub", testResponseToGithub)
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

extension GithubGithubTests {
  static var allTests: [(String, (GithubGithubTests) -> () throws -> Void)] = [
    ("testCheck", testCheck),
    ("testCheckFailure", testCheckFailure),
    ("testType", testType),
    ("testGithubRequestChangesRequested", testGithubRequestChangesRequested),
    ("testFailedStatus", testFailedStatus),
    ("testPullRequestOpened", testPullRequestOpened),
    ("testApiChangesRequested", testApiChangesRequested),
    ("testApiFailedStatus", testApiFailedStatus),
    ("testResponseToGithub", testResponseToGithub)
  ]
}

extension GithubServicesTests {
  static var allTests: [(String, (GithubServicesTests) -> () throws -> Void)] = [
    ("testVerify", testVerify),
    ("testJwt", testJwt),
    ("testAccessToken", testAccessToken)
  ]
}

extension IOTests {
  static var allTests: [(String, (IOTests) -> () throws -> Void)] = [
    ("testPure", testPure),
    ("testMapEither", testMapEither)
  ]
}

extension RouterGithubToCircleCiTests {
  static var allTests: [(String, (RouterGithubToCircleCiTests) -> () throws -> Void)] = [
    ("testCheckConfigsFail", testCheckConfigsFail),
    ("testCheckConfigs", testCheckConfigs),
    ("testFullRun", testFullRun),
    ("testEmptyRun", testEmptyRun)
  ]
}

extension RouterGithubToGithubTests {
  static var allTests: [(String, (RouterGithubToGithubTests) -> () throws -> Void)] = [
    ("testCheckConfigsFail", testCheckConfigsFail),
    ("testCheckConfigs", testCheckConfigs),
    ("testFullRun", testFullRun),
    ("testEmptyRun", testEmptyRun)
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

extension YoutrackGithubTests {
  static var allTests: [(String, (YoutrackGithubTests) -> () throws -> Void)] = [
    ("testGithubRequest", testGithubRequest),
    ("testApiWithGithub", testApiWithGithub),
    ("testApiWithGithubFailure", testApiWithGithubFailure),
    ("testResponseToGithub", testResponseToGithub)
  ]
}

extension YoutrackServicesTests {
  static var allTests: [(String, (YoutrackServicesTests) -> () throws -> Void)] = [
    ("testIssues", testIssues),
    ("testIssueURLs", testIssueURLs)
  ]
}

XCTMain([
  testCase(APIConnectTests.allTests),
  testCase(CircleCiTests.allTests),
  testCase(EitherTests.allTests),
  testCase(GithubGithubTests.allTests),
  testCase(GithubServicesTests.allTests),
  testCase(IOTests.allTests),
  testCase(RouterGithubToCircleCiTests.allTests),
  testCase(RouterGithubToGithubTests.allTests),
  testCase(RouterGithubToYoutrackTests.allTests),
  testCase(RouterSlackToCircleCiTests.allTests),
  testCase(SlackTests.allTests),
  testCase(YoutrackGithubTests.allTests),
  testCase(YoutrackServicesTests.allTests),
])
