//
//  RouterGithubToCircleCiTests.swift
//  APIConnectTests
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 02..
//

import APIConnect
import APIModels

import XCTest
import HTTP

@testable import App

class RouterGithubToCircleCiTests: XCTestCase {
    let project = "projectX"
    let branch = "feature/branch-X"
    let username = "tester"
    let options = ["options1:x", "options2:y"]

    override func setUp() {
        super.setUp()
        Environment.env = [
            Github.Payload.Config.githubSecret.rawValue: "x",
            CircleCi.JobRequest.Config.tokens.rawValue: CircleCi.JobRequest.Config.tokens.rawValue,
            CircleCi.JobRequest.Config.company.rawValue: CircleCi.JobRequest.Config.company.rawValue,
            CircleCi.JobRequest.Config.vcs.rawValue: CircleCi.JobRequest.Config.vcs.rawValue,
            CircleCi.JobRequest.Config.projects.rawValue: project,
        ]
        Environment.api = { hostname, _ in
            return { context, request in
                Environment.env[hostname] = hostname
                if hostname == "circleci.com" {
                    return pure(HTTPResponse(body: "{\"build_url\":\"buildURL\",\"build_num\":10}"), context)
                } else {
                    XCTFail("Shouldn't have an api for anything else")
                    return Environment.emptyApi(context)
                }
            }
        }
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

    func testFullRun() throws {
        let pullRequest = Github.PullRequest(url: "",
                                             id: 1,
                                             title: "x",
                                             body: "",
                                             head: Github.devBranch,
                                             base: Github.masterBranch)
        let request = Github.Payload(action: .labeled,
                                     pullRequest: pullRequest,
                                     label: Github.waitingForReviewLabel,
                                     installation: Github.Installation(id: 1),
                                     repository: Github.Repository(name: project))
        let response = try GithubToCircleCi.run(request,
                                                context(),
                                                "y",
                                                [Github.eventHeaderName: "pull_request",
                                                 Github.signatureHeaderName:
                                                    "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"])
            .wait()
        XCTAssertEqual(Environment.env["circleci.com"], "circleci.com")
        XCTAssertEqual(response, Github.PayloadResponse(value: "Job \'test\' has started at <buildURL|#10>. (project: projectX, branch: dev)"))
    }

    func testEmptyRun() throws {
        let pullRequest = Github.PullRequest(url: "",
                                             id: 1,
                                             title: "x",
                                             body: "",
                                             head: Github.devBranch,
                                             base: Github.masterBranch)
        let request = Github.Payload(action: .unlabeled,
                                     pullRequest: pullRequest,
                                     label: Github.waitingForReviewLabel,
                                     installation: Github.Installation(id: 1),
                                     repository: Github.Repository(name: project))
        let response = try GithubToYoutrack.run(request,
                                                context(),
                                                "y",
                                                [Github.eventHeaderName: "pull_request",
                                                 Github.signatureHeaderName:
                                                    "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"])
            .wait()
        XCTAssertEqual(response, Github.PayloadResponse())
    }

}
