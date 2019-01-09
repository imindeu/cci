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
            Youtrack.Request.Config.youtrackURL.rawValue: "https://test.com/youtrack/rest/"
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
    
    func testGithubRequest() {
        let title = "test \(issues.joined(separator: ", "))"
        let branchHeaders = [Github.eventHeaderName: "create"]
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        let pullRequest = Github.PullRequest(url: "",
                                             id: 0,
                                             title: title,
                                             body: "",
                                             head: Github.Branch(ref: "feature"),
                                             base: Github.Branch(ref: "dev"))

        let branchRequest = Github.Payload(ref: title,
                                           refType: Github.RefType.branch)
        XCTAssertEqual(Youtrack.githubRequest(branchRequest, branchHeaders).right,
                       Youtrack.Request(
                        data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .inProgress) }))
        
        let openedRequest = Github.Payload(action: Github.Action.opened,
                                           pullRequest: pullRequest)
        XCTAssertEqual(Youtrack.githubRequest(openedRequest, pullRequestHeaders).right,
                       Youtrack.Request(data: issues.map {
                        Youtrack.Request.RequestData(issue: $0, command: .inReview)
                       }))
        
        let closedRequest = Github.Payload(action: Github.Action.closed,
                                           pullRequest: pullRequest)
        XCTAssertEqual(Youtrack.githubRequest(closedRequest, pullRequestHeaders).right,
                       Youtrack.Request(
                        data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .waitingForDeploy) }))
        
        let emptyRequest = Github.Payload(ref: "test",
                                          refType: Github.RefType.branch)
        XCTAssertEqual(Youtrack.githubRequest(emptyRequest, branchHeaders).right,
                       Youtrack.Request(data: []))
        
        let wrongRequest = Github.Payload()
        XCTAssertEqual(Youtrack.githubRequest(wrongRequest, branchHeaders).left,
                       Github.PayloadResponse())
        
        // empty header
        XCTAssertEqual(Youtrack.githubRequest(branchRequest, nil).left,
                       Github.PayloadResponse())
        
        // wrong header
        XCTAssertEqual(Youtrack.githubRequest(branchRequest, pullRequestHeaders).left,
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
        let error = Service.Error.badUrl("x/issue/4DM-2001/execute?command=4DM%20iOS%20state%20In%20Progress")
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
