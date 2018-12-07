//
//  RouterGithubToYoutrackTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 05..
//

import APIConnect
import APIModels

import XCTest
import HTTP

@testable import App

class RouterGithubToYoutrackTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Environment.env = [
            GithubWebhookRequest.Config.githubSecret.rawValue: "x",
            YoutrackRequest.Config.youtrackToken.rawValue: YoutrackRequest.Config.youtrackToken.rawValue,
            YoutrackRequest.Config.youtrackURL.rawValue: "https://test.com/youtrack/rest"
        ]
        Environment.api = { hostname, _ in
            return { context, request in
                Environment.env[hostname] = hostname
                if hostname == "test.com" {
                    let command = request.url.query ?? ""
                    let response = HTTPResponse(
                        status: .ok,
                        version: HTTPVersion(major: 1, minor: 1),
                        headers: HTTPHeaders([]),
                        body: "{\"value\": \"\(command)\"}")
                    return pure(response, context)
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
    
    func testFullRun() throws {
        let request = GithubWebhookRequest(action: nil,
                                           pullRequest: nil,
                                           ref: "test 4DM-1000",
                                           refType: GithubWebhookType.branch.rawValue)
        let response = try GithubToYoutrack.run(request,
                                                MultiThreadedEventLoopGroup(numberOfThreads: 1),
                                                "y",
                                                [GithubWebhookRequest.signatureHeaderName:
                                                    "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"])
            .wait()
        XCTAssertEqual(Environment.env["test.com"], "test.com")
        XCTAssertEqual(response, GithubWebhookResponse(value: "command=4DM%20iOS%20state%20In%20Progress"))
    }

    func testNoRegexRun() throws {
        let request = GithubWebhookRequest(action: nil,
                                           pullRequest: nil,
                                           ref: "test",
                                           refType: GithubWebhookType.branch.rawValue)
        let response = try GithubToYoutrack.run(request,
                                                MultiThreadedEventLoopGroup(numberOfThreads: 1),
                                                "y",
                                                [GithubWebhookRequest.signatureHeaderName:
                                                    "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"])
            .wait()
        XCTAssertNil(Environment.env["test.com"])
        XCTAssertEqual(response, GithubWebhookResponse(value: YoutrackError.noIssue.localizedDescription))
    }

    func testEmptyRun() throws {
        let request = GithubWebhookRequest(action: nil,
                                           pullRequest: nil,
                                           ref: nil,
                                           refType: nil)
        let response = try GithubToYoutrack.run(request,
                                                MultiThreadedEventLoopGroup(numberOfThreads: 1),
                                                "y",
                                                [GithubWebhookRequest.signatureHeaderName:
                                                    "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"])
            .wait()
        XCTAssertNil(Environment.env["test.com"])
        XCTAssertEqual(response, GithubWebhookResponse())
    }

}
