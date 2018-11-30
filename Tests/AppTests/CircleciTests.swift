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
    let headers = HTTPHeaders([
        ("Accept", "application/json"),
        ("Content-Type", "application/json")
        ])
    let decoder = JSONDecoder()

    func request() throws -> Request {
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
                       ["DEPLOY_OPTIONS": "options1:x options2:y", "CIRCLE_JOB": "test"])

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
        let type = "alpha"
        
        // init
        let goodJob = CircleCiDeployJob(project: project, branch: branch, options: options, username: username, type: type)
        XCTAssertEqual(goodJob.name, CircleCiJobKind.deploy.rawValue)
        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
        XCTAssertEqual(goodJob.buildParameters,
                       ["DEPLOY_TYPE": "alpha",
                        "DEPLOY_OPTIONS": "options1:x options2:y",
                        "CIRCLE_JOB": "deploy"])
        
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

//    func testTestJobRequest() throws {
//        guard let body = "{\"build_parameters\":{\"DEPLOY_OPTIONS\":\"options1:x options2:y\",\"CIRCLE_JOB\":\"test\"}}".data(using: .utf8) else {
//            XCTFail()
//            return
//        }
//        // init
//        let goodJob = CircleCiTestJob(project: project,
//                                      branch: branch,
//                                      options: options,
//                                      username: username)
//        XCTAssertEqual(goodJob.name, "test")
//        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
//        guard let goodRequest = goodJob.request.right else {
//            XCTFail()
//            return
//        }
//        XCTAssertEqual(goodRequest.urlString, "\(project)/\(urlEncodedBranch)")
//        XCTAssertEqual(goodRequest.headers, headers)
//
//        guard let goodData = goodRequest.body.data else {
//            XCTFail()
//            return
//        }
//        XCTAssertEqual(try decoder.decode(Build.self, from: goodData), try decoder.decode(Build.self, from: body))
//
//        // parse
//        let parsedJob = try CircleciTestJobRequest.parse(project: project,
//                                                         parameters: [branch],
//                                                         options: options,
//                                                         username: username)
//        XCTAssertEqual(goodJob, parsedJob)
//
//        // parse error
//        do {
//            _ = try CircleciTestJobRequest.parse(project: project, parameters: [], options: [], username: username)
//            XCTFail()
//        } catch {
//            guard let error = error as? CircleciError else {
//                XCTFail()
//                return
//            }
//            if case CircleciError.parse = error {
//                XCTAssertEqual(error.slackResponse,
//                               SlackResponse.error(helpResponse: CircleciTestJobRequest.helpResponse,
//                                                   text: "Parse error (No branch found: ())"))
//            } else {
//                XCTFail()
//            }
//        }
//
//        // fetch
//        let response = try goodJob.fetch(worker: request()).wait()
//        let expected = SlackResponse(
//            response_type: .inChannel,
//            text: nil,
//            attachments: [
//                SlackResponse.Attachment(
//                    fallback: "Job \'test\' has started at <buildURL|#10>. (project: projectX, branch: feature/branch-X",
//                    text: "Job \'test\' has started at <buildURL|#10>.",
//                    color: "#764FA5",
//                    mrkdwn_in: ["text", "fields"],
//                    fields: [
//                        SlackResponse.Field(title: "Project", value: project, short: true),
//                        SlackResponse.Field(title: "Branch", value: branch, short: true),
//                        SlackResponse.Field(title: "User", value: username, short: true),
//                        SlackResponse.Field(title: "options1", value: "x", short: true),
//                        SlackResponse.Field(title: "options2", value: "y", short: true)])],
//            mrkdwn: true)
//        XCTAssertEqual(response.slackResponse, expected)
//
//        Environment.pop()
//    }
//
//    func testDeployJobRequest() throws {
//        let type = "alpha"
//        guard let body = "{\"build_parameters\":{\"DEPLOY_TYPE\":\"alpha\",\"DEPLOY_OPTIONS\":\"options1:x options2:y\",\"CIRCLE_JOB\":\"deploy\"}}".data(using: .utf8) else {
//            XCTFail()
//            return
//        }
//
//        Environment.push(Environment.init(circleciTokens: ["circleciToken"],
//                                          slackToken: "slackToken",
//                                          company: "company",
//                                          vcs: "vcs",
//                                          circleciPath: { "\($0)/\($1)" },
//                                          projects: [project],
//                                          circleci: Environment.goodApi("{\"build_url\":\"buildURL\",\"build_num\":10}"),
//                                          slack: Environment.empty.slack))
//
//        // init
//        let goodJob = CircleciDeployJobRequest(project: project, branch: branch, options: options, username: username, type: type)
//        XCTAssertEqual(goodJob.name, "deploy")
//        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
//        guard let goodRequest = goodJob.request.right else {
//            XCTFail()
//            return
//        }
//        XCTAssertEqual(goodRequest.urlString, "\(project)/\(urlEncodedBranch)")
//        XCTAssertEqual(goodRequest.headers, headers)
//
//        guard let goodData = goodRequest.body.data else {
//            XCTFail()
//            return
//        }
//        XCTAssertEqual(try decoder.decode(Build.self, from: goodData), try decoder.decode(Build.self, from: body))
//
//        // parse
//        let parsedJob = try CircleciDeployJobRequest.parse(project: project,
//                                                         parameters: [type, branch],
//                                                         options: options,
//                                                         username: username)
//        XCTAssertEqual(goodJob, parsedJob)
//
//        // parse error
//        do {
//            _ = try CircleciDeployJobRequest.parse(project: project, parameters: ["unknown"], options: [], username: username)
//            XCTFail()
//        } catch {
//            guard let error = error as? CircleciError else {
//                XCTFail()
//                return
//            }
//            if case CircleciError.parse = error {
//                XCTAssertEqual(error.slackResponse,
//                               SlackResponse.error(helpResponse: CircleciDeployJobRequest.helpResponse,
//                                                   text: "Parse error (Unknown type: (unknown))"))
//            } else {
//                XCTFail()
//            }
//        }
//
//        // fetch
//        let response = try goodJob.fetch(worker: request()).wait()
//        let expected = SlackResponse(
//            response_type: .inChannel,
//            text: nil,
//            attachments: [
//                SlackResponse.Attachment(
//                    fallback: "Job \'deploy\' has started at <buildURL|#10>. (project: projectX, branch: feature/branch-X",
//                    text: "Job \'deploy\' has started at <buildURL|#10>.",
//                    color: "#764FA5",
//                    mrkdwn_in: ["text", "fields"],
//                    fields: [
//                        SlackResponse.Field(title: "Project", value: project, short: true),
//                        SlackResponse.Field(title: "Type", value: type, short: true),
//                        SlackResponse.Field(title: "User", value: username, short: true),
//                        SlackResponse.Field(title: "Branch", value: branch, short: true),
//                        SlackResponse.Field(title: "options1", value: "x", short: true),
//                        SlackResponse.Field(title: "options2", value: "y", short: true)])],
//            mrkdwn: true)
//        XCTAssertEqual(response.slackResponse, expected)
//
//        Environment.pop()
//    }
    
}
