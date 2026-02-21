//
//  Youtrack+GithubTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 05..
//

@preconcurrency import APIConnect
import APIModels
import APIService
import Mocks

import XCTest
import Vapor

@testable import App

class YoutrackGithubTests: XCTestCase {
    let issues = ["4DM-2001", "4DM-2002"]
    
    override func setUp() async throws {
        try await super.setUp()
        
        Environment.env = [
            Youtrack.Request.Config.youtrackToken.rawValue: Youtrack.Request.Config.youtrackToken.rawValue,
            Youtrack.Request.Config.youtrackURL.rawValue: "https://test.com/youtrack/api/"
        ]
        
        class MockAPI: BackendAPIType {
            
            func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
                if request.host == "test.com" {
                    pure(MockHTTPResponse.okResponse(body: "{}"), Service.mockContext)
                } else {
                    pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
                }
            }
        }
        try await Service.loadTest(MockAPI())
    }
    
    func testGithubRequest() async throws {
        let title = "test \(issues.joined(separator: ", "))"
        let branchHeaders = [Github.eventHeaderName: "create"]
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        let pullRequest = Github.PullRequest(url: "",
                                             id: 0,
                                             title: title,
                                             body: "",
                                             head: Github.Branch.template(ref: "feature"),
                                             base: Github.Branch.template())

        let branchRequest = Github.Payload(ref: title, refType: Github.RefType.branch)
        let branchResponse = try await Youtrack.githubRequest(branchRequest, branchHeaders, Service.mockContext).get().right
        XCTAssertEqual(branchResponse, Youtrack.Request( data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .iOS_inProgress) }))
        
        let openedRequest = Github.Payload(action: Github.Action.opened, pullRequest: pullRequest)
        let openedResponse = try await Youtrack.githubRequest(openedRequest, pullRequestHeaders, Service.mockContext).get().right
        XCTAssertEqual(openedResponse, Youtrack.Request(data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .iOS_inReview) }))
        
        let closedRequest = Github.Payload(action: Github.Action.closed, pullRequest: pullRequest)
        let closedResponse = try await Youtrack.githubRequest(closedRequest, pullRequestHeaders, Service.mockContext).get().right
        XCTAssertEqual(closedResponse, Youtrack.Request( data: issues.map { Youtrack.Request.RequestData(issue: $0, command: .iOS_waitingForDeploy) }))
        
        let emptyRequest = Github.Payload(ref: "test", refType: Github.RefType.branch)
        let emptyResponse = try await Youtrack.githubRequest(emptyRequest, branchHeaders, Service.mockContext).get().right
        XCTAssertEqual(emptyResponse, Youtrack.Request(data: []))
        
        let wrongRequest = Github.Payload()
        let wrongResponse = try await Youtrack.githubRequest(wrongRequest, branchHeaders, Service.mockContext).get().left
        XCTAssertEqual(wrongResponse, Github.PayloadResponse())
        
        let emptyHeaderResponse = try await Youtrack.githubRequest(branchRequest, nil, Service.mockContext).get().left
        XCTAssertEqual(emptyHeaderResponse, Github.PayloadResponse())
        
        let wrongHeaderResponse = try await Youtrack.githubRequest(branchRequest, pullRequestHeaders, Service.mockContext).get().left
        XCTAssertEqual(wrongHeaderResponse, Github.PayloadResponse())
    }
    
    func testApiWithGithub() async throws {
        let api = Youtrack.apiWithGithub(Service.mockContext)
        
        let data = issues.map { Youtrack.Request.RequestData(issue: $0, command: .iOS_inProgress) }
        let request = Youtrack.Request(data: data)
        let expected = data.map { Youtrack.ResponseContainer(response: Youtrack.Response(), data: $0) }
        let response = try await api(request).get().right
        XCTAssertEqual(response, expected)
        
        let emptyRequest: Youtrack.Request = Youtrack.Request(data: [])
        let emptyExpected: [Youtrack.ResponseContainer] = []
        let emptyResponse = try await api(emptyRequest).get().right
        XCTAssertEqual(emptyResponse, emptyExpected)
    }
    
    func testApiWithGithubFailure() throws {
        let api = Youtrack.apiWithGithub(Service.mockContext)
        Environment.env[Youtrack.Request.Config.youtrackURL.rawValue] = "x"
        let data = issues.map { Youtrack.Request.RequestData(issue: $0, command: .iOS_inProgress) }
        let request: Youtrack.Request = Youtrack.Request(data: data)
        let badUrlExpected = Github.PayloadResponse(error: Youtrack.Error.underlying(HTTPClientError.emptyScheme))
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
                                       data: Youtrack.Request.RequestData(issue: "4DM-1000", command: .iOS_inReview))
        ])
        let singleExpected = Github.PayloadResponse(value: "")
        XCTAssertEqual(single, singleExpected)
    }
}
