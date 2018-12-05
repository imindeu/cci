//
//  GithubTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 04..
//

import APIConnect
import APIModels

import XCTest
import Crypto

@testable import App

extension Dictionary: Headers where Key == String, Value == String {
    public func get(_ name: String) -> String? { return self[name] }
}

class GithubWebhookTests: XCTestCase {
    
    func testVerify() throws {
        let signature = "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"
        XCTAssertTrue(GithubWebhookRequest.verify(payload: "y", secret: "x", signature: signature))
        XCTAssertFalse(GithubWebhookRequest.verify(payload: "x", secret: "x", signature: signature))
    }
    
    func testCheck() {
        Environment.env[GithubWebhookRequest.Config.githubSecret.rawValue] = "x"
        let headers = ["HTTP_X_HUB_SIGNATURE": "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        let response = GithubWebhookRequest.check(GithubWebhookRequest(action: nil,
                                                                       pullRequest: nil,
                                                                       ref: nil,
                                                                       refType: nil),
                                                  "y",
                                                  headers)
        XCTAssertNil(response)
    }
    
    func testCheckFailure() {
        Environment.env[GithubWebhookRequest.Config.githubSecret.rawValue] = "y"
        let headers = ["HTTP_X_HUB_SIGNATURE": "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        let response = GithubWebhookRequest.check(GithubWebhookRequest(action: nil,
                                                                       pullRequest: nil,
                                                                       ref: nil,
                                                                       refType: nil),
                                                  "y",
                                                  headers)
        XCTAssertEqual(response, GithubWebhookResponse(failure: "bad signature"))
    }
}
