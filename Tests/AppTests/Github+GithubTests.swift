//
//  Github+GithubTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 04..
//

import APIConnect
import APIModels

import XCTest
import Crypto
import HTTP

@testable import App

class Github_GithubTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Environment.env = [:]
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
        
        let new = "- " + (try Youtrack.issueURLs(from: title, url: "https://test.com")[0]) + "\n\n\(body)"
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

//        let wrongRequest = Github.APIRequest(installationId: 1, type: .changesRequested(url: "/pulls/1"))
//        let wrongResponse = try api(wrongRequest).wait()
//        XCTAssertEqual(wrongResponse.left,
//                       Github.PayloadResponse(error: Github.Error.badUrl("/issues/1/labels/waiting%20for%20review")))
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
