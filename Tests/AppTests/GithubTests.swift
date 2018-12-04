//
//  GithubTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 04..
//

import APIModels

import XCTest
import Crypto

@testable import App

class GithubWebhookTests: XCTestCase {
    
    func testVerify() throws {
        let signature = "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"
        XCTAssertTrue(GithubWebhookRequest.verify(payload: "y", secret: "x", signature: signature))
        XCTAssertFalse(GithubWebhookRequest.verify(payload: "x", secret: "x", signature: signature))
    }
}
