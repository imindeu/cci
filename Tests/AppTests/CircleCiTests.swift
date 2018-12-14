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
                       ["CCI_OPTIONS": options.joined(separator: " "),
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
            guard let error = error as? CircleCi.Error else {
                XCTFail("We should have a CircleCi.Error")
                return
            }
            if case CircleCi.Error.noBranch = error {
                XCTAssertEqual(error.localizedDescription, CircleCi.Error.noBranch("").localizedDescription)
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
                       ["CCI_DEPLOY_TYPE": type,
                        "CCI_OPTIONS": options.joined(separator: " "),
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
            guard let error = error as? CircleCi.Error else {
                XCTFail("We should have a CircleCi.Error")
                return
            }
            if case CircleCi.Error.unknownType = error {
                XCTAssertEqual(error.localizedDescription, CircleCi.Error.unknownType("unknown").localizedDescription)
            } else {
                XCTFail("We should have a parse error")
            }
        }

    }

    func testSlackRequest() {
        // no channel
        let noChannelRequest = Slack.Request.template(channelName: "nochannel")
        let noChannelResult = CircleCiJobRequest.slackRequest(noChannelRequest)
        XCTAssertEqual(noChannelResult.left, Slack.Response.error(CircleCi.Error.noChannel("nochannel")))
        
        // unknown command
        let unknownCommandRequest = Slack.Request.template(channelName: project, text: "command branch")
        let unknownCommandResult = CircleCiJobRequest.slackRequest(unknownCommandRequest)
        XCTAssertEqual(unknownCommandResult.left,
                       Slack.Response.error(CircleCi.Error.unknownCommand("command branch")))
        
        // help command
        let helpRequest = Slack.Request.template(channelName: project, text: "help")
        let helpResult = CircleCiJobRequest.slackRequest(helpRequest)
        XCTAssertEqual(helpResult.left, CircleCiJobRequest.helpResponse)
        
        // test job
        let testRequest = Slack.Request.template(channelName: project,
                                                userName: username,
                                                text: "test \(branch) \(options.joined(separator: " "))")
        let testResponse = CircleCiJobRequest.slackRequest(testRequest)
        XCTAssertEqual(testResponse.right?.job as? CircleCiTestJob,
                       CircleCiTestJob(project: project,
                                       branch: branch,
                                       options: options,
                                       username: username))
        
        // deploy job
        let deployRequest = Slack.Request.template(channelName: project,
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
        let api = CircleCiJobRequest.apiWithSlack(context())

        // passthrough
        let passthrough: Either<Slack.Response, CircleCiJobRequest> = .left(Slack.Response(responseType: .ephemeral,
                                                                                         text: nil,
                                                                                         attachments: [],
                                                                                         mrkdwn: nil))
        XCTAssertEqual(try api(passthrough).wait().left, passthrough.left)
        
        // build response
        let job = CircleCiTestJob(project: project,
                                  branch: branch,
                                  options: options,
                                  username: username)
        let request: Either<Slack.Response, CircleCiJobRequest> = .right(CircleCiJobRequest(job: job))
        let expected = CircleCi.Response(buildURL: "buildURL",
                                        buildNum: 10)
        let response = try api(request).wait().right
        XCTAssertEqual(response?.job as? CircleCiTestJob, job)
        XCTAssertEqual(response?.response, expected)
    }
    
    func testApiWithSlackMessage() throws {
        Environment.api = { hostname, _ in
            return { context, _ in
                if hostname == "circleci.com" {
                    let response = HTTPResponse(
                        status: .ok,
                        version: HTTPVersion(major: 1, minor: 1),
                        headers: HTTPHeaders([]),
                        body: "{\"message\":\"x\"}")
                    return pure(response, context)
                } else {
                    return Environment.emptyApi(context)
                }
            }
        }
        let api = CircleCiJobRequest.apiWithSlack(context())
        
        let job = CircleCiTestJob(project: project,
                                  branch: branch,
                                  options: options,
                                  username: username)
        let request: Either<Slack.Response, CircleCiJobRequest> = .right(CircleCiJobRequest(job: job))
        let expected = CircleCi.Response(message: "x")
        let response = try api(request).wait().right
        XCTAssertEqual(response?.job as? CircleCiTestJob, job)
        XCTAssertEqual(response?.response, expected)
        
    }
    func testResponseToSlack() {
        // test
        let testResponse = CircleCiBuildResponse(response: CircleCi.Response(buildURL: "buildURL",
                                                                            buildNum: 10),
                                             job: CircleCiTestJob(project: project,
                                                                  branch: branch,
                                                                  options: options,
                                                                  username: username))
        let testSlackResponse = CircleCiJobRequest.responseToSlack(testResponse)
        let expectedTestSlackResponse = Slack.Response(
            responseType: .inChannel,
            text: nil,
            attachments: [
                Slack.Response.Attachment(
                    fallback: "Job \'test\' has started at <buildURL|#10>. "
                        + "(project: projectX, branch: feature/branch-X)",
                    text: "Job \'test\' has started at <buildURL|#10>.",
                    color: "#764FA5",
                    mrkdwnIn: ["text", "fields"],
                    fields: [
                        Slack.Response.Field(title: "Project", value: project, short: true),
                        Slack.Response.Field(title: "Branch", value: branch, short: true),
                        Slack.Response.Field(title: "User", value: username, short: true),
                        Slack.Response.Field(title: "options1", value: "x", short: true),
                        Slack.Response.Field(title: "options2", value: "y", short: true)])
            ],
            mrkdwn: true)
        XCTAssertEqual(testSlackResponse, expectedTestSlackResponse)

        // deploy
        let deployResponse = CircleCiBuildResponse(response: CircleCi.Response(buildURL: "buildURL",
                                                                              buildNum: 10),
                                                   job: CircleCiDeployJob(project: project,
                                                                          branch: branch,
                                                                          options: options,
                                                                          username: username,
                                                                          type: type))
        let deploySlackResponse = CircleCiJobRequest.responseToSlack(deployResponse)
        let expectedDeploySlackResponse = Slack.Response(
            responseType: .inChannel,
            text: nil,
            attachments: [
                Slack.Response.Attachment(
                    fallback: "Job \'deploy\' has started at <buildURL|#10>. "
                        + "(project: projectX, branch: feature/branch-X)",
                    text: "Job \'deploy\' has started at <buildURL|#10>.",
                    color: "#764FA5",
                    mrkdwnIn: ["text", "fields"],
                    fields: [
                        Slack.Response.Field(title: "Project", value: project, short: true),
                        Slack.Response.Field(title: "Type", value: type, short: true),
                        Slack.Response.Field(title: "User", value: username, short: true),
                        Slack.Response.Field(title: "Branch", value: branch, short: true),
                        Slack.Response.Field(title: "options1", value: "x", short: true),
                        Slack.Response.Field(title: "options2", value: "y", short: true)])
            ],
            mrkdwn: true)
        XCTAssertEqual(deploySlackResponse, expectedDeploySlackResponse)

        let messageResponse = CircleCiBuildResponse(response: CircleCi.Response(message: "x"),
                                                    job: CircleCiTestJob(project: project,
                                                                         branch: branch,
                                                                         options: options,
                                                                         username: username))
        let messageSlackResponse = CircleCiJobRequest.responseToSlack(messageResponse)
        XCTAssertEqual(messageSlackResponse, Slack.Response.error(CircleCi.Error.badResponse("x")))

    }

}
