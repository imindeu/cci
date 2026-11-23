//
//  CircleciTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 08. 30..
//

import APIConnect
import APIModels
import APIService
import Mocks

import XCTest
import Vapor

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
    
    private class MockAPI: BackendAPIType {
        
        func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {

            
            switch request.host {
            case "circleci.com":
                return pure(MockHTTPResponse.okResponse(body:"{\"number\": 10, \"message\":\"x\"}"), Service.mockContext)
            case "api.github.com":
                return pure(MockHTTPResponse.okResponse(body:"{\"token\":\"x\"}"), Service.mockContext)
            case "empty.com":
                return pure(MockHTTPResponse.okResponse(body:"[]"), Service.mockContext)
            case "error.com":
                return pure(MockHTTPResponse.okResponse(body:"[{\"state\":\"error\"}]"), Service.mockContext)
            case "success.com":
                return pure(MockHTTPResponse.okResponse(body:"[{\"state\":\"success\"}]"), Service.mockContext)
            default:
                XCTFail("unknown host: \(request.host)")
                return pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
            }
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        
        Environment.env = [
            CircleCi.JobTriggerRequest.Config.tokens.rawValue: CircleCi.JobTriggerRequest.Config.tokens.rawValue,
            CircleCi.JobTriggerRequest.Config.company.rawValue: CircleCi.JobTriggerRequest.Config.company.rawValue,
            CircleCi.JobTriggerRequest.Config.vcs.rawValue: CircleCi.JobTriggerRequest.Config.vcs.rawValue,
            CircleCi.JobTriggerRequest.Config.projects.rawValue: project,
            Github.APIRequest.Config.githubAppId.rawValue: Github.APIRequest.Config.githubAppId.rawValue,
            Github.APIRequest.Config.githubPrivateKey.rawValue: Service.privateKeyString
        ]
        
        try await Service.loadTest(MockAPI())
    }

    func testTestJob() throws {
        // init
        let goodJob = CircleCiTestJob(project: .unknown(project),
                                      branch: branch,
                                      options: options,
                                      username: username)
        XCTAssertEqual(goodJob.name, CircleCiJobKind.test.rawValue)
        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
        XCTAssertEqual(
            try goodJob.body.flatMap { try Service.decoder.decode(CircleCiJobTriggerRequestBody.self, from: $0).parameters },
           .init(job: CircleCiJobKind.test.rawValue, deploy_type: "", options: options.joined(separator: " "))
        )
        
        // parse
        let parsedJob = try CircleCiTestJob.parse(project: .unknown(project),
                                                  parameters: [branch],
                                                  options: options,
                                                  username: username).right as? CircleCiTestJob
        XCTAssertEqual(goodJob, parsedJob)
        
        let helpResponse = try CircleCiTestJob.parse(project: .unknown(project),
                                                     parameters: ["help"],
                                                     options: options,
                                                     username: username).left
        XCTAssertEqual(helpResponse, CircleCiTestJob.helpResponse)
        
        // parse error
        do {
            _ = try CircleCiTestJob.parse(project: .unknown(project), parameters: [], options: [], username: username)
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
        let goodJob = CircleCiBuildsimJob(project: .unknown(project),
                                          branch: branch,
                                          options: options,
                                          username: username)
        XCTAssertEqual(goodJob.name, CircleCiJobKind.buildsim.rawValue)
        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
        XCTAssertEqual(try goodJob.body.flatMap { try Service.decoder.decode(CircleCiJobTriggerRequestBody.self, from: $0).parameters },
                       .init(job: CircleCiJobKind.buildsim.rawValue,
                             deploy_type: "",
                             options: options.joined(separator: " ")))
        
        // parse
        let parsedJob = try CircleCiBuildsimJob.parse(project: .unknown(project),
                                                      parameters: [branch],
                                                      options: options,
                                                      username: username).right as? CircleCiBuildsimJob
        XCTAssertEqual(goodJob, parsedJob)
        
        let helpResponse = try CircleCiBuildsimJob.parse(project: .unknown(project),
                                                         parameters: ["help"],
                                                         options: options,
                                                         username: username).left
        XCTAssertEqual(helpResponse, CircleCiBuildsimJob.helpResponse)
        
        // parse error
        do {
            _ = try CircleCiBuildsimJob.parse(project: .unknown(project), parameters: [], options: [], username: username)
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
        let goodJob = CircleCiDeployJob(project: .unknown(project),
                                        branch: branch,
                                        type: type,
                                        options: options,
                                        username: username)
        XCTAssertEqual(goodJob.name, CircleCiJobKind.deploy.rawValue)
        XCTAssertEqual(goodJob.urlEncodedBranch, urlEncodedBranch)
        XCTAssertEqual(try goodJob.body.flatMap { try Service.decoder.decode(CircleCiJobTriggerRequestBody.self, from: $0).parameters },
                       .init(job: CircleCiJobKind.deploy.rawValue,
                             deploy_type: type,
                             options: options.joined(separator: " ")))
        
        // parse
        let parsedJob = try CircleCiDeployJob.parse(project: .unknown(project),
                                                    parameters: [type, branch],
                                                    options: options,
                                                    username: username).right as? CircleCiDeployJob
        XCTAssertEqual(goodJob, parsedJob)
        
        let helpResponse = try CircleCiDeployJob.parse(project: .iOS4DM,
                                                       parameters: ["help"],
                                                       options: options,
                                                       username: username).left
        XCTAssertEqual(helpResponse, CircleCiDeployJob.helpResponse)
        
        let goodFourDJob = CircleCiDeployJob(project: .iOS4DM,
                                             branch: branch,
                                             type: "beta",
                                             options: options + [
                                                "test_release:true",
                                                "branch:\(branch)",
                                                "project_name:FourDMotion"
                                             ],
                                             username: username)
        let fourdResponse = try CircleCiDeployJob.parse(project: .iOS4DM,
                                                        parameters: ["fourd", "beta", branch],
                                                        options: options,
                                                        username: username).right as? CircleCiDeployJob
        XCTAssertEqual(fourdResponse, goodFourDJob)
        
        // parse error
        do {
            _ = try CircleCiDeployJob.parse(project: .unknown(project), parameters: ["unknown"], options: [], username: username)
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

    func testAndroidDeployJob() throws {
        func parse(_ project: CircleCiProject, _ parameters: [String]) throws -> CircleCiDeployJob? {
            return try CircleCiDeployJob.parse(project: project,
                                               parameters: parameters,
                                               options: options,
                                               username: username).right as? CircleCiDeployJob
        }
        func job(_ project: CircleCiProject, _ branch: String, _ type: String, _ extraOptions: [String]) -> CircleCiDeployJob {
            return CircleCiDeployJob(project: project,
                                     branch: branch,
                                     type: type,
                                     options: options + extraOptions,
                                     username: username)
        }

        // FourDMotion alpha and beta deploy the `fourdmotion` Gradle subproject
        XCTAssertEqual(try parse(.android4DM, ["fourd", "alpha", "golf-port"]),
                       job(.android4DM, "golf-port", "alpha",
                           ["test_release:true", "branch:golf-port", "project_name:fourdmotion"]))
        XCTAssertEqual(try parse(.android4DM, ["fourd", "beta"]),
                       job(.android4DM, "fourd", "beta", ["branch:fourd", "project_name:fourdmotion"]))

        // OrthoCor on Android and FourDMotion on iOS are unchanged, production included
        XCTAssertEqual(try parse(.android4DM, ["oc", "app_store"]),
                       job(.android4DM, "release_oc", "app_store", ["branch:release_oc", "project_name:orthocor"]))
        XCTAssertEqual(try parse(.iOS4DM, ["fourd", "alpha"]),
                       job(.iOS4DM, "dev", "alpha", ["branch:dev", "project_name:FourDMotion"]))
        XCTAssertEqual(try parse(.iOS4DM, ["fourd", "app_store"]),
                       job(.iOS4DM, "release", "app_store", ["branch:release", "project_name:FourDMotion"]))

        // No production release of FourDMotion on Android, and no SinglePlane there at all
        XCTAssertThrowsError(try parse(.android4DM, ["fourd", "app_store"])) { error in
            XCTAssertEqual(error.localizedDescription,
                           "Invalid deploy combination: (fourd app_store - 4dmotion-android)")
        }
        for parameters in [["fourd", "app_store", "golf-port"], ["sp", "alpha"]] {
            XCTAssertThrowsError(try parse(.android4DM, parameters)) { error in
                guard case .invalidDeployCombination? = error as? CircleCi.Error else {
                    XCTFail("\(parameters) should be an invalid deploy combination, not \(error)")
                    return
                }
            }
        }
    }

    func testSlackRequest() async throws {
        // no channel
        let noChannelRequest = Slack.Request.template(channelName: "nochannel")
        let noChannelResult = try await CircleCi.slackRequest(noChannelRequest, nil, Service.mockContext).get()
        XCTAssertEqual(noChannelResult.left, Slack.Response.error(CircleCi.Error.noChannel("nochannel")))
        
        // unknown command
        let unknownCommandRequest = Slack.Request.template(channelName: project, text: "command branch")
        let unknownCommandResult = try await CircleCi.slackRequest(unknownCommandRequest, nil, Service.mockContext).get()
        XCTAssertEqual(unknownCommandResult.left,
                       Slack.Response.error(CircleCi.Error.unknownCommand("command branch")))
        
        // help command
        let helpRequest = Slack.Request.template(channelName: project, text: "help")
        let helpResult = try await CircleCi.slackRequest(helpRequest, nil, Service.mockContext).get()
        XCTAssertEqual(helpResult.left, CircleCi.helpResponse)
        
        // test job
        let testRequest = Slack.Request.template(channelName: project,
                                                 userName: username,
                                                 text: "test \(branch) \(options.joined(separator: " "))")
        let testResponse = try await CircleCi.slackRequest(testRequest, nil, Service.mockContext).get()
        XCTAssertEqual(testResponse.right?.request as? CircleCiTestJob,
                       CircleCiTestJob(project: .unknown(project),
                                       branch: branch,
                                       options: options,
                                       username: username))
        
        // deploy job
        let deployRequest = Slack.Request.template(channelName: project,
                                                   userName: username,
                                                   text: "deploy \(type) \(options.joined(separator: " ")) \(branch)")
        let deployResponse = try await CircleCi.slackRequest(deployRequest, nil, Service.mockContext).get()
        XCTAssertEqual(deployResponse.right?.request as? CircleCiDeployJob,
                       CircleCiDeployJob(project: .unknown(project),
                                         branch: branch,
                                         type: type,
                                         options: options,
                                         username: username))
    }
    
    // MARK: Slack
    
    func testApiWithSlackMessage() async throws {
        let api = CircleCi.apiWithSlack(Service.mockContext)
        let job = CircleCiTestJob(project: .unknown(project),
                                  branch: branch,
                                  options: options,
                                  username: username)
        let request: CircleCi.JobTriggerRequest = CircleCi.JobTriggerRequest(request: job)
        let expected = CircleCi.JobTrigger.Response(number: 10, state: nil, createdAt: nil, message: "x")
        let response = try await api(request).get().right
        XCTAssertEqual(response?.request as? CircleCiTestJob, job)
        XCTAssertEqual(response?.responseObject, expected)

    }

    func testApiWithSlackProjectWithoutToken() async throws {
        // Two projects, one token: the second project has no token at its position.
        Environment.env[CircleCi.JobTriggerRequest.Config.projects.rawValue] = "\(project)@4dmotion-android"
        let api = CircleCi.apiWithSlack(Service.mockContext)
        let job = CircleCiTestJob(project: .android4DM, branch: branch, options: [], username: username)
        let response = try await api(CircleCi.JobTriggerRequest(request: job)).get()
        XCTAssertEqual(response.left,
                       Slack.Response.error(CircleCi.Error.underlying(CircleCi.Error.noProject("4dmotion-android")),
                                            helpResponse: CircleCi.helpResponse))
    }

    func testResponseToSlack() {
        // test
        let testResponse = CircleCi.JobTriggerResponse(
            responseObject: CircleCi.JobTrigger.Response(number: 10, state: nil, createdAt: nil, message: "x"),
            request: CircleCiTestJob(
                project: .unknown(project),
                branch: branch,
                options: options,
                username: username
            )
        )
        let testSlackResponse = CircleCi.responseToSlack(testResponse)
        let expectedTestSlackResponse = Slack.Response(
            responseType: .inChannel,
            text: nil,
            attachments: [
                Slack.Response.Attachment(
                    fallback: "Job \'test\' has started at <https://app.circleci.com/pipelines/circleCiVcs/circleCiCompany/projectX/10|#10>. "
                        + "(project: unknown(\"projectX\"), branch: feature/branch-X)",
                    text: "Job \'test\' has started at <https://app.circleci.com/pipelines/circleCiVcs/circleCiCompany/projectX/10|#10>.",
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
        let deployResponse = CircleCi.JobTriggerResponse(
            responseObject: CircleCi.JobTrigger.Response(number: 10, state: nil, createdAt: nil, message: "x"),
            request: CircleCiDeployJob(
                project: .unknown(project),
                branch: branch,
                type: type,
                options: options,
                username: username
            )
        )
        let deploySlackResponse = CircleCi.responseToSlack(deployResponse)
        let expectedDeploySlackResponse = Slack.Response(
            responseType: .inChannel,
            text: nil,
            attachments: [
                Slack.Response.Attachment(
                    fallback: "Job \'deploy\' has started at <https://app.circleci.com/pipelines/circleCiVcs/circleCiCompany/projectX/10|#10>. "
                        + "(project: unknown(\"projectX\"), branch: feature/branch-X)",
                    text: "Job \'deploy\' has started at <https://app.circleci.com/pipelines/circleCiVcs/circleCiCompany/projectX/10|#10>.",
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

        let messageResponse = CircleCi.JobTriggerResponse(
            responseObject: CircleCi.JobTrigger.Response(number: nil, state: nil, createdAt: nil, message: "x"),
            request: CircleCiTestJob(
                project: .unknown(project),
                branch: branch,
                options: options,
                username: username
            )
        )
        let messageSlackResponse = CircleCi.responseToSlack(messageResponse)
        XCTAssertEqual(messageSlackResponse, Slack.Response.error(CircleCi.Error.badResponse("x")))
    }

    // MARK: Github
    func testGithubRequest() async throws {
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        
        // ci should run, if no status and waiting for review labeling
        let branchNoStatus = Github.Branch.template(
            ref: branch,
            repo: Github.Repository.template(
                url: "https://empty.com/repo/company/project"))
        let devNoStatusPullRequest = Github.PullRequest.template(
            id: 0,
            title: "test",
            body: "",
            head: branchNoStatus,
            base: Github.Branch.template(),
            url: ""
        )
        let labeledDevNoStatuRequest = Github.Payload(action: .labeled,
                                                      pullRequest: devNoStatusPullRequest,
                                                      label: Github.Label.waitingForReview,
                                                      installation: Github.Installation(id: 1),
                                                      repository: Github.Repository.template(name: project))
        let testDevNoStatusRequest = try await CircleCi.githubRequest(
            labeledDevNoStatuRequest,
            pullRequestHeaders,
            Service.mockContext).get()
        XCTAssertEqual(testDevNoStatusRequest.right?.request as? CircleCiTestJob,
                       CircleCiTestJob(project: .unknown(project),
                                       branch: branch,
                                       options: [],
                                       username: "cci"))
        
        // ci should run, if error is the last commit status and waiting for review labeling
        let branchErrorStatus = Github.Branch.template(
            ref: branch,
            repo: Github.Repository.template(
                url: "https://error.com/repo/company/project"))
        let devErrorStatusPullRequest = Github.PullRequest.template(
            id: 0,
            title: "test",
            body: "",
            head: branchErrorStatus,
            base: Github.Branch.template(),
            url: ""
        )
        let labeledDevErrorStatuRequest = Github.Payload(action: .labeled,
                                                         pullRequest: devErrorStatusPullRequest,
                                                         label: Github.Label.waitingForReview,
                                                         installation: Github.Installation(id: 1),
                                                         repository: Github.Repository.template(name: project))
        let testDevErrorStatusRequest = try await CircleCi.githubRequest(
            labeledDevErrorStatuRequest,
            pullRequestHeaders,
            Service.mockContext).get()
        XCTAssertEqual(testDevErrorStatusRequest.right?.request as? CircleCiTestJob,
                       CircleCiTestJob(project: .unknown(project),
                                       branch: branch,
                                       options: [],
                                       username: "cci"))
        
        // ci should not run, if success is the last commit status and waiting for review labeling
        let branchSuccessStatus = Github.Branch.template(
            ref: branch,
            repo: Github.Repository.template(
                url: "https://success.com/repo/company/project"))
        let devSuccessStatusPullRequest = Github.PullRequest.template(
            id: 0,
            title: "test",
            body: "",
            head: branchSuccessStatus,
            base: Github.Branch.template(),
            url: ""
        )
        let labeledDevSuccessStatuRequest = Github.Payload(action: .labeled,
                                                           pullRequest: devSuccessStatusPullRequest,
                                                           label: Github.Label.waitingForReview,
                                                           installation: Github.Installation(id: 1),
                                                           repository: Github.Repository.template(name: project))
        
        let testDevSuccessStatusRequest = try await CircleCi.githubRequest(
            labeledDevSuccessStatuRequest,
            pullRequestHeaders,
            Service.mockContext).get()
        XCTAssertEqual(testDevSuccessStatusRequest.left, Github.PayloadResponse())
        
        let masterPullRequest = Github.PullRequest.template(
            id: 0,
            title: "test",
            body: "",
            head: Github.Branch.template(ref: branch),
            base: Github.Branch.template(ref: "master"),
            url: ""
        )
        let labeledMasterRequest = Github.Payload(action: .labeled,
                                                  pullRequest: masterPullRequest,
                                                  label: Github.Label.waitingForReview,
                                                  repository: Github.Repository.template(name: project))
        
        let testMasterRequest = try await CircleCi.githubRequest(labeledMasterRequest, pullRequestHeaders, Service.mockContext).get()
        XCTAssertEqual(testMasterRequest.right?.request as? CircleCiTestJob,
                       CircleCiTestJob(project: .unknown(project),
                                       branch: branch,
                                       options: ["restrict_fixme_comments:true"],
                                       username: "cci"))
        
        let emptyRequest = Github.Payload()
        let testEmptyRequest = try await CircleCi.githubRequest(emptyRequest, nil, Service.mockContext).get()
        XCTAssertEqual(testEmptyRequest.left, Github.PayloadResponse())

    }
    
}
