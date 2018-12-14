//
//  SlackTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

import APIConnect
import APIModels

import XCTest
import HTTP

@testable import App

class SlackTests: XCTestCase {

    func testCheck() {
        let token = "slackToken"
        Environment.env = [token: token]
        let badURLRequest = Slack.Request.template(token: token, responseUrlString: "")
        XCTAssertEqual(Slack.Request.check(badURLRequest), Slack.Response.error(Slack.Error.missingResponseURL))
        
        let badTokenRequest = Slack.Request.template(token: "", responseUrlString: "https://test.com")
        XCTAssertEqual(Slack.Request.check(badTokenRequest), Slack.Response.error(Slack.Error.badToken))
        
        let badRequest = Slack.Request.template(token: "", responseUrlString: "")
        XCTAssertEqual(Slack.Request.check(badRequest),
                       Slack.Response.error(Slack.Error.combined([.badToken, .missingResponseURL])))

        let goodRequest = Slack.Request.template(token: token, responseUrlString: "https://test.com")
        XCTAssertNil(Slack.Request.check(goodRequest))
    }
    
    func testApi() throws {
        var usedEmptyApi = false
        Environment.emptyApi = {
            usedEmptyApi = true
            return pure(HTTPResponse(), $0)
        }
        var usedApi = false
        Environment.api = { _, _ in
            return { context, _ in
                usedApi = true
                return pure(HTTPResponse(), context)
            }
        }
        
        let goodRequest = Slack.Request.template(responseUrlString: "https://test.com")
        let goodApi = Slack.Request.api(goodRequest, context())
        try goodApi(Slack.Response(responseType: .ephemeral, text: nil, attachments: [], mrkdwn: nil)).wait()
        XCTAssertTrue(usedApi)
        XCTAssertFalse(usedEmptyApi)
        
        usedApi = false
        let badRequest = Slack.Request.template(responseUrlString: "")
        let badApi = Slack.Request.api(badRequest, context())
        try badApi(Slack.Response(responseType: .ephemeral, text: nil, attachments: [], mrkdwn: nil)).wait()
        XCTAssertTrue(usedEmptyApi)
        XCTAssertFalse(usedApi)
    }
    
    func testInstant() throws {
        let instant = Slack.Request.instant(context())
        let response = try instant(Slack.Request.template()).wait()
        XCTAssertEqual(response, Slack.Response.instant)
    }
}
