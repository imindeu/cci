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
        let pullRequest = Github.PullRequest(id: 0,
                                             title: title,
                                             head: featureBranch,
                                             base: Github.devBranch,
                                             links: Github.Links(comments: Github.Link(href: "")))

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

    // Commented out because fails on linux
//    func testJwt() throws {
//        Environment.env[Github.APIRequest.Config.githubAppId.rawValue] = "0101"
//        Environment.env[Github.APIRequest.Config.githubPrivateKey.rawValue] = privateKeyString
//
//        // swiftlint:disable line_length
//        let token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjEsImV4cCI6NjAxLCJpc3MiOiIwMTAxIn0.F6RslER_TFawnvvPijRhKj0EmP-0fkNsfmPmLSmwk0A1FRXcIg4nIRkmAWlHZD9WQS3_wFYJP3OflmDCZ4xUHNru3Y4JvjsouHaSCrkpgak3RArLW4NXjD1n_Oh9eVvARMSN6bJTIQMey2emYcl08091kdn5mV-67EsvoTgvOU8"
//        // swiftlint:enable line_length
//        XCTAssertEqual(try Github.jwt(date: Date(timeIntervalSince1970: 1)), token)
//    }
    
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
        XCTAssertEqual(try Github.accessToken(context: context(), jwtToken: "a", installationId: 1).wait(), token)
    }
    
    func testReviewText() {
        let multi = [Github.User(login: "x"), Github.User(login: "y")]
        XCTAssertEqual(Github.reviewText(multi), "@x, @y please review this pr")
        let single = [Github.User(login: "z")]
        XCTAssertEqual(Github.reviewText(single), "@z please review this pr")
    }
    
    func testGithubRequest() throws {
        let commentLink = "http://test.com/comment/link"
        let reviewer = Github.User(login: "y")
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        let pullRequest = Github.PullRequest(id: 1,
                                             title: "x",
                                             head: Github.devBranch,
                                             base: Github.masterBranch,
                                             requestedReviewers: [reviewer],
                                             links: Github.Links(comments: Github.Link(href: commentLink)))
        
        let response = Github.githubRequest(Github.Payload(action: .labeled,
                                                           pullRequest: pullRequest,
                                                           label: Github.waitingForReviewLabel,
                                                           installation: Github.Installation(id: 1)),
                                            pullRequestHeaders)
        
        let expectedBody =
            try JSONEncoder().encode(Github.IssueComment(body: Github.reviewText([reviewer])))
        
        XCTAssertNotNil(response.right)
        XCTAssertEqual(response.right?.url, URL(string: commentLink))
        XCTAssertEqual(response.right?.installationId, 1)
        XCTAssertEqual(response.right?.body, expectedBody)
        
    }

    func testGithubRequestEmptyReviewer() throws {
        let commentLink = "http://test.com/comment/link"
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        let pullRequest = Github.PullRequest(id: 1,
                                             title: "x",
                                             head: Github.devBranch,
                                             base: Github.masterBranch,
                                             requestedReviewers: [],
                                             links: Github.Links(comments: Github.Link(href: commentLink)))
        
        let response = Github.githubRequest(Github.Payload(action: .labeled,
                                                           pullRequest: pullRequest,
                                                           label: Github.waitingForReviewLabel,
                                                           installation: Github.Installation(id: 1)),
                                            pullRequestHeaders)
        
        XCTAssertNotNil(response.left)
        XCTAssertEqual(response.left, Github.PayloadResponse())
        
    }

    func testApiWithGithub() throws {
        let payloadResponse: Either<Github.PayloadResponse, Github.APIRequest> = .left(Github.PayloadResponse())
        let api = Github.apiWithGithub(context())
        
        XCTAssertEqual(try api(payloadResponse).wait().left, payloadResponse.left)

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

        let body = try JSONEncoder().encode(Github.IssueComment(body: Github.reviewText([Github.User(login: "x")])))
        let request = Github.APIRequest(installationId: 1,
                                        url: URL(string: "http://test.com/comment/link")!,
                                        body: body)
        let response = try Github.apiWithGithub(context())(.right(request)).wait()
        XCTAssertEqual(response.right, Github.APIResponse(message: "y"))
        
        let wrongRequest = Github.APIRequest(installationId: 1,
                                             url: URL(string: "/comment/link")!,
                                             body: body)
        let wrongResponse = try Github.apiWithGithub(context())(.right(wrongRequest)).wait()
        XCTAssertEqual(wrongResponse.left, Github.PayloadResponse(error: Github.Error.badUrl("/comment/link")))
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
