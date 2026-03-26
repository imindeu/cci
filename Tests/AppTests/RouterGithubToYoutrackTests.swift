//
//  RouterGithubToYoutrackTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 05..
//

import APIConnect
import APIModels
import APIService
import Mocks

import XCTest
import Vapor

@testable import App

class RouterGithubToYoutrackTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        Environment.env = [
            Github.Payload.Config.githubSecret.rawValue: "x",
            Youtrack.Request.Config.youtrackToken.rawValue: Youtrack.Request.Config.youtrackToken.rawValue,
            Youtrack.Request.Config.youtrackURL.rawValue: "https://test.com/youtrack/api"
        ]
        
        class MockAPI: BackendAPIType {
            
            func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
                Environment.env[request.host] = request.host

                switch request.host {
                case "test.com":
                    return pure(MockHTTPResponse.okResponse(body: "{ \"value\": \"test 4DM-1000\" }"), Service.mockContext)
                default:
                    XCTFail("Shouldn't have an api for anything else")
                    return pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
                }
            }
        }
        try await Service.loadTest(MockAPI())
    }
    
    func testCheckConfigsFail() {
        Environment.env = [:]
        do {
            try GithubToYoutrack.checkConfigs()
        } catch {
            if case let GithubToYoutrack.APIConnectError.combined(errors) = error {
                XCTAssertEqual(errors.count, 2,
                               "We haven't found all the errors (no conflict)")
            } else {
                XCTFail("Wrong error \(error)")
            }
        }
    }
    
    func testCheckConfigs() {
        do {
            try GithubToYoutrack.checkConfigs()
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testFullRun() async throws {
        let request = Github.Payload(ref: "test 4DM-1000", refType: Github.RefType.branch)
        let response = try await GithubToYoutrack.run(
            request,
            Service.mockContext,
            "y",
            [Github.signatureHeaderName: "sha256=1b56188fbdc65a885923886c8b7271332149050589d91803364521080cd0792d",
             Github.eventHeaderName: "create"]
        ).get()
        XCTAssertEqual(Environment.env["test.com"], "test.com")
        XCTAssertEqual(response, Github.PayloadResponse(value: "test 4DM-1000"))
    }
    
    func testNoRegexRun() async throws {
        let request = Github.Payload(ref: "test", refType: Github.RefType.branch)
        let response = try await GithubToYoutrack.run(
            request,
            Service.mockContext,
            "y",
            [Github.signatureHeaderName: "sha256=1b56188fbdc65a885923886c8b7271332149050589d91803364521080cd0792d",
             Github.eventHeaderName: "create"]
        ).get()
        XCTAssertNil(Environment.env["test.com"])
        XCTAssertEqual(response, Github.PayloadResponse(value: Youtrack.Error.noIssue.localizedDescription))
    }
    
    func testEmptyRun() async throws {
        let request = Github.Payload()
        let response = try await GithubToYoutrack.run(
            request,
            Service.mockContext,
            "y",
            [Github.signatureHeaderName: "sha256=1b56188fbdc65a885923886c8b7271332149050589d91803364521080cd0792d"]
        ).get()
        XCTAssertNil(Environment.env["test.com"])
        XCTAssertEqual(response, Github.PayloadResponse())
    }
    
}
