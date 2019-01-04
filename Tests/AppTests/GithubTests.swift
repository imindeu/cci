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
import JWT
import HTTP

@testable import App

class GithubTests: XCTestCase {
    
    func testVerify() throws {
        let signature = "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"
        XCTAssertTrue(Github.verify(body: "y", secret: "x", signature: signature))
        XCTAssertFalse(Github.verify(body: "x", secret: "x", signature: signature))
    }
    
    func testCheck() {
        Environment.env[Github.Payload.Config.githubSecret.rawValue] = "x"
        let headers = [Github.signatureHeaderName: "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        let response = Github.check(Github.Payload(),
                                    "y",
                                    headers)
        XCTAssertNil(response)
    }
    
    func testCheckFailure() {
        Environment.env[Github.Payload.Config.githubSecret.rawValue] = "y"
        let headers = [Github.signatureHeaderName: "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        let response = Github.check(Github.Payload(),
                                    "y",
                                    headers)
        XCTAssertEqual(response, Github.PayloadResponse(error: Github.Error.signature))
    }
    
    func testType() {
        let title = "test 4DM-2001, 4DM-2002"
        let branchHeaders = [Github.eventHeaderName: "create"]
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        let featureBranch = Github.Branch(ref: "feature")
        let pullRequest = Github.PullRequest(url: "",
                                             id: 0,
                                             title: title,
                                             head: featureBranch,
                                             base: Github.devBranch)

        let branchRequest = Github.Payload(ref: title,
                                           refType: Github.RefType.branch)
        let branchType = branchRequest.type(headers: branchHeaders)
        XCTAssertEqual(branchType, .branchCreated(title: title))
        
        let openedRequest = Github.Payload(action: Github.Action.opened,
                                           pullRequest: pullRequest)
        let openedType = openedRequest.type(headers: pullRequestHeaders)
        XCTAssertEqual(openedType, .pullRequestOpened(title: title))
        
        let closedRequest = Github.Payload(action: Github.Action.closed,
                                           pullRequest: pullRequest)
        let closedType = closedRequest.type(headers: pullRequestHeaders)
        XCTAssertEqual(closedType, .pullRequestClosed(title: title))
        
        let labeledRequest = Github.Payload(action: .labeled,
                                            pullRequest: pullRequest,
                                            label: Github.waitingForReviewLabel)
        let labeledType = labeledRequest.type(headers: pullRequestHeaders)
        XCTAssertEqual(labeledType, .pullRequestLabeled(label: Github.waitingForReviewLabel,
                                                        head: featureBranch,
                                                        base: Github.devBranch))

        let wrongRequest = Github.Payload()
        XCTAssertNil(wrongRequest.type(headers: branchHeaders) ?? wrongRequest.type(headers: pullRequestHeaders))
        
        // empty header
        XCTAssertNil(branchRequest.type(headers: nil)
            ?? openedRequest.type(headers: nil)
            ?? closedRequest.type(headers: nil))
        
        // wrong header
        XCTAssertNil(branchRequest.type(headers: pullRequestHeaders) ?? openedRequest.type(headers: branchHeaders))
        
    }

    func testJwt() throws {
        Environment.env[Github.APIRequest.Config.githubAppId.rawValue] = "0101"
        Environment.env[Github.APIRequest.Config.githubPrivateKey.rawValue] = privateKeyString

        // swiftlint:disable line_length
        #if os(Linux)
        // on linux the payload data orders are different
        let token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpYXQiOjEsImlzcyI6IjAxMDEiLCJleHAiOjYwMX0.mkExPTvAJYU09vDb6XuU6i659gzFfNczBeTJadMN-ObvoceOAJEugTU7CwM5dkGFQks1IWz6BcR7Xo-nMjBBCJkB7JKNQVOGQRthANhyWdKJueGVwuofJ0dE3g87q7-QWjuapx02xPfjbGCGw9G6P9CxMZye0HmRFHwuBxRcy1E"
        #else
        let token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjEsImV4cCI6NjAxLCJpc3MiOiIwMTAxIn0.F6RslER_TFawnvvPijRhKj0EmP-0fkNsfmPmLSmwk0A1FRXcIg4nIRkmAWlHZD9WQS3_wFYJP3OflmDCZ4xUHNru3Y4JvjsouHaSCrkpgak3RArLW4NXjD1n_Oh9eVvARMSN6bJTIQMey2emYcl08091kdn5mV-67EsvoTgvOU8"
        #endif
        // swiftlint:enable line_length
        XCTAssertEqual(try Github.jwt(date: Date(timeIntervalSince1970: 1)), token)
    }
    
    func testAccessToken() throws {
        let token = "x"
        Environment.api = { hostname, _ in
            return { context, _ in
                let response = HTTPResponse(
                    status: .ok,
                    version: HTTPVersion(major: 1, minor: 1),
                    headers: HTTPHeaders([]),
                    body: "{\"token\":\"\(token)\"}")
                return pure(response, context)
            }
        }
        XCTAssertEqual(try Github.accessToken(context: context(), jwtToken: "a", installationId: 1)().wait(), token)
    }
    
    func testReviewText() {
        let multi = [Github.User(login: "x"), Github.User(login: "y")]
        XCTAssertEqual(Github.reviewText(multi), "@x, @y please review this pr")
        let single = [Github.User(login: "z")]
        XCTAssertEqual(Github.reviewText(single), "@z please review this pr")
    }
    
//    func testGithubRequestLabeled() throws {
//        let commentLink = "http://test.com/comment/link"
//        let reviewer = Github.User(login: "y")
//        let pullRequestHeaders = [Github.eventHeaderName: Github.Event.pullRequest.rawValue]
//        let pullRequest = Github.PullRequest(id: 1,
//                                             title: "x",
//                                             head: Github.devBranch,
//                                             base: Github.masterBranch,
//                                             requestedReviewers: [reviewer],
//                                             links: Github.Links(comments: Github.Link(href: commentLink)))
//        
//        let response = Github.githubRequest(Github.Payload(action: .labeled,
//                                                           pullRequest: pullRequest,
//                                                           label: Github.waitingForReviewLabel,
//                                                           installation: Github.Installation(id: 1)),
//                                            pullRequestHeaders)
//        
//        let expectedBody =
//            try JSONEncoder().encode(Github.IssueComment(body: Github.reviewText([reviewer])))
//        
//        XCTAssertEqual(response.right?.url, URL(string: commentLink))
//        XCTAssertEqual(response.right?.installationId, 1)
//        XCTAssertEqual(response.right?.body, expectedBody)
//        XCTAssertEqual(response.right?.method, .POST)
//        
//    }
//
//    func testGithubRequestLabeledEmptyReviewer() {
//        let commentLink = "http://test.com/comment/link"
//        let pullRequestHeaders = [Github.eventHeaderName: Github.Event.pullRequest.rawValue]
//        let pullRequest = Github.PullRequest(id: 1,
//                                             title: "x",
//                                             head: Github.devBranch,
//                                             base: Github.masterBranch,
//                                             requestedReviewers: [],
//                                             links: Github.Links(comments: Github.Link(href: commentLink)))
//        
//        let response = Github.githubRequest(Github.Payload(action: .labeled,
//                                                           pullRequest: pullRequest,
//                                                           label: Github.waitingForReviewLabel,
//                                                           installation: Github.Installation(id: 1)),
//                                            pullRequestHeaders)
//        
//        XCTAssertEqual(response.left, Github.PayloadResponse())
//        
//    }
    
    func testGithubRequestChangesRequested() throws {
        let labelPath = "/pulls/labels/waiting for review"
        let reviewer = Github.User(login: "y")
        let pullRequestHeaders = [Github.eventHeaderName: Github.Event.pullRequestReview.rawValue]
        let pullRequest = Github.PullRequest(url: "http://test.com/pulls",
                                             id: 1,
                                             title: "x",
                                             head: Github.devBranch,
                                             base: Github.masterBranch,
                                             requestedReviewers: [reviewer])
        
        let response = Github.githubRequest(Github.Payload(action: .submitted,
                                                           review: Github.Review(state: .changesRequested),
                                                           pullRequest: pullRequest,
                                                           installation: Github.Installation(id: 1)),
                                            pullRequestHeaders)
        
        XCTAssertEqual(response.right?.type.url?.host, "test.com")
        XCTAssertEqual(response.right?.type.url?.path, labelPath)
        XCTAssertEqual(response.right?.installationId, 1)
        XCTAssertEqual(response.right?.type.method, .DELETE)

    }

    func testApiWithGithub() throws {
        let api = Github.apiWithGithub(context())

        Environment.env = [
            Github.APIRequest.Config.githubAppId.rawValue: Github.APIRequest.Config.githubAppId.rawValue,
            Github.APIRequest.Config.githubPrivateKey.rawValue: privateKeyString
        ]

        Environment.api = { hostname, _ in
            return { context, _ in
                if hostname == "api.github.com" {
                    let response = HTTPResponse(
                        status: .ok,
                        version: HTTPVersion(major: 1, minor: 1),
                        headers: HTTPHeaders([]),
                        body: "{\"token\": \"x\"}")
                    return pure(response, context)
                } else if hostname == "test.com" {
                    let response = HTTPResponse(
                        status: .ok,
                        version: HTTPVersion(major: 1, minor: 1),
                        headers: HTTPHeaders([]),
                        body: "{\"message\": \"y\"}")
                    return pure(response, context)
                } else {
                    XCTFail("Shouldn't be more api calls")
                    return Environment.emptyApi(context)
                }
            }
        }

        let request = Github.APIRequest(installationId: 1, type: .changesRequested(url: "http://test.com/pulls"))
        let response = try api(request).wait()
        XCTAssertEqual(response.right, Github.APIResponse(message: "y"))

        let wrongRequest = Github.APIRequest(installationId: 1, type: .changesRequested(url: "/pulls"))
        let wrongResponse = try api(wrongRequest).wait()
        XCTAssertEqual(wrongResponse.left,
                       Github.PayloadResponse(error: Github.Error.badUrl("/pulls/labels/waiting%20for%20review")))
    }
    
    func testResponseToGithub() {
        XCTAssertEqual(Github.responseToGithub(Github.APIResponse()), Github.PayloadResponse())
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
