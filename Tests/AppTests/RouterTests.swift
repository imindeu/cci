//
//  RouterTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 09. 10..
//

import APIConnect
import APIModels

import XCTest
import Vapor
@testable import App

class RouterTests: XCTestCase {
    let slackToken = "slackToken"
    let project = "projectX"
    let branch = "feature/branch-X"
    let username = "tester"
    let options = ["options1:x", "options2:y"]
    
    private func assert(body: Data?, file: StaticString = #file, line: UInt = #line) {
        guard let body = body else {
            XCTFail("Empty body", file: file, line: line)
            return
        }
        let response = CircleCiBuildResponse(response: CircleCiResponse(buildURL: "buildURL",
                                                                        buildNum: 10),
                                             job: CircleCiTestJob(project: project,
                                                                  branch: branch,
                                                                  options: options,
                                                                  username: username))
        let slackResponse = CircleCiJobRequest.responseToSlack(response)
        let data = try? JSONEncoder().encode(slackResponse)
        XCTAssertEqual(data, body, file: file, line: line)
    }
    
    override func setUp() {
        super.setUp()
        Environment.env = [
            "circleCiTokens": "circleCiTokens",
            "slackToken": slackToken,
            "circleCiCompany": "company",
            "circleCiVcs": "vcs",
            "circleCiProjects": project
        ]
        Environment.api = { hostname, _ in
            return { context, request in
                Environment.env[hostname] = hostname
                if hostname == "slack.com" {
                    self.assert(body: request.body.data)
                }
                if hostname == "circleci.com" {
                    let response = HTTPResponse(
                        status: .ok,
                        version: HTTPVersion(major: 1, minor: 1),
                        headers: HTTPHeaders([]),
                        body: "{\"build_url\":\"buildURL\",\"build_num\":10}")
                    return pure(response, context)
                } else {
                    return Environment.emptyApi(context)
                }
            }
        }
    }
    
    func testCheckConfigsFail() {
        Environment.env = [:]
        do {
            try SlackToCircleCi.checkConfigs()
        } catch {
            if case let SlackToCircleCi.APIConnectError.combined(errors) = error {
                XCTAssertEqual(errors.count, 2,
                               "We haven't found all the errors (no conflict)")
            } else {
                XCTFail("Wrong error \(error)")
            }
        }
    }

    func testCheckConfigs() {
        do {
            try SlackToCircleCi.checkConfigs()
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testFullRun() throws {
        let request = SlackRequest(token: slackToken,
                                   teamId: "",
                                   teamDomain: "",
                                   enterpriseId: "",
                                   enterpriseName: nil,
                                   channelId: "",
                                   channelName: project,
                                   userId: "",
                                   userName: username,
                                   command: "x",
                                   text: "\(CircleCiJobKind.test.rawValue) \(branch) \(options.joined(separator: " "))",
                                   responseUrlString: "https://slack.com",
                                   triggerId: "")
        let response = try SlackToCircleCi.run(request,
                                               MultiThreadedEventLoopGroup(numberOfThreads: 1))
            .wait()
        XCTAssertEqual(Environment.env["slack.com"], "slack.com")
        XCTAssertEqual(Environment.env["circleci.com"], "circleci.com")
        XCTAssertEqual(response, SlackResponse.instant)
    }
}
