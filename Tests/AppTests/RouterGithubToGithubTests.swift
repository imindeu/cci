//
//  RouterGithubToGithubTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 19..
//
import APIConnect
import APIModels

import XCTest
import HTTP

@testable import App

class RouterGithubToGithubTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Environment.env = [
            Github.Payload.Config.githubSecret.rawValue: "x",
            Github.APIRequest.Config.githubAppId.rawValue: "0101",
            Github.APIRequest.Config.githubPrivateKey.rawValue: privateKeyString
        ]
        Environment.api = { hostname, _ in
            return { context, request in
                Environment.env[hostname] = hostname
                if hostname == "test.com" {
                    let command = request.url.query ?? ""
                    return pure(HTTPResponse(body: "{\"value\": \"\(command)\"}"), context)
                } else if hostname == "api.github.com" {
                    return pure(HTTPResponse(body: "{\"token\":\"x\"}"), context)
                } else {
                    XCTFail("Shouldn't have an api for anything else")
                    return Environment.emptyApi(context)
                }
            }
        }
    }
    
    func testCheckConfigsFail() {
        Environment.env = [:]
        do {
            try GithubToGithub.checkConfigs()
        } catch {
            if case let GithubToGithub.APIConnectError.combined(errors) = error {
                XCTAssertEqual(errors.count, 2,
                               "We haven't found all the errors (no conflict)")
            } else {
                XCTFail("Wrong error \(error)")
            }
        }
    }
    
    func testCheckConfigs() {
        do {
            try GithubToGithub.checkConfigs()
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testFullRun() throws {
        let pullRequest = Github.PullRequest(url: "http://test.com/pull",
                                             id: 1,
                                             title: "x",
                                             body: "",
                                             head: Github.devBranch,
                                             base: Github.masterBranch)
        let request = Github.Payload(action: .submitted,
                                     review: Github.Review(state: .changesRequested),
                                     pullRequest: pullRequest,
                                     label: Github.waitingForReviewLabel,
                                     installation: Github.Installation(id: 1))
        let response = try GithubToGithub.run(request,
                                              context(),
                                              "y",
                                              [Github.eventHeaderName: Github.Event.pullRequestReview.rawValue,
                                               Github.signatureHeaderName:
                                                "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"])
            .wait()
        XCTAssertEqual(Environment.env["api.github.com"], "api.github.com")
        XCTAssertEqual(Environment.env["test.com"], "test.com")
        XCTAssertEqual(response, Github.PayloadResponse())
    }

    func testEmptyRun() throws {
        let pullRequest = Github.PullRequest(url: "http://test.com/pull",
                                             id: 1,
                                             title: "x",
                                             body: "",
                                             head: Github.devBranch,
                                             base: Github.masterBranch)
        let request = Github.Payload(action: .labeled,
                                     pullRequest: pullRequest,
                                     label: Github.waitingForReviewLabel,
                                     installation: Github.Installation(id: 1))
        let response = try GithubToYoutrack.run(request,
                                                context(),
                                                "y",
                                                [Github.eventHeaderName: Github.Event.pullRequest.rawValue,
                                                 Github.signatureHeaderName:
                                                    "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"])
            .wait()
        XCTAssertNil(Environment.env["test.com"])
        XCTAssertEqual(response, Github.PayloadResponse())
    }

}

// swiftlint:disable prefixed_toplevel_constant
let privateKeyString = """
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQC0cOtPjzABybjzm3fCg1aCYwnxPmjXpbCkecAWLj/CcDWEcuTZ
kYDiSG0zgglbbbhcV0vJQDWSv60tnlA3cjSYutAv7FPo5Cq8FkvrdDzeacwRSxYu
Iq1LtYnd6I30qNaNthntjvbqyMmBulJ1mzLI+Xg/aX4rbSL49Z3dAQn8vQIDAQAB
AoGBAJeBFGLJ1EI8ENoiWIzu4A08gRWZFEi06zs+quU00f49XwIlwjdX74KP03jj
H14wIxMNjSmeixz7aboa6jmT38pQIfE3DmZoZAbKPG89SdP/S1qprQ71LgBGOuNi
LoYTZ96ZFPcHbLZVCJLPWWWX5yEqy4MS996E9gMAjSt8yNvhAkEA38MufqgrAJ0H
VSgL7ecpEhWG3PHryBfg6fK13RRpRM3jETo9wAfuPiEodnD6Qcab52H2lzMIysv1
Ex6nGv2pCQJBAM5v9SMbMG20gBzmeZvjbvxkZV2Tg9x5mWQpHkeGz8GNyoDBclAc
BFEWGKVGYV6jl+3F4nqQ6YwKBToE5KIU5xUCQEY9Im8norgCkrasZ3I6Sa4fi8H3
PqgEttk5EtVe/txWNJzHx3JsCuD9z5G+TRAwo+ex3JIBtxTRiRCDYrkaPuECQA2W
vRI0hfmSuiQs37BtRi8DBNEmFrX6oyg+tKmMrDxXcw8KrNWtInOb+r9WZK5wIl4a
epAK3fTD7Bgnnk01BwkCQHQwEdGNGN3ntYfuRzPA4KiLrt8bpACaHHr2wn9N3fRI
bxEd3Ax0uhHVqKRWNioL7UBvd4lxoReY8RmmfghZHEA=
-----END RSA PRIVATE KEY-----
"""

// public key for later testing
let publicKeyString = """
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC0cOtPjzABybjzm3fCg1aCYwnx
PmjXpbCkecAWLj/CcDWEcuTZkYDiSG0zgglbbbhcV0vJQDWSv60tnlA3cjSYutAv
7FPo5Cq8FkvrdDzeacwRSxYuIq1LtYnd6I30qNaNthntjvbqyMmBulJ1mzLI+Xg/
aX4rbSL49Z3dAQn8vQIDAQAB
-----END PUBLIC KEY-----
"""

// swiftlint:enable prefixed_toplevel_constant
