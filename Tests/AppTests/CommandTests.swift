//
//  CommandTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 09. 10..
//

import XCTest
import Vapor
@testable import App

class CommandTests: XCTestCase {
    let circleciToken = "circleciToken"
    let slackToken = "slackToken"
    let project = "projectX"
    let branch = "feature/branch-X"
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

    func testTestCommand() throws {
        let slackRequest = SlackRequest(token: slackToken,
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
            trigger_id: "")
        let command = try Command(slack: slackRequest)
        let jobRequest = CircleciTestJobRequest(project: project, branch: branch, options: options, username: username)
        XCTAssertEqual(command, .test(jobRequest))
    }
    
    func testDeployCommand() throws {
        let slackRequest = SlackRequest(token: slackToken,
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
            trigger_id: "")
        let command = try Command(slack: slackRequest)
        let jobRequest = CircleciDeployJobRequest(project: project, branch: branch, options: options, username: username, type: "alpha")
        XCTAssertEqual(command, .deploy(jobRequest))
    }
    
    func testHelpCommand() throws {
        let slackRequest = SlackRequest(token: slackToken,
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
            trigger_id: "")
        let command = try Command(slack: slackRequest)
        XCTAssertEqual(command, .help(Command.self))
    }

    func testTestHelpCommand() throws {
        let slackRequest = SlackRequest(token: slackToken,
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
                                        trigger_id: "")
        let command = try Command(slack: slackRequest)
        XCTAssertEqual(command, .help(CircleciTestJobRequest.self))
    }
    
    func testDeployHelpCommand() throws {
        let slackRequest = SlackRequest(token: slackToken,
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
                                        trigger_id: "")
        let command = try Command(slack: slackRequest)
        XCTAssertEqual(command, .help(CircleciTestJobRequest.self))
    }
    
    func testNoChannel() throws {
        let slackRequest = SlackRequest(token: slackToken,
                                        team_id: "",
                                        team_domain: "",
                                        enterprise_id: nil,
                                        enterprise_name: nil,
                                        channel_id: "",
                                        channel_name: "badChannel",
                                        user_id: "",
                                        user_name: username,
                                        command: "",
                                        text: "deploy help",
                                        response_url: "",
                                        trigger_id: "")
        do {
            _ = try Command(slack: slackRequest)
        } catch {
            guard let error = error as? App.CommandError else {
                XCTFail()
                return
            }
            if case App.CommandError.noChannel = error {
                XCTAssertEqual(error.slackResponse, SlackResponse.error(helpResponse: Command.helpResponse, text: "No project found (channel: \(slackRequest.channel_name))"))
            } else {
                XCTFail()
            }
        }
    }
    
    func assertUnknownCommand(_ slackRequest: SlackRequest, file: StaticString = #file, line: UInt = #line) throws {
        do {
            _ = try Command(slack: slackRequest)
        } catch {
            guard let error = error as? App.CommandError else {
                XCTFail(file: file, line: line)
                return
            }
            if case App.CommandError.unknownCommand = error {
                XCTAssertEqual(error.slackResponse, SlackResponse.error(helpResponse: Command.helpResponse, text: "Unknown command (\(slackRequest.text))"), file: file, line: line)
            } else {
                XCTFail(file: file, line: line)
            }
        }
    }
    
    func testUnknownCommand() throws {
        try assertUnknownCommand(SlackRequest(token: slackToken,
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
                                              trigger_id: ""))
        
        try assertUnknownCommand(SlackRequest(token: slackToken,
                                              team_id: "",
                                              team_domain: "",
                                              enterprise_id: nil,
                                              enterprise_name: nil,
                                              channel_id: "",
                                              channel_name: project,
                                              user_id: "",
                                              user_name: username,
                                              command: "",
                                              text: "unknown command",
                                              response_url: "",
                                              trigger_id: ""))

        try assertUnknownCommand(SlackRequest(token: slackToken,
                                              team_id: "",
                                              team_domain: "",
                                              enterprise_id: nil,
                                              enterprise_name: nil,
                                              channel_id: "",
                                              channel_name: project,
                                              user_id: "",
                                              user_name: username,
                                              command: "",
                                              text: "unknown help command",
                                              response_url: "",
                                              trigger_id: ""))
    }

}
