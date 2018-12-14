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
            Youtrack.Request.Config.youtrackToken.rawValue: Youtrack.Request.Config.youtrackToken.rawValue,
            Youtrack.Request.Config.youtrackURL.rawValue: "https://test.com/youtrack/rest/"
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
        let branchHeaders = [GithubWebhook.eventHeaderName: "create"]
        let pullRequestHeaders = [GithubWebhook.eventHeaderName: "pull_request"]
        
        let branchRequest = GithubWebhook.Request(action: nil,
                                                  pullRequest: nil,
                                                  ref: title,
                                                  refType: GithubWebhook.RefType.branch)
        XCTAssertEqual(Youtrack.githubWebhookRequest(branchRequest, branchHeaders).right,
                       Youtrack.Request(
                        data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }))
        
        let openedRequest = GithubWebhook.Request(action: GithubWebhook.Action.opened,
                                                  pullRequest: GithubWebhook.PullRequest(title: title),
                                                  ref: nil,
                                                  refType: nil)
        XCTAssertEqual(Youtrack.githubWebhookRequest(openedRequest, pullRequestHeaders).right,
                       Youtrack.Request(data: issues.map {
                        Youtrack.Request.RequestData(issue: $0, command: .inReview)
                       }))
        
        let closedRequest = GithubWebhook.Request(action: GithubWebhook.Action.closed,
                                                  pullRequest: GithubWebhook.PullRequest(title: title),
                                                  ref: nil,
                                                  refType: nil)
        XCTAssertEqual(Youtrack.githubWebhookRequest(closedRequest, pullRequestHeaders).right,
                       Youtrack.Request(
                        data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .waitingForDeploy) }))
        
        let emptyRequest = GithubWebhook.Request(action: nil,
                                                 pullRequest: nil,
                                                 ref: "test",
                                                 refType: GithubWebhook.RefType.branch)
        XCTAssertEqual(Youtrack.githubWebhookRequest(emptyRequest, branchHeaders).right,
                       Youtrack.Request(data: []))
        
        let wrongRequest = GithubWebhook.Request(action: nil,
                                                 pullRequest: nil,
                                                 ref: nil,
                                                 refType: nil)
        XCTAssertEqual(Youtrack.githubWebhookRequest(wrongRequest, branchHeaders).left,
                       GithubWebhook.Response())
        
        // empty header
        XCTAssertEqual(Youtrack.githubWebhookRequest(branchRequest, nil).left,
                       GithubWebhook.Response())
        
        // wrong header
        XCTAssertEqual(Youtrack.githubWebhookRequest(branchRequest, pullRequestHeaders).left,
                       GithubWebhook.Response())
        
    }
    
    func testApiWithGithubWebhook() throws {
        let api = Youtrack.apiWithGithubWebhook(context())
        
        let passthrough: Either<GithubWebhook.Response, Youtrack.Request> = .left(GithubWebhook.Response(value: "x"))
        XCTAssertEqual(try api(passthrough).wait().left, passthrough.left)
        
        let data = issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }
        let request: Either<GithubWebhook.Response, Youtrack.Request> = .right(Youtrack.Request(data: data))
        let expected = data.map { Youtrack.ResponseContainer(response: Youtrack.Response(), data: $0) }
        let response = try api(request).wait().right
        XCTAssertEqual(response, expected)
        
        let emptyRequest: Either<GithubWebhook.Response, Youtrack.Request> = .right(Youtrack.Request(data: []))
        let emptyExpected: [Youtrack.ResponseContainer] = []
        let emptyResponse = try api(emptyRequest).wait().right
        XCTAssertEqual(emptyResponse, emptyExpected)
    }
    
    func testApiWithGithubWebhookFailure() throws {
        let api = Youtrack.apiWithGithubWebhook(context())
        Environment.env[Youtrack.Request.Config.youtrackURL.rawValue] = "x"
        let data = issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }
        let request: Either<GithubWebhook.Response, Youtrack.Request> = .right(Youtrack.Request(data: data))
        let badUrlExpected = GithubWebhook.Response(error: Youtrack.Error.badURL)
        let badUrlResponse = try api(request).wait().left
        XCTAssertEqual(badUrlResponse, badUrlExpected)
        
        Environment.env[Youtrack.Request.Config.youtrackToken.rawValue] = nil
        let badTokenExpected = GithubWebhook.Response(error: Youtrack.Error.missingToken)
        let badTokenResponse = try api(request).wait().left
        XCTAssertEqual(badTokenResponse, badTokenExpected)
    }
    
    func testResponseToGithubWebhook() {
        let emptyExpected = GithubWebhook.Response(value: Youtrack.Error.noIssue.localizedDescription)
        let empty = Youtrack.responseToGithubWebhook([])
        XCTAssertEqual(empty, emptyExpected)
        
        let single = Youtrack.responseToGithubWebhook([
            Youtrack.ResponseContainer(response: Youtrack.Response(),
                                       data: Youtrack.Request.RequestData(issue: "4DM-1000", command: .inReview))
        ])
        let singleExpected = GithubWebhook.Response(value: "")
        XCTAssertEqual(single, singleExpected)
    }
    
}
