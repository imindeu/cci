//
//  RouterSlackToCircleCiTests
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 09. 10..
//

import APIConnect
import APIModels

import XCTest
import Vapor
@testable import App

class RouterSlackToCircleCiTests: XCTestCase {
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
        let response = CircleCi.BuildResponse(response: CircleCi.Response(buildURL: "buildURL",
                                                                          buildNum: 10),
                                             job: CircleCiTestJob(project: project,
                                                                  branch: branch,
                                                                  options: options,
                                                                  username: username))
        let slackResponse = CircleCi.responseToSlack(response)
        let data = try? JSONEncoder().encode(slackResponse)
        XCTAssertEqual(data, body, file: file, line: line)
    }
    
    override func setUp() {
        super.setUp()
        Environment.env = [
            Slack.Request.Config.slackToken.rawValue: Slack.Request.Config.slackToken.rawValue,
            CircleCi.JobRequest.Config.tokens.rawValue: CircleCi.JobRequest.Config.tokens.rawValue,
            CircleCi.JobRequest.Config.company.rawValue: CircleCi.JobRequest.Config.company.rawValue,
            CircleCi.JobRequest.Config.vcs.rawValue: CircleCi.JobRequest.Config.vcs.rawValue,
            CircleCi.JobRequest.Config.projects.rawValue: project,
        ]
        Environment.api = { hostname, _ in
            return { context, request in
                Environment.env[hostname] = hostname
                if hostname == "slack.com" {
                    self.assert(body: request.body.data)
                    return Environment.emptyApi(context)
                } else if hostname == "circleci.com" {
                    let response = HTTPResponse(
                        status: .ok,
                        version: HTTPVersion(major: 1, minor: 1),
                        headers: HTTPHeaders([]),
                        body: "{\"build_url\":\"buildURL\",\"build_num\":10}")
                    return pure(response, context)
                } else {
                    XCTFail("Shouldn't have an api for anything else: \(hostname)")
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
        let text = "\(CircleCiJobKind.test.rawValue) \(branch) \(options.joined(separator: " "))"
        let request = Slack.Request(token: slackToken,
                                    teamId: "",
                                    teamDomain: "",
                                    enterpriseId: "",
                                    enterpriseName: nil,
                                    channelId: "",
                                    channelName: project,
                                    userId: "",
                                    userName: username,
                                    command: "x",
                                    text: text,
                                    responseUrlString: "https://slack.com",
                                    triggerId: "")
        let response = try SlackToCircleCi.run(request,
                                               context())
            .wait()
        XCTAssertEqual(Environment.env["slack.com"], "slack.com")
        XCTAssertEqual(Environment.env["circleci.com"], "circleci.com")
        XCTAssertEqual(response, Slack.Response.instant)
    }
}
