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

class GithubWebhookTests: XCTestCase {
    
    func testVerify() throws {
        let signature = "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"
        XCTAssertTrue(GithubWebhook.verify(payload: "y", secret: "x", signature: signature))
        XCTAssertFalse(GithubWebhook.verify(payload: "x", secret: "x", signature: signature))
    }
    
    func testCheck() {
        Environment.env[GithubWebhook.Request.Config.githubSecret.rawValue] = "x"
        let headers = [GithubWebhook.signatureHeaderName: "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        let response = GithubWebhook.check(GithubWebhook.Request(action: nil,
                                                                 pullRequest: nil,
                                                                 ref: nil,
                                                                 refType: nil),
                                           "y",
                                           headers)
        XCTAssertNil(response)
    }
    
    func testCheckFailure() {
        Environment.env[GithubWebhook.Request.Config.githubSecret.rawValue] = "y"
        let headers = ["HTTP_X_HUB_SIGNATURE": "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        let response = GithubWebhook.check(GithubWebhook.Request(action: nil,
                                                                 pullRequest: nil,
                                                                 ref: nil,
                                                                 refType: nil),
                                           "y",
                                           headers)
        XCTAssertEqual(response, GithubWebhook.Response(error: GithubWebhook.Error.signature))
    }
    
    func testType() {
        let title = "test 4DM-2001, 4DM-2002"
        let branchHeaders = [GithubWebhook.eventHeaderName: "create"]
        let pullRequestHeaders = [GithubWebhook.eventHeaderName: "pull_request"]
        
        let branchRequest = GithubWebhook.Request(action: nil,
                                                  pullRequest: nil,
                                                  ref: title,
                                                  refType: GithubWebhook.RefType.branch)
        let branchType = branchRequest.type(headers: branchHeaders)
        XCTAssertNotNil(branchType)
        XCTAssertEqual(branchType?.0, .branchCreated)
        XCTAssertEqual(branchType?.1, title)
        
        let openedRequest = GithubWebhook.Request(action: GithubWebhook.Action.opened,
                                                  pullRequest: GithubWebhook.PullRequest(title: title),
                                                  ref: nil,
                                                  refType: nil)
        let openedType = openedRequest.type(headers: pullRequestHeaders)
        XCTAssertNotNil(openedType)
        XCTAssertEqual(openedType?.0, .pullRequestOpened)
        XCTAssertEqual(openedType?.1, title)
        
        let closedRequest = GithubWebhook.Request(action: GithubWebhook.Action.closed,
                                                  pullRequest: GithubWebhook.PullRequest(title: title),
                                                  ref: nil,
                                                  refType: nil)
        let closedType = closedRequest.type(headers: pullRequestHeaders)
        XCTAssertNotNil(closedType)
        XCTAssertEqual(closedType?.0, .pullRequestClosed)
        XCTAssertEqual(closedType?.1, title)
        
        let wrongRequest = GithubWebhook.Request(action: nil,
                                                 pullRequest: nil,
                                                 ref: nil,
                                                 refType: nil)
        XCTAssertNil(wrongRequest.type(headers: branchHeaders) ?? wrongRequest.type(headers: pullRequestHeaders))
        
        // empty header
        XCTAssertNil(branchRequest.type(headers: nil)
            ?? openedRequest.type(headers: nil)
            ?? closedRequest.type(headers: nil))
        
        // wrong header
        XCTAssertNil(branchRequest.type(headers: pullRequestHeaders) ?? openedRequest.type(headers: branchHeaders))
        
    }
}
