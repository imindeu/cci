//
//  Youtrack+GithubTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 05..
//

import APIConnect
import APIModels
import APIService

import XCTest
import HTTP

@testable import App

class YoutrackGithubTests: XCTestCase {
    let issues = ["4DM-2001", "4DM-2002"]
    
    override func setUp() {
        super.setUp()
        Environment.env = [
            Youtrack.Request.Config.youtrackToken.rawValue: Youtrack.Request.Config.youtrackToken.rawValue,
            Youtrack.Request.Config.youtrackURL.rawValue: "https://test.com/youtrack/api/"
        ]
        Environment.api = { hostname, _ in
            return { context, _ in
                if hostname == "test.com" {
                    return pure(HTTPResponse(body: "{}"), context)
                } else {
                    return Environment.emptyApi(context)
                }
            }
        }
    }
    
    func testGithubRequest() throws {
        let title = "test \(issues.joined(separator: ", "))"
        let branchHeaders = [Github.eventHeaderName: "create"]
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        let pullRequest = Github.PullRequest(url: "",
                                             id: 0,
                                             title: title,
                                             body: "",
                                             head: Github.Branch.template(ref: "feature"),
                                             base: Github.Branch.template())

        let branchRequest = Github.Payload(ref: title,
                                           refType: Github.RefType.branch)
        XCTAssertEqual(try Youtrack.githubRequest(branchRequest, branchHeaders, context()).wait().right,
                       Youtrack.Request(
                        data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }))
        
        let openedRequest = Github.Payload(action: Github.Action.opened,
                                           pullRequest: pullRequest)
        XCTAssertEqual(try Youtrack.githubRequest(openedRequest, pullRequestHeaders, context()).wait().right,
                       Youtrack.Request(data: issues.map {
                        Youtrack.Request.RequestData(issue: $0, command: .inReview)
                       }))
        
        let closedRequest = Github.Payload(action: Github.Action.closed,
                                           pullRequest: pullRequest)
        XCTAssertEqual(try Youtrack.githubRequest(closedRequest, pullRequestHeaders, context()).wait().right,
                       Youtrack.Request(
                        data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .waitingForDeploy) }))
        
        let emptyRequest = Github.Payload(ref: "test",
                                          refType: Github.RefType.branch)
        XCTAssertEqual(try Youtrack.githubRequest(emptyRequest, branchHeaders, context()).wait().right,
                       Youtrack.Request(data: []))
        
        let wrongRequest = Github.Payload()
        XCTAssertEqual(try Youtrack.githubRequest(wrongRequest, branchHeaders, context()).wait().left,
                       Github.PayloadResponse())
        
        // empty header
        XCTAssertEqual(try Youtrack.githubRequest(branchRequest, nil, context()).wait().left,
                       Github.PayloadResponse())
        
        // wrong header
        XCTAssertEqual(try Youtrack.githubRequest(branchRequest, pullRequestHeaders, context()).wait().left,
                       Github.PayloadResponse())
        
    }
    
    func testApiWithGithub() throws {
        let api = Youtrack.apiWithGithub(context())
        
        let data = issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }
        let request = Youtrack.Request(data: data)
        let expected = data.map { Youtrack.ResponseContainer(response: Youtrack.Response(), data: $0) }
        let response = try api(request).wait().right
        XCTAssertEqual(response, expected)
        
        let emptyRequest: Youtrack.Request = Youtrack.Request(data: [])
        let emptyExpected: [Youtrack.ResponseContainer] = []
        let emptyResponse = try api(emptyRequest).wait().right
        XCTAssertEqual(emptyResponse, emptyExpected)
    }
    
    func testApiWithGithubFailure() throws {
        let api = Youtrack.apiWithGithub(context())
        Environment.env[Youtrack.Request.Config.youtrackURL.rawValue] = "x"
        let data = issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }
        let request: Youtrack.Request = Youtrack.Request(data: data)
        let error = Service.Error.badUrl("x/commands")
        let badUrlExpected = Github.PayloadResponse(error: error)
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
