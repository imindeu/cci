//
//  RouterGithubToGithubTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 19..
//
import APIConnect
import APIModels

import XCTest
import HTTP

@testable import App

class RouterGithubToGithubTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Environment.env = [
            Github.Payload.Config.githubSecret.rawValue: "x",
            Github.APIRequest.Config.githubAppId.rawValue: "0101",
            Github.APIRequest.Config.githubPrivateKey.rawValue: privateKeyString
        ]
        Environment.api = { hostname, _ in
            return { context, request in
                Environment.env[hostname] = hostname
                if hostname == "test.com" {
                    let command = request.url.query ?? ""
                    return pure(HTTPResponse(body: "{\"value\": \"\(command)\"}"), context)
                } else if hostname == "api.github.com" {
                    return pure(HTTPResponse(body: "{\"token\":\"x\"}"), context)
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
            try GithubToGithub.checkConfigs()
        } catch {
            if case let GithubToGithub.APIConnectError.combined(errors) = error {
                XCTAssertEqual(errors.count, 2,
                               "We haven't found all the errors (no conflict)")
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
    
    func testFullRun() throws {
        let pullRequest = Github.PullRequest(url: "http://test.com/pull",
                                             id: 1,
                                             title: "x",
                                             head: Github.devBranch,
                                             base: Github.masterBranch,
                                             requestedReviewers: [Github.User(login: "z")])
        let request = Github.Payload(action: .submitted,
                                     review: Github.Review(state: .changesRequested),
                                     pullRequest: pullRequest,
                                     label: Github.waitingForReviewLabel,
                                     installation: Github.Installation(id: 1))
        let response = try GithubToGithub.run(request,
                                              context(),
                                              "y",
                                              [Github.eventHeaderName: Github.Event.pullRequestReview.rawValue,
                                               Github.signatureHeaderName:
                                                "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"])
            .wait()
        XCTAssertEqual(Environment.env["api.github.com"], "api.github.com")
        XCTAssertEqual(Environment.env["test.com"], "test.com")
        XCTAssertEqual(response, Github.PayloadResponse())
    }

    func testEmptyRun() throws {
        let pullRequest = Github.PullRequest(url: "http://test.com/pull",
                                             id: 1,
                                             title: "x",
                                             head: Github.devBranch,
                                             base: Github.masterBranch,
                                             assignees: [],
                                             requestedReviewers: [])
        let request = Github.Payload(action: .labeled,
                                     pullRequest: pullRequest,
                                     label: Github.waitingForReviewLabel,
                                     installation: Github.Installation(id: 1))
        let response = try GithubToYoutrack.run(request,
                                                context(),
                                                "y",
                                                [Github.eventHeaderName: Github.Event.pullRequest.rawValue,
                                                 Github.signatureHeaderName:
                                                    "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"])
            .wait()
        XCTAssertNil(Environment.env["test.com"])
        XCTAssertEqual(response, Github.PayloadResponse())
    }

}
