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
        let branchHeaders = [GithubWebhook.Request.eventHeaderName: "create"]
        let pullRequestHeaders = [GithubWebhook.Request.eventHeaderName: "pull_request"]

        let branchRequest = GithubWebhook.Request(action: nil,
                                                 pullRequest: nil,
                                                 ref: title,
                                                 refType: GithubWebhook.RefType.branch)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(branchRequest, branchHeaders).right,
                       YoutrackRequest(
                        data: issues.map { YoutrackRequest.RequestData(issue: $0, command: .inProgress) }))
        
        let openedRequest = GithubWebhook.Request(action: GithubWebhook.Action.opened,
                                                 pullRequest: GithubWebhook.PullRequest(title: title),
                                                 ref: nil,
                                                 refType: nil)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(openedRequest, pullRequestHeaders).right,
                       YoutrackRequest(data: issues.map { YoutrackRequest.RequestData(issue: $0, command: .inReview) }))
        
        let closedRequest = GithubWebhook.Request(action: GithubWebhook.Action.closed,
                                                 pullRequest: GithubWebhook.PullRequest(title: title),
                                                 ref: nil,
                                                 refType: nil)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(closedRequest, pullRequestHeaders).right,
                       YoutrackRequest(
                        data: issues.map { YoutrackRequest.RequestData(issue: $0, command: .waitingForDeploy) }))
        
        let emptyRequest = GithubWebhook.Request(action: nil,
                                                pullRequest: nil,
                                                ref: "test",
                                                refType: GithubWebhook.RefType.branch)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(emptyRequest, branchHeaders).right,
                       YoutrackRequest(data: []))

        let wrongRequest = GithubWebhook.Request(action: nil,
                                                pullRequest: nil,
                                                ref: nil,
                                                refType: nil)
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(wrongRequest, branchHeaders).left,
                       GithubWebhook.Response())
        
        // empty header
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(branchRequest, nil).left,
                       GithubWebhook.Response())
        
        // wrong header
        XCTAssertEqual(YoutrackRequest.githubWebhookRequest(branchRequest, pullRequestHeaders).left,
                       GithubWebhook.Response())

    }
    
    func testApiWithGithubWebhook() throws {
        let api = YoutrackRequest.apiWithGithubWebhook(context())
        
        let passthrough: Either<GithubWebhook.Response, YoutrackRequest> = .left(GithubWebhook.Response(value: "x"))
        XCTAssertEqual(try api(passthrough).wait().left, passthrough.left)
        
        let data = issues.map { YoutrackRequest.RequestData(issue: $0, command: .inProgress) }
        let request: Either<GithubWebhook.Response, YoutrackRequest> = .right(YoutrackRequest(data: data))
        let expected = data.map { YoutrackResponseContainer(response: YoutrackResponse(), data: $0) }
        let response = try api(request).wait().right
        XCTAssertEqual(response, expected)
        
        let emptyRequest: Either<GithubWebhook.Response, YoutrackRequest> = .right(YoutrackRequest(data: []))
        let emptyExpected: [YoutrackResponseContainer] = []
        let emptyResponse = try api(emptyRequest).wait().right
        XCTAssertEqual(emptyResponse, emptyExpected)
    }
    
    func testApiWithGithubWebhookFailure() throws {
        let api = YoutrackRequest.apiWithGithubWebhook(context())
        Environment.env[YoutrackRequest.Config.youtrackURL.rawValue] = "x"
        let data = issues.map { YoutrackRequest.RequestData(issue: $0, command: .inProgress) }
        let request: Either<GithubWebhook.Response, YoutrackRequest> = .right(YoutrackRequest(data: data))
        let badUrlExpected = GithubWebhook.Response(error: YoutrackError.badURL)
        let badUrlResponse = try api(request).wait().left
        XCTAssertEqual(badUrlResponse, badUrlExpected)

        Environment.env[YoutrackRequest.Config.youtrackToken.rawValue] = nil
        let badTokenExpected = GithubWebhook.Response(error: YoutrackError.missingToken)
        let badTokenResponse = try api(request).wait().left
        XCTAssertEqual(badTokenResponse, badTokenExpected)
    }
    
    func testResponseToGithubWebhook() {
        let emptyExpected = GithubWebhook.Response(value: YoutrackError.noIssue.localizedDescription)
        let empty = YoutrackRequest.responseToGithubWebhook([])
        XCTAssertEqual(empty, emptyExpected)
        
        let single = YoutrackRequest.responseToGithubWebhook([
            YoutrackResponseContainer(response: YoutrackResponse(),
                                      data: YoutrackRequest.RequestData(issue: "4DM-1000", command: .inReview))
        ])
        let singleExpected = GithubWebhook.Response(value: "")
        XCTAssertEqual(single, singleExpected)
    }

}
