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
            CircleCi.JobRequest.Config.tokens.rawValue: CircleCi.JobRequest.Config.tokens.rawValue,
            CircleCi.JobRequest.Config.company.rawValue: CircleCi.JobRequest.Config.company.rawValue,
            CircleCi.JobRequest.Config.vcs.rawValue: CircleCi.JobRequest.Config.vcs.rawValue,
            CircleCi.JobRequest.Config.projects.rawValue: project,
            Github.APIRequest.Config.githubAppId.rawValue: Github.APIRequest.Config.githubAppId.rawValue,
            Github.APIRequest.Config.githubPrivateKey.rawValue: privateKeyString
        ]
        Environment.api = { hostname, _ in
            return { context, _ in
                if hostname == "circleci.com" {
                    return pure(HTTPResponse(body: "{\"build_url\":\"buildURL\",\"build_num\":10}"), context)
                } else if hostname == "api.github.com" {
                    return pure(HTTPResponse(body: "{\"token\":\"x\"}"), context)
                } else if hostname == "empty.com" {
                    return pure(HTTPResponse(body: "[]"), context)
                } else if hostname == "error.com" {
                    return pure(HTTPResponse(body: "[{\"state\":\"error\"}]"), context)
                } else if hostname == "success.com" {
                    return pure(HTTPResponse(body: "[{\"state\":\"success\"}]"), context)
                } else {
                    XCTFail("unknown host: \(hostname)")
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
    
    func testBuildsimJob() throws {
        // init
        let goodJob = CircleCiBuildsimJob(project: project,
                                          branch: branch,
                                          options: options,
                                          username: username)
        XCTAssertEqual(goodJob.name, CircleCiJobKind.buildsim.rawValue)
        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
        XCTAssertEqual(goodJob.buildParameters,
                       ["CCI_OPTIONS": options.joined(separator: " "),
                        "CIRCLE_JOB": CircleCiJobKind.buildsim.rawValue])
        
        // parse
        let parsedJob = try CircleCiBuildsimJob.parse(project: project,
                                                      parameters: [branch],
                                                      options: options,
                                                      username: username).right as? CircleCiBuildsimJob
        XCTAssertEqual(goodJob, parsedJob)
        
        let helpResponse = try CircleCiBuildsimJob.parse(project: project,
                                                         parameters: ["help"],
                                                         options: options,
                                                         username: username).left
        XCTAssertEqual(helpResponse, CircleCiBuildsimJob.helpResponse)
        
        // parse error
        do {
            _ = try CircleCiBuildsimJob.parse(project: project, parameters: [], options: [], username: username)
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

    func testSlackRequest() throws {
        // no channel
        let noChannelRequest = Slack.Request.template(channelName: "nochannel")
        let noChannelResult = try CircleCi.slackRequest(noChannelRequest, nil, context()).wait()
        XCTAssertEqual(noChannelResult.left, Slack.Response.error(CircleCi.Error.noChannel("nochannel")))
        
        // unknown command
        let unknownCommandRequest = Slack.Request.template(channelName: project, text: "command branch")
        let unknownCommandResult = try CircleCi.slackRequest(unknownCommandRequest, nil, context()).wait()
        XCTAssertEqual(unknownCommandResult.left,
                       Slack.Response.error(CircleCi.Error.unknownCommand("command branch")))
        
        // help command
        let helpRequest = Slack.Request.template(channelName: project, text: "help")
        let helpResult = try CircleCi.slackRequest(helpRequest, nil, context()).wait()
        XCTAssertEqual(helpResult.left, CircleCi.helpResponse)
        
        // test job
        let testRequest = Slack.Request.template(channelName: project,
                                                 userName: username,
                                                 text: "test \(branch) \(options.joined(separator: " "))")
        let testResponse = try CircleCi.slackRequest(testRequest, nil, context()).wait()
        XCTAssertEqual(testResponse.right?.job as? CircleCiTestJob,
                       CircleCiTestJob(project: project,
                                       branch: branch,
                                       options: options,
                                       username: username))
        
        // deploy job
        let deployRequest = Slack.Request.template(channelName: project,
                                                   userName: username,
                                                   text: "deploy \(type) \(options.joined(separator: " ")) \(branch)")
        let deployResponse = try CircleCi.slackRequest(deployRequest, nil, context()).wait()
        XCTAssertEqual(deployResponse.right?.job as? CircleCiDeployJob,
                       CircleCiDeployJob(project: project,
                                         branch: branch,
                                         options: options,
                                         username: username,
                                         type: type))
    }
    
    // MARK: Slack
    func testApiWithSlack() throws {
        let api = CircleCi.apiWithSlack(context())
        
        // build response
        let job = CircleCiTestJob(project: project,
                                  branch: branch,
                                  options: options,
                                  username: username)
        let request: CircleCi.JobRequest = CircleCi.JobRequest(job: job)
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
                    return pure(HTTPResponse(body: "{\"message\":\"x\"}"), context)
                } else {
                    return Environment.emptyApi(context)
                }
            }
        }
        let api = CircleCi.apiWithSlack(context())
        
        let job = CircleCiTestJob(project: project,
                                  branch: branch,
                                  options: options,
                                  username: username)
        let request: CircleCi.JobRequest = CircleCi.JobRequest(job: job)
        let expected = CircleCi.Response(message: "x")
        let response = try api(request).wait().right
        XCTAssertEqual(response?.job as? CircleCiTestJob, job)
        XCTAssertEqual(response?.response, expected)
        
    }
    func testResponseToSlack() {
        // test
        let testResponse = CircleCi.BuildResponse(response: CircleCi.Response(buildURL: "buildURL",
                                                                              buildNum: 10),
                                             job: CircleCiTestJob(project: project,
                                                                  branch: branch,
                                                                  options: options,
                                                                  username: username))
        let testSlackResponse = CircleCi.responseToSlack(testResponse)
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
        let deployResponse = CircleCi.BuildResponse(response: CircleCi.Response(buildURL: "buildURL",
                                                                                buildNum: 10),
                                                   job: CircleCiDeployJob(project: project,
                                                                          branch: branch,
                                                                          options: options,
                                                                          username: username,
                                                                          type: type))
        let deploySlackResponse = CircleCi.responseToSlack(deployResponse)
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

        let messageResponse = CircleCi.BuildResponse(response: CircleCi.Response(message: "x"),
                                                     job: CircleCiTestJob(project: project,
                                                                          branch: branch,
                                                                          options: options,
                                                                          username: username))
        let messageSlackResponse = CircleCi.responseToSlack(messageResponse)
        XCTAssertEqual(messageSlackResponse, Slack.Response.error(CircleCi.Error.badResponse("x")))

    }

    // MARK: Github
    func testGithubRequest() throws {
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        
        // ci should run, if no status and waiting for review labeling
        let branchNoStatus = Github.Branch.template(
            ref: branch,
            repo: Github.Repository.template(
                url: "https://empty.com/repo/company/project"))
        let devNoStatusPullRequest = Github.PullRequest(url: "",
                                                        id: 0,
                                                        title: "test",
                                                        body: "",
                                                        head: branchNoStatus,
                                                        base: Github.Branch.template())
        let labeledDevNoStatuRequest = Github.Payload(action: .labeled,
                                                      pullRequest: devNoStatusPullRequest,
                                                      label: Github.waitingForReviewLabel,
                                                      installation: Github.Installation(id: 1),
                                                      repository: Github.Repository.template(name: project))
        let testDevNoStatusRequest = try CircleCi.githubRequest(
            labeledDevNoStatuRequest,
            pullRequestHeaders,
            context()).wait()
        XCTAssertEqual(testDevNoStatusRequest.right?.job as? CircleCiTestJob,
                       CircleCiTestJob(project: project,
                                       branch: branch,
                                       options: [],
                                       username: "cci"))
        
        // ci should run, if error is the last commit status and waiting for review labeling
        let branchErrorStatus = Github.Branch.template(
            ref: branch,
            repo: Github.Repository.template(
                url: "https://error.com/repo/company/project"))
        let devErrorStatusPullRequest = Github.PullRequest(url: "",
                                                           id: 0,
                                                           title: "test",
                                                           body: "",
                                                           head: branchErrorStatus,
                                                           base: Github.Branch.template())
        let labeledDevErrorStatuRequest = Github.Payload(action: .labeled,
                                                         pullRequest: devErrorStatusPullRequest,
                                                         label: Github.waitingForReviewLabel,
                                                         installation: Github.Installation(id: 1),
                                                         repository: Github.Repository.template(name: project))
        let testDevErrorStatusRequest = try CircleCi.githubRequest(
            labeledDevErrorStatuRequest,
            pullRequestHeaders,
            context()).wait()
        XCTAssertEqual(testDevErrorStatusRequest.right?.job as? CircleCiTestJob,
                       CircleCiTestJob(project: project,
                                       branch: branch,
                                       options: [],
                                       username: "cci"))
        
        // ci should not run, if success is the last commit status and waiting for review labeling
        let branchSuccessStatus = Github.Branch.template(
            ref: branch,
            repo: Github.Repository.template(
                url: "https://success.com/repo/company/project"))
        let devSuccessStatusPullRequest = Github.PullRequest(url: "",
                                                             id: 0,
                                                             title: "test",
                                                             body: "",
                                                             head: branchSuccessStatus,
                                                             base: Github.Branch.template())
        let labeledDevSuccessStatuRequest = Github.Payload(action: .labeled,
                                                           pullRequest: devSuccessStatusPullRequest,
                                                           label: Github.waitingForReviewLabel,
                                                           installation: Github.Installation(id: 1),
                                                           repository: Github.Repository.template(name: project))
        
        let testDevSuccessStatusRequest = try CircleCi.githubRequest(
            labeledDevSuccessStatuRequest,
            pullRequestHeaders,
            context()).wait()
        XCTAssertEqual(testDevSuccessStatusRequest.left, Github.PayloadResponse())
        
        let masterPullRequest = Github.PullRequest(url: "",
                                                   id: 0,
                                                   title: "test",
                                                   body: "",
                                                   head: Github.Branch.template(ref: branch),
                                                   base: Github.Branch.template(ref: "master"))
        let labeledMasterRequest = Github.Payload(action: .labeled,
                                                  pullRequest: masterPullRequest,
                                                  label: Github.waitingForReviewLabel,
                                                  repository: Github.Repository.template(name: project))
        
        let testMasterRequest = try CircleCi.githubRequest(labeledMasterRequest, pullRequestHeaders, context()).wait()
        XCTAssertEqual(testMasterRequest.right?.job as? CircleCiTestJob,
                       CircleCiTestJob(project: project,
                                       branch: branch,
                                       options: ["restrict_fixme_comments:true"],
                                       username: "cci"))
        
        let emptyRequest = Github.Payload()
        let testEmptyRequest = try CircleCi.githubRequest(emptyRequest, nil, context()).wait()
        XCTAssertEqual(testEmptyRequest.left, Github.PayloadResponse())

    }
    
}
