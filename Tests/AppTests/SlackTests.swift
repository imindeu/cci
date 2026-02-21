//
//  SlackTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

import APIConnect
import APIModels
import APIService
import Mocks

import XCTest
import Vapor

@testable import App

class SlackTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Environment.env = [:]
    }

    func testCheck() {
        let token = "slackToken"
        Environment.env = [token: token]
        let badURLRequest = Slack.Request.template(token: token, responseUrlString: "")
        XCTAssertEqual(Slack.check(badURLRequest), Slack.Response.error(Slack.Error.missingResponseURL))
        
        let badTokenRequest = Slack.Request.template(token: "", responseUrlString: "https://test.com")
        XCTAssertEqual(Slack.check(badTokenRequest), Slack.Response.error(Slack.Error.badToken))
        
        let badRequest = Slack.Request.template(token: "", responseUrlString: "")
        XCTAssertEqual(Slack.check(badRequest),
                       Slack.Response.error(Slack.Error.combined([.badToken, .missingResponseURL])))

        let goodRequest = Slack.Request.template(token: token, responseUrlString: "https://test.com")
        XCTAssertNil(Slack.check(goodRequest))
    }
    
    func testApi() async throws {
        class MockAPI: BackendAPIType {
            
            func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
                pure(MockHTTPResponse.okResponse(body: "{}"), Service.mockContext)
            }
        }
        try await Service.loadTest(MockAPI())
        
        let request = Slack.Request.template(responseUrlString: "https://test.com")
        let api = Slack.api(request, Service.mockContext)
        
        try await api(Slack.Response(responseType: .ephemeral, text: nil, attachments: [], mrkdwn: nil)).get()
    }
    
    func testInstant() throws {
        let instant = Slack.instant(Service.mockContext)
        let response = try instant(Slack.Request.template()).wait()
        XCTAssertEqual(response, Slack.Response.instant)
    }
}
