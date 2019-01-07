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
                                             body: "",
                                             head: featureBranch,
                                             base: Github.devBranch)

        let branchRequest = Github.Payload(ref: title,
                                           refType: Github.RefType.branch)
        let branchType = branchRequest.type(headers: branchHeaders)
        XCTAssertEqual(branchType, .branchCreated(title: title))
        
        let openedRequest = Github.Payload(action: Github.Action.opened,
                                           pullRequest: pullRequest)
        let openedType = openedRequest.type(headers: pullRequestHeaders)
        XCTAssertEqual(openedType, .pullRequestOpened(title: title, url: "", body: ""))

        let editedRequest = Github.Payload(action: Github.Action.edited,
                                           pullRequest: pullRequest)
        let editedType = editedRequest.type(headers: pullRequestHeaders)
        XCTAssertEqual(editedType, .pullRequestEdited(title: title, url: "", body: ""))

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
        let iss = "0101"
        let iat: TimeInterval = 1
        let exp = (10 * 60) + iat
        
        Environment.env[Github.APIRequest.Config.githubAppId.rawValue] = iss
        Environment.env[Github.APIRequest.Config.githubPrivateKey.rawValue] = privateKeyString

        let token = try Github.jwt(date: Date(timeIntervalSince1970: iat))
        let data: Data = token.data(using: .utf8) ?? Data()
        let jwt = try JWT<Github.JWTPayloadData>(unverifiedFrom: data)

        XCTAssertEqual(jwt.payload.iss, iss)
        XCTAssertEqual(jwt.payload.iat, Int(iat))
        XCTAssertEqual(jwt.payload.exp, Int(exp))
        
    }
    
    func testAccessToken() throws {
        let token = "x"
        Environment.api = { hostname, _ in
            return { context, _ in
                return pure(HTTPResponse(body: "{\"token\":\"\(token)\"}"), context)
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
    
    func testGithubRequestChangesRequested() throws {
        let labelPath = "/issues/1/labels/waiting for review"
        let reviewer = Github.User(login: "y")
        let pullRequestHeaders = [Github.eventHeaderName: Github.Event.pullRequestReview.rawValue]
        let pullRequest = Github.PullRequest(url: "http://test.com/pulls/1",
                                             id: 1,
                                             title: "x",
                                             body: "",
                                             head: Github.devBranch,
                                             base: Github.masterBranch,
                                             requestedReviewers: [reviewer])
        
        let response = Github.githubRequest(Github.Payload(action: .submitted,
                                                           review: Github.Review(state: .changesRequested),
                                                           pullRequest: pullRequest,
                                                           installation: Github.Installation(id: 1)),
                                            pullRequestHeaders)
        
        XCTAssertEqual(response.right?.url?.host, "test.com")
        XCTAssertEqual(response.right?.url?.path, labelPath)
        XCTAssertEqual(response.right?.installationId, 1)
        XCTAssertEqual(response.right?.method, .DELETE)

    }
    
    func testFailedStatus() {
        let headers = [Github.eventHeaderName: Github.Event.status.rawValue]
        
        let response = Github.githubRequest(Github.Payload(installation: Github.Installation(id: 1),
                                                           commit: Github.Commit(sha: "shaxyz"),
                                                           state: .some(.error)),
                                            headers)
        
        let query = "shaxyz+label:\"\(Github.waitingForReviewLabel.name)\"+state:open"
        XCTAssertNil(response.left)
        XCTAssertEqual(response.right?.url?.host, "api.github.com")
        XCTAssertEqual(response.right?.url?.path, "/search/issues?q=\(query)")
        XCTAssertEqual(response.right?.installationId, 1)
        XCTAssertEqual(response.right?.method, .GET)
    }
    
    func testPullRequestOpened() throws {
        Environment.env[Youtrack.Request.Config.youtrackURL.rawValue] = "https://test.com"
        let title = "#4DM-2001 test"
        let body = "body"
        let headers = [Github.eventHeaderName: Github.Event.pullRequest.rawValue]
        let pullRequest = Github.PullRequest(url: "http://test.com/pulls/1",
                                             id: 1,
                                             title: title,
                                             body: "body",
                                             head: Github.devBranch,
                                             base: Github.masterBranch)

        let response = Github.githubRequest(Github.Payload(action: .opened,
                                                           pullRequest: pullRequest,
                                                           installation: Github.Installation(id: 1)),
                                            headers)
        XCTAssertNil(response.left)
        XCTAssertEqual(response.right?.url?.host, "test.com")
        XCTAssertEqual(response.right?.url?.path, "/pulls/1")
        XCTAssertEqual(response.right?.installationId, 1)
        XCTAssertEqual(response.right?.method, .PATCH)
        
        let new = "- " + (try Youtrack.issueURLs(from: title)[0]) + "\n\n\(body)"
        struct Body: Decodable, Equatable { let body: String }
        XCTAssertEqual(try JSONDecoder().decode(Body.self, from: response.right?.body ?? Data()),
                       Body(body: new))
    }

    func testApiChangesRequested() throws {
        let api = Github.apiWithGithub(context())

        Environment.env = [
            Github.APIRequest.Config.githubAppId.rawValue: Github.APIRequest.Config.githubAppId.rawValue,
            Github.APIRequest.Config.githubPrivateKey.rawValue: privateKeyString
        ]

        Environment.api = { hostname, _ in
            Environment.env[hostname] = hostname
            return { context, _ in
                if hostname == "api.github.com" {
                    return pure(HTTPResponse(body: "{\"token\": \"x\"}"), context)
                } else if hostname == "test.com" {
                    return pure(HTTPResponse(body: "{\"message\": \"y\"}"), context)
                } else {
                    XCTFail("Shouldn't be more api calls")
                    return Environment.emptyApi(context)
                }
            }
        }

        let request = Github.APIRequest(installationId: 1, type: .changesRequested(url: "http://test.com/pulls/1"))
        let response = try api(request).wait()
        XCTAssertEqual(response.right, Github.APIResponse(message: "y"))

        let wrongRequest = Github.APIRequest(installationId: 1, type: .changesRequested(url: "/pulls/1"))
        let wrongResponse = try api(wrongRequest).wait()
        XCTAssertEqual(wrongResponse.left,
                       Github.PayloadResponse(error: Github.Error.badUrl("/issues/1/labels/waiting%20for%20review")))
    }
    
    func testApiFailedStatus() throws {
        let api = Github.apiWithGithub(context())
        
        Environment.env = [
            Github.APIRequest.Config.githubAppId.rawValue: Github.APIRequest.Config.githubAppId.rawValue,
            Github.APIRequest.Config.githubPrivateKey.rawValue: privateKeyString
        ]
        
        Environment.api = { hostname, _ in
            return { context, request in
                Environment.env[hostname] = hostname
                if hostname == "api.github.com" {
                    if request.urlString.contains("/app/installations") {
                        return pure(HTTPResponse(body: "{\"token\": \"x\"}"), context)
                    } else if request.urlString.contains("/search/issues") {
                        let response = Github.SearchResponse(
                            items: [Github.SearchIssue(pullRequest: .init(url: "https://pr.com/1"))])
                        let data = try? JSONEncoder().encode(response)
                        return pure(HTTPResponse(body: data ?? Data()), context)
                    } else {
                        XCTFail("Shouldn't be more api calls")
                        return Environment.emptyApi(context)
                    }
                } else if hostname == "pr.com" {
                    let data = try? JSONEncoder().encode(Github.PullRequest(url: "https://test.com/pull/1",
                                                                            id: 1,
                                                                            title: "title",
                                                                            body: "",
                                                                            head: Github.devBranch,
                                                                            base: Github.masterBranch))
                    return pure(HTTPResponse(body: data ?? Data()), context)
                } else if hostname == "test.com" {
                    return pure(HTTPResponse(body: "{\"message\": \"y\"}"), context)
                } else {
                    XCTFail("Shouldn't be more api calls")
                    return Environment.emptyApi(context)
                }
            }
        }
        
        let request = Github.APIRequest(installationId: 1, type: .failedStatus(sha: "shaxyz"))
        let response = try api(request).wait()
        
        XCTAssertNil(response.left)
        XCTAssertEqual(response.right, Github.APIResponse(message: "y"))
        XCTAssertEqual(Environment.env["api.github.com"], "api.github.com")
        XCTAssertEqual(Environment.env["pr.com"], "pr.com")
        XCTAssertEqual(Environment.env["test.com"], "test.com")
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
