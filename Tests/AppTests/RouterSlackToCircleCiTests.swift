//
//  RouterSlackToCircleCiTests
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 09. 10..
//

import APIConnect
import APIService
import APIModels
import Mocks

import XCTest
import Vapor
@testable import App

class RouterSlackToCircleCiTests: XCTestCase {
    
    private class MockAPI: BackendAPIType {
        
        func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
            Environment.env[request.host] = request.host
            
            switch request.host {
            case "slack.com":
                return pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
            case "circleci.com":
                return pure(MockHTTPResponse.okResponse(body: "{\"build_url\":\"buildURL\",\"build_num\":10}"), Service.mockContext)
            default:
                XCTFail("Shouldn't have an api for anything else: \(request.host)")
                return pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
            }
        }
    }
    
    override func setUp() async throws {
        try await super.setUp()
        
        Environment.env = [
            Slack.Request.Config.slackToken.rawValue: Slack.Request.Config.slackToken.rawValue,
            CircleCi.JobTriggerRequest.Config.tokens.rawValue: CircleCi.JobTriggerRequest.Config.tokens.rawValue,
            CircleCi.JobTriggerRequest.Config.company.rawValue: CircleCi.JobTriggerRequest.Config.company.rawValue,
            CircleCi.JobTriggerRequest.Config.vcs.rawValue: CircleCi.JobTriggerRequest.Config.vcs.rawValue,
            CircleCi.JobTriggerRequest.Config.projects.rawValue: "projectX"
        ]
        
        try await Service.loadTest(MockAPI())
    }
    
    func testCheckConfigsFail() {
        Environment.env = [:]
        do {
            try SlackToCircleCi.checkConfigs()
        } catch {
            if case let SlackToCircleCi.APIConnectError.combined(errors) = error {
                XCTAssertEqual(errors.count, 2, "We haven't found all the errors (no conflict)")
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
    
    func testFullRun() async throws {
        let text = "\(CircleCiJobKind.test.rawValue) feature/branch-X \(["options1:x", "options2:y"].joined(separator: " "))"
        let request = Slack.Request(
            token: "slackToken",
            teamId: "",
            teamDomain: "",
            enterpriseId: "",
            enterpriseName: nil,
            channelId: "",
            channelName: "projectX",
            userId: "",
            userName: "tester",
            command: "x",
            text: text,
            responseUrlString: "https://slack.com",
            triggerId: ""
        )
        
        let response = try await SlackToCircleCi.run(request, Service.mockContext).get()
        XCTAssertEqual(Environment.env["slack.com"], "slack.com")
        XCTAssertEqual(Environment.env["circleci.com"], "circleci.com")
        XCTAssertEqual(response, Slack.Response.instant)
    }
}
