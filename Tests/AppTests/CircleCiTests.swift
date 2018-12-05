//
//  CircleciTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 08. 30..
//

import APIConnect
import APIModels

import XCTest
import HTTP

@testable import App

class CircleCiTests: XCTestCase {
    let project = "projectX"
    let branch = "feature/branch-X"
    var urlEncodedBranch: String {
        return branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
    let username = "tester"
    let options = ["options1:x", "options2:y"]
    let type = "alpha"

    override func setUp() {
        super.setUp()
        Environment.env = [
            CircleCiJobRequest.Config.tokens.rawValue: CircleCiJobRequest.Config.tokens.rawValue,
            SlackRequest.Config.slackToken.rawValue: SlackRequest.Config.slackToken.rawValue,
            CircleCiJobRequest.Config.company.rawValue: CircleCiJobRequest.Config.company.rawValue,
            CircleCiJobRequest.Config.vcs.rawValue: CircleCiJobRequest.Config.vcs.rawValue,
            CircleCiJobRequest.Config.projects.rawValue: project,
        ]
        Environment.api = { hostname, _ in
            return { context, _ in
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
    
    func testTestJob() throws {
        // init
        let goodJob = CircleCiTestJob(project: project,
                                      branch: branch,
                                      options: options,
                                      username: username)
        XCTAssertEqual(goodJob.name, CircleCiJobKind.test.rawValue)
        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
        XCTAssertEqual(goodJob.buildParameters,
                       ["DEPLOY_OPTIONS": options.joined(separator: " "),
                        "CIRCLE_JOB": CircleCiJobKind.test.rawValue])

        // parse
        let parsedJob = try CircleCiTestJob.parse(project: project,
                                                  parameters: [branch],
                                                  options: options,
                                                  username: username).right as? CircleCiTestJob
        XCTAssertEqual(goodJob, parsedJob)
        
        let helpResponse = try CircleCiTestJob.parse(project: project,
                                                     parameters: ["help"],
                                                     options: options,
                                                     username: username).left
        XCTAssertEqual(helpResponse, CircleCiTestJob.helpResponse)

        // parse error
        do {
            _ = try CircleCiTestJob.parse(project: project, parameters: [], options: [], username: username)
            XCTFail("We should have an exception")
        } catch {
            guard let error = error as? CircleCiError else {
                XCTFail("We should have a CircleCiError")
                return
            }
            if case CircleCiError.parse = error {
                XCTAssertEqual(error.text, "Parse error (No branch found: ())")
            } else {
                XCTFail("We should have a parse error")
            }
        }
        
    }
    
    func testDeployJob() throws {
        // init
        let goodJob = CircleCiDeployJob(project: project,
                                        branch: branch,
                                        options: options,
                                        username: username,
                                        type: type)
        XCTAssertEqual(goodJob.name, CircleCiJobKind.deploy.rawValue)
        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
        XCTAssertEqual(goodJob.buildParameters,
                       ["DEPLOY_TYPE": type,
                        "DEPLOY_OPTIONS": options.joined(separator: " "),
                        "CIRCLE_JOB": CircleCiJobKind.deploy.rawValue])
        
        // parse
        let parsedJob = try CircleCiDeployJob.parse(project: project,
                                                    parameters: [type, branch],
                                                    options: options,
                                                    username: username).right as? CircleCiDeployJob
        XCTAssertEqual(goodJob, parsedJob)
        
        let helpResponse = try CircleCiDeployJob.parse(project: project,
                                                       parameters: ["help"],
                                                       options: options,
                                                       username: username).left
        XCTAssertEqual(helpResponse, CircleCiDeployJob.helpResponse)
        
        // parse error
        do {
            _ = try CircleCiDeployJob.parse(project: project, parameters: ["unknown"], options: [], username: username)
            XCTFail("We should have an exception")
        } catch {
            guard let error = error as? CircleCiError else {
                XCTFail("We should have a CircleCiError")
                return
            }
            if case CircleCiError.parse = error {
                XCTAssertEqual(error.text, "Parse error (Unknown type: (unknown))")
            } else {
                XCTFail("We should have a parse error")
            }
        }

    }

    func testSlackRequest() {
        // no channel
        let noChannelRequest = SlackRequest.template(channelName: "nochannel")
        let noChannelResult = CircleCiJobRequest.slackRequest(noChannelRequest)
        XCTAssertEqual(noChannelResult.left, SlackResponse.error(text: CircleCiError.noChannel("nochannel").text))
        
        // unknown command
        let unknownCommandRequest = SlackRequest.template(channelName: project, text: "command branch")
        let unknownCommandResult = CircleCiJobRequest.slackRequest(unknownCommandRequest)
        XCTAssertEqual(unknownCommandResult.left,
                       SlackResponse.error(text: CircleCiError.unknownCommand("command branch").text))
        
        // help command
        let helpRequest = SlackRequest.template(channelName: project, text: "help")
        let helpResult = CircleCiJobRequest.slackRequest(helpRequest)
        XCTAssertEqual(helpResult.left, CircleCiJobRequest.helpResponse)
        
        // test job
        let testRequest = SlackRequest.template(channelName: project,
                                                userName: username,
                                                text: "test \(branch) \(options.joined(separator: " "))")
        let testResponse = CircleCiJobRequest.slackRequest(testRequest)
        XCTAssertEqual(testResponse.right?.job as? CircleCiTestJob,
                       CircleCiTestJob(project: project,
                                       branch: branch,
                                       options: options,
                                       username: username))
        
        // deploy job
        let deployRequest = SlackRequest.template(channelName: project,
                                                  userName: username,
                                                  text: "deploy \(type) \(options.joined(separator: " ")) \(branch)")
        let deployResponse = CircleCiJobRequest.slackRequest(deployRequest)
        XCTAssertEqual(deployResponse.right?.job as? CircleCiDeployJob,
                       CircleCiDeployJob(project: project,
                                         branch: branch,
                                         options: options,
                                         username: username,
                                         type: type))
    }
    
    func testApiWithSlack() throws {
        let api = try CircleCiJobRequest.apiWithSlack(context())

        // passthrough
        let passthrough: Either<SlackResponse, CircleCiJobRequest> = .left(SlackResponse.error(text: ""))
        XCTAssertEqual(try api(passthrough).wait().left, passthrough.left)
        
        // build response
        let job = CircleCiTestJob(project: project,
                                  branch: branch,
                                  options: options,
                                  username: username)
        let request: Either<SlackResponse, CircleCiJobRequest> = .right(CircleCiJobRequest(job: job))
        let expected = CircleCiResponse(buildURL: "buildURL",
                                        buildNum: 10)
        let response = try api(request).wait().right
        XCTAssertEqual(response?.job as? CircleCiTestJob, job)
        XCTAssertEqual(response?.response, expected)
    }
        
    func testResponseToSlack() {
        // test
        let testResponse = CircleCiBuildResponse(response: CircleCiResponse(buildURL: "buildURL",
                                                                            buildNum: 10),
                                             job: CircleCiTestJob(project: project,
                                                                  branch: branch,
                                                                  options: options,
                                                                  username: username))
        let testSlackResponse = CircleCiJobRequest.responseToSlack(testResponse)
        let expectedTestSlackResponse = SlackResponse(
            responseType: .inChannel,
            text: nil,
            attachments: [
                SlackResponse.Attachment(
                    fallback: "Job \'test\' has started at <buildURL|#10>. "
                        + "(project: projectX, branch: feature/branch-X)",
                    text: "Job \'test\' has started at <buildURL|#10>.",
                    color: "#764FA5",
                    mrkdwnIn: ["text", "fields"],
                    fields: [
                        SlackResponse.Field(title: "Project", value: project, short: true),
                        SlackResponse.Field(title: "Branch", value: branch, short: true),
                        SlackResponse.Field(title: "User", value: username, short: true),
                        SlackResponse.Field(title: "options1", value: "x", short: true),
                        SlackResponse.Field(title: "options2", value: "y", short: true)])
            ],
            mrkdwn: true)
        XCTAssertEqual(testSlackResponse, expectedTestSlackResponse)

        // deploy
        let deployResponse = CircleCiBuildResponse(response: CircleCiResponse(buildURL: "buildURL",
                                                                              buildNum: 10),
                                                   job: CircleCiDeployJob(project: project,
                                                                          branch: branch,
                                                                          options: options,
                                                                          username: username,
                                                                          type: type))
        let deploySlackResponse = CircleCiJobRequest.responseToSlack(deployResponse)
        let expectedDeploySlackResponse = SlackResponse(
            responseType: .inChannel,
            text: nil,
            attachments: [
                SlackResponse.Attachment(
                    fallback: "Job \'deploy\' has started at <buildURL|#10>. "
                        + "(project: projectX, branch: feature/branch-X)",
                    text: "Job \'deploy\' has started at <buildURL|#10>.",
                    color: "#764FA5",
                    mrkdwnIn: ["text", "fields"],
                    fields: [
                        SlackResponse.Field(title: "Project", value: project, short: true),
                        SlackResponse.Field(title: "Type", value: type, short: true),
                        SlackResponse.Field(title: "User", value: username, short: true),
                        SlackResponse.Field(title: "Branch", value: branch, short: true),
                        SlackResponse.Field(title: "options1", value: "x", short: true),
                        SlackResponse.Field(title: "options2", value: "y", short: true)])
            ],
            mrkdwn: true)
        XCTAssertEqual(deploySlackResponse, expectedDeploySlackResponse)

    }
}
