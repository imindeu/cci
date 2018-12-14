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
    
    func testGithubRequest() {
        let title = "test \(issues.joined(separator: ", "))"
        let branchHeaders = [Github.eventHeaderName: "create"]
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        
        let branchRequest = Github.Payload(action: nil,
                                                  pullRequest: nil,
                                                  ref: title,
                                                  refType: Github.RefType.branch)
        XCTAssertEqual(Youtrack.githubWebhookRequest(branchRequest, branchHeaders).right,
                       Youtrack.Request(
                        data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }))
        
        let openedRequest = Github.Payload(action: Github.Action.opened,
                                                  pullRequest: Github.PullRequest(title: title),
                                                  ref: nil,
                                                  refType: nil)
        XCTAssertEqual(Youtrack.githubWebhookRequest(openedRequest, pullRequestHeaders).right,
                       Youtrack.Request(data: issues.map {
                        Youtrack.Request.RequestData(issue: $0, command: .inReview)
                       }))
        
        let closedRequest = Github.Payload(action: Github.Action.closed,
                                                  pullRequest: Github.PullRequest(title: title),
                                                  ref: nil,
                                                  refType: nil)
        XCTAssertEqual(Youtrack.githubWebhookRequest(closedRequest, pullRequestHeaders).right,
                       Youtrack.Request(
                        data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .waitingForDeploy) }))
        
        let emptyRequest = Github.Payload(action: nil,
                                                 pullRequest: nil,
                                                 ref: "test",
                                                 refType: Github.RefType.branch)
        XCTAssertEqual(Youtrack.githubWebhookRequest(emptyRequest, branchHeaders).right,
                       Youtrack.Request(data: []))
        
        let wrongRequest = Github.Payload(action: nil,
                                                 pullRequest: nil,
                                                 ref: nil,
                                                 refType: nil)
        XCTAssertEqual(Youtrack.githubWebhookRequest(wrongRequest, branchHeaders).left,
                       Github.PayloadResponse())
        
        // empty header
        XCTAssertEqual(Youtrack.githubWebhookRequest(branchRequest, nil).left,
                       Github.PayloadResponse())
        
        // wrong header
        XCTAssertEqual(Youtrack.githubWebhookRequest(branchRequest, pullRequestHeaders).left,
                       Github.PayloadResponse())
        
    }
    
    func testApiWithGithub() throws {
        let api = Youtrack.apiWithGithub(context())
        
        let passthrough: Either<Github.PayloadResponse, Youtrack.Request> = .left(Github.PayloadResponse(value: "x"))
        XCTAssertEqual(try api(passthrough).wait().left, passthrough.left)
        
        let data = issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }
        let request: Either<Github.PayloadResponse, Youtrack.Request> = .right(Youtrack.Request(data: data))
        let expected = data.map { Youtrack.ResponseContainer(response: Youtrack.Response(), data: $0) }
        let response = try api(request).wait().right
        XCTAssertEqual(response, expected)
        
        let emptyRequest: Either<Github.PayloadResponse, Youtrack.Request> = .right(Youtrack.Request(data: []))
        let emptyExpected: [Youtrack.ResponseContainer] = []
        let emptyResponse = try api(emptyRequest).wait().right
        XCTAssertEqual(emptyResponse, emptyExpected)
    }
    
    func testApiWithGithubFailure() throws {
        let api = Youtrack.apiWithGithub(context())
        Environment.env[Youtrack.Request.Config.youtrackURL.rawValue] = "x"
        let data = issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }
        let request: Either<Github.PayloadResponse, Youtrack.Request> = .right(Youtrack.Request(data: data))
        let badUrlExpected = Github.PayloadResponse(error: Youtrack.Error.badURL)
        let badUrlResponse = try api(request).wait().left
        XCTAssertEqual(badUrlResponse, badUrlExpected)
        
        Environment.env[Youtrack.Request.Config.youtrackToken.rawValue] = nil
        let badTokenExpected = Github.PayloadResponse(error: Youtrack.Error.missingToken)
        let badTokenResponse = try api(request).wait().left
        XCTAssertEqual(badTokenResponse, badTokenExpected)
    }
    
    func testResponseToGithub() {
        let emptyExpected = Github.PayloadResponse(value: Youtrack.Error.noIssue.localizedDescription)
        let empty = Youtrack.responseToGithub([])
        XCTAssertEqual(empty, emptyExpected)
        
        let single = Youtrack.responseToGithub([
            Youtrack.ResponseContainer(response: Youtrack.Response(),
                                       data: Youtrack.Request.RequestData(issue: "4DM-1000", command: .inReview))
        ])
        let singleExpected = Github.PayloadResponse(value: "")
        XCTAssertEqual(single, singleExpected)
    }
    
}
