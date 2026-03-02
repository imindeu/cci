//
//  RouterGithubToCircleCiTests.swift
//  APIConnectTests
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 02..
//

import APIConnect
import APIModels
import APIService
import Mocks

import XCTest
import Vapor

@testable import App

class RouterGithubToCircleCiTests: XCTestCase {
    let project = "projectX"
    let branch = "feature/branch-X"
    let username = "tester"
    let options = ["options1:x", "options2:y"]

    override func setUp() async throws {
        try await super.setUp()
        
        Environment.env = [
            Github.Payload.Config.githubSecret.rawValue: "x",
            CircleCi.JobTriggerRequest.Config.tokens.rawValue: CircleCi.JobTriggerRequest.Config.tokens.rawValue,
            CircleCi.JobTriggerRequest.Config.company.rawValue: CircleCi.JobTriggerRequest.Config.company.rawValue,
            CircleCi.JobTriggerRequest.Config.vcs.rawValue: CircleCi.JobTriggerRequest.Config.vcs.rawValue,
            CircleCi.JobTriggerRequest.Config.projects.rawValue: project,
        ]
        
        class MockAPI: BackendAPIType {
            
            func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
                Environment.env[request.host] = request.host

                switch request.host {
                case "circleci.com":
                    return pure(MockHTTPResponse.okResponse(body:"{\"number\":10}"), Service.mockContext)
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
            try GithubToCircleCi.checkConfigs()
        } catch {
            if case let GithubToCircleCi.APIConnectError.combined(errors) = error {
                XCTAssertEqual(errors.count, 2,
                               "We haven't found all the errors (no conflict)")
            } else {
                XCTFail("Wrong error \(error)")
            }
        }
    }
    
    func testCheckConfigs() {
        do {
            try GithubToCircleCi.checkConfigs()
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
            url: ""
        )
        let request = Github.Payload(action: .labeled,
                                     pullRequest: pullRequest,
                                     label: Github.Label.waitingForReview,
                                     installation: Github.Installation(id: 1),
                                     repository: Github.Repository.template(name: project))
        let response = try await GithubToCircleCi.run(
            request,
            Service.mockContext,
            "y",
            [Github.eventHeaderName: "pull_request",
             Github.signatureHeaderName: "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        ).get()
        XCTAssertEqual(Environment.env["circleci.com"], "circleci.com")
        XCTAssertEqual(
            response,
            Github.PayloadResponse(value: "Job \'test\' has started at <https://app.circleci.com/pipelines/circleCiVcs/circleCiCompany/projectX/10|#10>. (project: unknown(\"projectX\"), branch: dev)")
        )
    }

    func testEmptyRun() async throws {
        let pullRequest = Github.PullRequest.template(
            id: 1,
            title: "x",
            body: "",
            head: Github.Branch.template(),
            base: Github.Branch.template(ref: "master"),
            url: ""
        )
        let request = Github.Payload(action: .unlabeled,
                                     pullRequest: pullRequest,
                                     label: Github.Label.waitingForReview,
                                     installation: Github.Installation(id: 1),
                                     repository: Github.Repository.template(name: project))
        let response = try await GithubToYoutrack.run(
            request,
            Service.mockContext,
            "y",
            [Github.eventHeaderName: "pull_request",
             Github.signatureHeaderName: "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        ).get()
        XCTAssertEqual(response, Github.PayloadResponse())
    }

}
