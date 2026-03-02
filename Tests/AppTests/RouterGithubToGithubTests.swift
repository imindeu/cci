//
//  RouterGithubToGithubTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 19..
//
import APIConnect
import APIModels
import APIService
import Mocks

import XCTest
import Vapor

@testable import App

class RouterGithubToGithubTests: XCTestCase {

    private class MockAPI: BackendAPIType {
        
        func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
            Environment.env[request.host] = request.host
            
            switch request.host {
            case "test.com":
                return pure(MockHTTPResponse.okResponse(body: "{\"value\": \"\(request.url.query() ?? "")\"}"), Service.mockContext)
            case "api.github.com":
                return pure(MockHTTPResponse.okResponse(body: "{\"token\":\"x\"}"), Service.mockContext)
            default:
                XCTFail("Shouldn't have an api for anything else")
                return pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
            }
        }
    }
    
    override func setUp() async throws {
        try await super.setUp()
        
        Environment.env = [
            Github.Payload.Config.githubSecret.rawValue: "x",
            Github.APIRequest.Config.githubAppId.rawValue: "0101",
            Github.APIRequest.Config.githubPrivateKey.rawValue: Service.privateKeyString
        ]
        
        try await Service.loadTest(MockAPI())
    }
    
    func testCheckConfigsFail() {
        Environment.env = [:]
        do {
            try GithubToGithub.checkConfigs()
        } catch {
            if case let GithubToGithub.APIConnectError.combined(errors) = error {
                XCTAssertEqual(errors.count, 2, "We haven't found all the errors (no conflict)")
            } else {
                XCTFail("Wrong error \(error)")
            }
        }
    }
    
    func testCheckConfigs() {
        do {
            try GithubToGithub.checkConfigs()
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testFullRun() async throws {
        let pullRequest = Github.PullRequest.template(
            id: 1,
            title: "x",
            body: "",
            head: Github.Branch.template(),
            base: Github.Branch.template(ref: "master"),
            url: "http://test.com/pull"
        )
        let request = Github.Payload(
            action: .submitted,
            review: Github.Review(state: .changesRequested),
            pullRequest: pullRequest,
            label: Github.Label.waitingForReview,
            installation: Github.Installation(id: 1)
        )
        let response = try await GithubToGithub
            .run(
                request,
                Service.mockContext,
                "y",
                [Github.eventHeaderName: Github.Event.pullRequestReview.rawValue,
                 Github.signatureHeaderName: "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
            )
            .get()
        XCTAssertEqual(Environment.env["api.github.com"], "api.github.com")
        XCTAssertEqual(Environment.env["test.com"], "test.com")
        XCTAssertEqual(response, Github.PayloadResponse())
    }

    func testEmptyRun() async throws {
        let pullRequest = Github.PullRequest.template(
            id: 1,
            title: "x",
            body: "",
            head: Github.Branch.template(),
            base: Github.Branch.template(ref: "master"),
            url: "http://test.com/pull"
        )
        let request = Github.Payload(
            action: .labeled,
            pullRequest: pullRequest,
            label: Github.Label.waitingForReview,
            installation: Github.Installation(id: 1)
        )
        let response = try await GithubToYoutrack
            .run(
                request,
                Service.mockContext,
                "y",
                [Github.eventHeaderName: Github.Event.pullRequest.rawValue,
                 Github.signatureHeaderName: "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
            )
            .get()
        XCTAssertNil(Environment.env["test.com"])
        XCTAssertEqual(response, Github.PayloadResponse())
    }

}
