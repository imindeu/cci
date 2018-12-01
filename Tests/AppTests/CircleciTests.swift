//
//  CircleciTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 08. 30..
//

import APIConnect
import XCTest
import Vapor

@testable import App

class CircleciTests: XCTestCase {
    let project = "projectX"
    let branch = "feature/branch-X"
    var urlEncodedBranch: String {
        return branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
    let username = "tester"
    let options = ["options1:x", "options2:y"]
    let type = "alpha"
    let headers = HTTPHeaders([
        ("Accept", "application/json"),
        ("Content-Type", "application/json")
        ])
    let decoder = JSONDecoder()

    func context() throws -> Context {
        let app = try Application()
        return Request(using: app)
    }

    override func setUp() {
        super.setUp()
        Environment.env = [
            "circleCiTokens": "circleCiTokens",
            "slackToken": "slackToken",
            "company": "company",
            "vcs": "vcs",
            "projects": "projectX"
        ]
        Environment.api = { hostname, _ in
            return { context, _ in
                if hostname == "circleci.com" {
                    return Future.map(on: context, {
                        return HTTPResponse(
                            status: .ok,
                            version: HTTPVersion.init(major: 1, minor: 1),
                            headers: HTTPHeaders([]),
                            body: "{\"build_url\":\"buildURL\",\"build_num\":10}")
                    })

                } else {
                    return Environment.emptyApi(context)
                }
            }
        }
    }
    
    override func tearDown() {
        super.tearDown()
    }

    private struct Build: Decodable, Equatable {
        struct BuildParameters: Decodable, Equatable {
            let DEPLOY_OPTIONS: String
            let CIRCLE_JOB: String
            let DEPLOY_TYPE: String?
        }
        let build_parameters: BuildParameters
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
        let parsedJob = try CircleCiTestJob.parse(project: project, parameters: [branch], options: options, username: username).right as? CircleCiTestJob
        XCTAssertEqual(goodJob, parsedJob)
        
        let helpResponse = try CircleCiTestJob.parse(project: project, parameters: ["help"], options: options, username: username).left
        XCTAssertEqual(helpResponse, CircleCiTestJob.helpResponse)

        // parse error
        do {
            _ = try CircleCiTestJob.parse(project: project, parameters: [], options: [], username: username)
            XCTFail()
        } catch {
            guard let error = error as? CircleCiError else {
                XCTFail()
                return
            }
            if case CircleCiError.parse = error {
                XCTAssertEqual(error.text, "Parse error (No branch found: ())")
            } else {
                XCTFail()
            }
        }

        
    }
    
    func testDeployJob() throws {
        // init
        let goodJob = CircleCiDeployJob(project: project, branch: branch, options: options, username: username, type: type)
        XCTAssertEqual(goodJob.name, CircleCiJobKind.deploy.rawValue)
        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
        XCTAssertEqual(goodJob.buildParameters,
                       ["DEPLOY_TYPE": type,
                        "DEPLOY_OPTIONS": options.joined(separator: " "),
                        "CIRCLE_JOB": CircleCiJobKind.deploy.rawValue])
        
        // parse
        let parsedJob = try CircleCiDeployJob.parse(project: project, parameters: [type, branch], options: options, username: username).right as? CircleCiDeployJob
        XCTAssertEqual(goodJob, parsedJob)
        
        let helpResponse = try CircleCiDeployJob.parse(project: project, parameters: ["help"], options: options, username: username).left
        XCTAssertEqual(helpResponse, CircleCiDeployJob.helpResponse)
        
        // parse error
        do {
            _ = try CircleCiDeployJob.parse(project: project, parameters: ["unknown"], options: [], username: username)
            XCTFail()
        } catch {
            guard let error = error as? CircleCiError else {
                XCTFail()
                return
            }
            if case CircleCiError.parse = error {
                XCTAssertEqual(error.text, "Parse error (Unknown type: (unknown))")
            } else {
                XCTFail()
            }
        }

    }

    func testSlackRequest() {
        // no channel
        let noChannelRequest = SlackRequest.template(channel_name: "nochannel")
        let noChannelResult = CircleCiJobRequest.slackRequest(noChannelRequest)
        XCTAssertEqual(noChannelResult.left, SlackResponse.error(text: CircleCiError.noChannel("nochannel").text))
        
        // unknown command
        let unknownCommandRequest = SlackRequest.template(channel_name: project, text: "command branch")
        let unknownCommandResult = CircleCiJobRequest.slackRequest(unknownCommandRequest)
        XCTAssertEqual(unknownCommandResult.left, SlackResponse.error(text: CircleCiError.unknownCommand("command branch").text))
        
        // help command
        let helpRequest = SlackRequest.template(channel_name: project, text: "help")
        let helpResult = CircleCiJobRequest.slackRequest(helpRequest)
        XCTAssertEqual(helpResult.left, CircleCiJobRequest.helpResponse)
        
        // test job
        let testRequest = SlackRequest.template(channel_name: project,
                                                user_name: username,
                                                text: "test \(branch) \(options.joined(separator: " "))")
        let testResponse = CircleCiJobRequest.slackRequest(testRequest)
        XCTAssertEqual(testResponse.right?.job as? CircleCiTestJob,
                       CircleCiTestJob(project: project,
                                       branch: branch,
                                       options: options,
                                       username: username))
        
        // deploy job
        let deployRequest = SlackRequest.template(channel_name: project,
                                                  user_name: username,
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
        let expected = CircleCiBuild(build_url: "buildURL",
                                     build_num: 10)
        let response = try api(request).wait().right
        XCTAssertEqual(response?.job as? CircleCiTestJob, job)
        XCTAssertEqual(response?.response, expected)
    }
        
    func testResponseToSlack() {
        // test
        let testResponse = CircleCiBuildResponse(response: CircleCiBuild(build_url: "buildURL",
                                                                     build_num: 10),
                                             job: CircleCiTestJob(project: project,
                                                                  branch: branch,
                                                                  options: options,
                                                                  username: username))
        let testSlackResponse = CircleCiJobRequest.responseToSlack(testResponse)
        let expectedTestSlackResponse = SlackResponse(
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
        XCTAssertEqual(testSlackResponse, expectedTestSlackResponse)

        // deploy
        let deployResponse = CircleCiBuildResponse(response: CircleCiBuild(build_url: "buildURL",
                                                                           build_num: 10),
                                                   job: CircleCiDeployJob(project: project,
                                                                          branch: branch,
                                                                          options: options,
                                                                          username: username,
                                                                          type: type))
        let deploySlackResponse = CircleCiJobRequest.responseToSlack(deployResponse)
        let expectedDeploySlackResponse = SlackResponse(
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
                        SlackResponse.Field(title: "Type", value: type, short: true),
                        SlackResponse.Field(title: "User", value: username, short: true),
                        SlackResponse.Field(title: "Branch", value: branch, short: true),
                        SlackResponse.Field(title: "options1", value: "x", short: true),
                        SlackResponse.Field(title: "options2", value: "y", short: true)])],
            mrkdwn: true)
        XCTAssertEqual(deploySlackResponse, expectedDeploySlackResponse)

    }    
}
