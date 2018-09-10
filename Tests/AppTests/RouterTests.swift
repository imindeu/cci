//
//  RouterTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 09. 10..
//

import XCTest
import Vapor
@testable import App

class RouterTests: XCTestCase {
    let circleciToken = "circleciToken"
    let slackToken = "slackToken"
    let project = "projectX"
    let branch = "feature/branch-X"
    var urlEncodedBranch: String {
        return branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
    let username = "tester"
    let options = ["options1:x", "options2:y"]
    let headers = HTTPHeaders([
        ("Accept", "application/json"),
        ("Content-Type", "application/json")
        ])
    
    func request() throws -> Request {
        let app = try Application()
        return Request(using: app)
    }

    override func setUp() {
        super.setUp()
        Environment.push(Environment.init(circleciToken: circleciToken,
                                          slackToken: slackToken,
                                          company: "company",
                                          vcs: "vcs",
                                          circleciPath: { "\($0)/\($1)" },
                                          projects: [project],
                                          circleci: Environment.goodApi("{\"build_url\":\"buildURL\",\"build_num\":10}"),
                                          slack: Environment.empty.slack))
    }
    
    override func tearDown() {
        Environment.pop()
        super.tearDown()
    }
    
    func testTestCommandAction() throws {
        let response = try commandAction(
            worker: request(),
            slack: SlackRequest(token: slackToken,
                                team_id: "",
                                team_domain: "",
                                enterprise_id: nil,
                                enterprise_name: nil,
                                channel_id: "",
                                channel_name: project,
                                user_id: "",
                                user_name: username,
                                command: "",
                                text: "test options1:x options2:y \(branch)",
                                response_url: "",
                                trigger_id: "")).wait()
        let expected = SlackResponse(
            response_type: .inChannel,
            text: nil,
            attachments: [
                SlackResponse.Attachment(
                    fallback: "Job \'test\' has started at <buildURL|#10>. (project: projectX, branch: feature/branch-X",
                    text: "Job \'test\' has started at <buildURL|#10>.",
                    color: "#764FA5",
                    mrkdwn_in: ["text", "fields"],
                    fields: [
                        SlackResponse.Field(title: "Project", value: project, short: true),
                        SlackResponse.Field(title: "Branch", value: branch, short: true),
                        SlackResponse.Field(title: "User", value: username, short: true),
                        SlackResponse.Field(title: "options1", value: "x", short: true),
                        SlackResponse.Field(title: "options2", value: "y", short: true)])],
            mrkdwn: true)

        XCTAssertEqual(response.slackResponse, expected)
    }
    
    func testDeployCommandAction() throws {
        let response = try commandAction(
            worker: request(),
            slack: SlackRequest(token: slackToken,
                                team_id: "",
                                team_domain: "",
                                enterprise_id: nil,
                                enterprise_name: nil,
                                channel_id: "",
                                channel_name: project,
                                user_id: "",
                                user_name: username,
                                command: "",
                                text: "deploy alpha options1:x options2:y \(branch)",
                response_url: "",
                trigger_id: "")).wait()
        let expected = SlackResponse(
            response_type: .inChannel,
            text: nil,
            attachments: [
                SlackResponse.Attachment(
                    fallback: "Job \'deploy\' has started at <buildURL|#10>. (project: projectX, branch: feature/branch-X",
                    text: "Job \'deploy\' has started at <buildURL|#10>.",
                    color: "#764FA5",
                    mrkdwn_in: ["text", "fields"],
                    fields: [
                        SlackResponse.Field(title: "Project", value: project, short: true),
                        SlackResponse.Field(title: "Type", value: "alpha", short: true),
                        SlackResponse.Field(title: "User", value: username, short: true),
                        SlackResponse.Field(title: "Branch", value: branch, short: true),
                        SlackResponse.Field(title: "options1", value: "x", short: true),
                        SlackResponse.Field(title: "options2", value: "y", short: true)])],
            mrkdwn: true)

        XCTAssertEqual(response.slackResponse, expected)
    }
    
    func testHelpCommandAction() throws {
        let response = try commandAction(
            worker: request(),
            slack: SlackRequest(token: slackToken,
                                team_id: "",
                                team_domain: "",
                                enterprise_id: nil,
                                enterprise_name: nil,
                                channel_id: "",
                                channel_name: project,
                                user_id: "",
                                user_name: username,
                                command: "",
                                text: "help",
                response_url: "",
                trigger_id: "")).wait()
        
        XCTAssertEqual(response.slackResponse, Command.helpResponse)
    }
    
    func testTestHelpCommandAction() throws {
        let response = try commandAction(
            worker: request(),
            slack: SlackRequest(token: slackToken,
                                team_id: "",
                                team_domain: "",
                                enterprise_id: nil,
                                enterprise_name: nil,
                                channel_id: "",
                                channel_name: project,
                                user_id: "",
                                user_name: username,
                                command: "",
                                text: "test help",
                                response_url: "",
                                trigger_id: "")).wait()
        
        XCTAssertEqual(response.slackResponse, CircleciTestJobRequest.helpResponse)
    }
    
    func testDeployHelpCommandAction() throws {
        let response = try commandAction(
            worker: request(),
            slack: SlackRequest(token: slackToken,
                                team_id: "",
                                team_domain: "",
                                enterprise_id: nil,
                                enterprise_name: nil,
                                channel_id: "",
                                channel_name: project,
                                user_id: "",
                                user_name: username,
                                command: "",
                                text: "deploy help",
                                response_url: "",
                                trigger_id: "")).wait()
        
        XCTAssertEqual(response.slackResponse, CircleciDeployJobRequest.helpResponse)
    }
    
    func testErrorCommandAction() throws {
        let response = try commandAction(
            worker: request(),
            slack: SlackRequest(token: slackToken,
                                team_id: "",
                                team_domain: "",
                                enterprise_id: nil,
                                enterprise_name: nil,
                                channel_id: "",
                                channel_name: project,
                                user_id: "",
                                user_name: username,
                                command: "",
                                text: "",
                                response_url: "",
                                trigger_id: "")).wait()
        
        XCTAssertEqual(response.slackResponse, SlackResponse.error(helpResponse: Command.helpResponse, text: "Unknown command ()"))
    }
}
