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
        let badURLRequest = SlackRequest.template(token: token, responseUrlString: "")
        XCTAssertEqual(SlackRequest.check(badURLRequest), SlackResponse.error(SlackError.missingResponseURL))
        
        let badTokenRequest = SlackRequest.template(token: "", responseUrlString: "https://test.com")
        XCTAssertEqual(SlackRequest.check(badTokenRequest), SlackResponse.error(SlackError.badToken))
        
        let badRequest = SlackRequest.template(token: "", responseUrlString: "")
        XCTAssertEqual(SlackRequest.check(badRequest),
                       SlackResponse.error(SlackError.combined([.badToken, .missingResponseURL])))

        let goodRequest = SlackRequest.template(token: token, responseUrlString: "https://test.com")
        XCTAssertNil(SlackRequest.check(goodRequest))
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
        
        let goodRequest = SlackRequest.template(responseUrlString: "https://test.com")
        let goodApi = SlackRequest.api(goodRequest, context())
        try goodApi(SlackResponse(responseType: .ephemeral, text: nil, attachments: [], mrkdwn: nil)).wait()
        XCTAssertTrue(usedApi)
        XCTAssertFalse(usedEmptyApi)
        
        usedApi = false
        let badRequest = SlackRequest.template(responseUrlString: "")
        let badApi = SlackRequest.api(badRequest, context())
        try badApi(SlackResponse(responseType: .ephemeral, text: nil, attachments: [], mrkdwn: nil)).wait()
        XCTAssertTrue(usedEmptyApi)
        XCTAssertFalse(usedApi)
    }
    
    func testInstant() throws {
        let instant = SlackRequest.instant(context())
        let response = try instant(SlackRequest.template()).wait()
        XCTAssertEqual(response, SlackResponse.instant)
    }
}
