//
//  YoutrackTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 05..
//

import APIConnect
import APIModels
import XCTest
import HTTP

@testable import App

class YoutrackTests: XCTestCase {
    let issues = ["4DM-2001", "4DM-2002"]

    override func setUp() {
        super.setUp()
        Environment.env = [
            YoutrackRequest.Config.youtrackToken.rawValue: YoutrackRequest.Config.youtrackToken.rawValue,
            YoutrackRequest.Config.youtrackURL.rawValue: "https://test.com/youtrack/rest/"
        ]
        Environment.api = { hostname, _ in
            return { context, _ in
                if hostname == "test.com" {
                    let response = HTTPResponse(
                        status: .ok,
                        version: HTTPVersion(major: 1, minor: 1),
                        headers: HTTPHeaders([]),
                        body: "{}")
                    return pure(response, context)
                } else {
                    return Environment.emptyApi(context)
                }
            }
        }
    }
    
    func testGithubWebhookRequest() {
        let title = "test \(issues.joined(separator: ", "))"
        
        let branchRequest = GithubWebhookRequest(action: nil,
                                                 pullRequest: nil,
                                                 ref: title,
                                                 refType: GithubWebhookType.branch.rawValue)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(branchRequest).right,
                       YoutrackRequest(
                        data: issues.map { YoutrackRequest.RequestData(issue: $0, command: .inProgress) }))
        
        let openedRequest = GithubWebhookRequest(action: GithubWebhookType.opened.rawValue,
                                                 pullRequest: GithubWebhookRequest.PullRequest(title: title),
                                                 ref: nil,
                                                 refType: nil)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(openedRequest).right,
                       YoutrackRequest(data: issues.map { YoutrackRequest.RequestData(issue: $0, command: .inReview) }))
        
        let closedRequest = GithubWebhookRequest(action: GithubWebhookType.closed.rawValue,
                                                 pullRequest: GithubWebhookRequest.PullRequest(title: title),
                                                 ref: nil,
                                                 refType: nil)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(closedRequest).right,
                       YoutrackRequest(
                        data: issues.map { YoutrackRequest.RequestData(issue: $0, command: .waitingForDeploy) }))
        
        let emptyRequest = GithubWebhookRequest(action: nil,
                                                pullRequest: nil,
                                                ref: "test",
                                                refType: GithubWebhookType.branch.rawValue)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(emptyRequest).right,
                       YoutrackRequest(data: []))

        let wrongRequest = GithubWebhookRequest(action: nil,
                                                pullRequest: nil,
                                                ref: nil,
                                                refType: nil)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(wrongRequest).left,
                       GithubWebhookResponse())

    }
    
    func testApiWithGithubWebhook() throws {
        let api = YoutrackRequest.apiWithGithubWebhook(context())
        
        let passthrough: Either<GithubWebhookResponse, YoutrackRequest> = .left(GithubWebhookResponse(failure: "x"))
        XCTAssertEqual(try api(passthrough).wait().left, passthrough.left)
        
        let data = issues.map { YoutrackRequest.RequestData(issue: $0, command: .inProgress) }
        let request: Either<GithubWebhookResponse, YoutrackRequest> = .right(YoutrackRequest(data: data))
        let expected = data.map { YoutrackResponseContainer(response: YoutrackResponse(), data: $0) }
        let response = try api(request).wait().right
        XCTAssertEqual(response, expected)
        
        let emptyRequest: Either<GithubWebhookResponse, YoutrackRequest> = .right(YoutrackRequest(data: []))
        let emptyExpected: [YoutrackResponseContainer] = []
        let emptyResponse = try api(emptyRequest).wait().right
        XCTAssertEqual(emptyResponse, emptyExpected)
    }
    
    func testApiWithGithubWebhookFailure() throws {
        let api = YoutrackRequest.apiWithGithubWebhook(context())
        Environment.env[YoutrackRequest.Config.youtrackURL.rawValue] = "x"
        let data = issues.map { YoutrackRequest.RequestData(issue: $0, command: .inProgress) }
        let request: Either<GithubWebhookResponse, YoutrackRequest> = .right(YoutrackRequest(data: data))
        let badUrlExpected = GithubWebhookResponse(error: YoutrackError.badURL)
        let badUrlResponse = try api(request).wait().left
        XCTAssertEqual(badUrlResponse, badUrlExpected)

        Environment.env[YoutrackRequest.Config.youtrackToken.rawValue] = nil
        let badTokenExpected = GithubWebhookResponse(error: YoutrackError.missingToken)
        let badTokenResponse = try api(request).wait().left
        XCTAssertEqual(badTokenResponse, badTokenExpected)
    }
    
    func testResponseToGithubWebhook() {
        let expected = GithubWebhookResponse()
        let empty = YoutrackRequest.responseToGithubWebhook([])
        XCTAssertEqual(empty, expected)
        
        let single = YoutrackRequest.responseToGithubWebhook([
            YoutrackResponseContainer(response: YoutrackResponse(),
                                      data: YoutrackRequest.RequestData(issue: "4DM-1000", command: .inReview))
        ])
        XCTAssertEqual(single, expected)
    }

}
