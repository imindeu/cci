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

class GithubTests: XCTestCase {
    
    func testVerify() throws {
        let signature = "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"
        XCTAssertTrue(Github.verify(payload: "y", secret: "x", signature: signature))
        XCTAssertFalse(Github.verify(payload: "x", secret: "x", signature: signature))
    }
    
    func testCheck() {
        Environment.env[Github.Payload.Config.githubSecret.rawValue] = "x"
        let headers = [Github.signatureHeaderName: "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        let response = Github.check(Github.Payload(action: nil,
                                                   pullRequest: nil,
                                                   ref: nil,
                                                   refType: nil),
                                    "y",
                                    headers)
        XCTAssertNil(response)
    }
    
    func testCheckFailure() {
        Environment.env[Github.Payload.Config.githubSecret.rawValue] = "y"
        let headers = ["HTTP_X_HUB_SIGNATURE": "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        let response = Github.check(Github.Payload(action: nil,
                                                   pullRequest: nil,
                                                   ref: nil,
                                                   refType: nil),
                                    "y",
                                    headers)
        XCTAssertEqual(response, Github.PayloadResponse(error: Github.Error.signature))
    }
    
    func testType() {
        let title = "test 4DM-2001, 4DM-2002"
        let branchHeaders = [Github.eventHeaderName: "create"]
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        
        let branchRequest = Github.Payload(action: nil,
                                           pullRequest: nil,
                                           ref: title,
                                           refType: Github.RefType.branch)
        let branchType = branchRequest.type(headers: branchHeaders)
        XCTAssertNotNil(branchType)
        XCTAssertEqual(branchType?.0, .branchCreated)
        XCTAssertEqual(branchType?.1, title)
        
        let openedRequest = Github.Payload(action: Github.Action.opened,
                                           pullRequest: Github.PullRequest(title: title),
                                           ref: nil,
                                           refType: nil)
        let openedType = openedRequest.type(headers: pullRequestHeaders)
        XCTAssertNotNil(openedType)
        XCTAssertEqual(openedType?.0, .pullRequestOpened)
        XCTAssertEqual(openedType?.1, title)
        
        let closedRequest = Github.Payload(action: Github.Action.closed,
                                           pullRequest: Github.PullRequest(title: title),
                                           ref: nil,
                                           refType: nil)
        let closedType = closedRequest.type(headers: pullRequestHeaders)
        XCTAssertNotNil(closedType)
        XCTAssertEqual(closedType?.0, .pullRequestClosed)
        XCTAssertEqual(closedType?.1, title)
        
        let wrongRequest = Github.Payload(action: nil,
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
