//
//  Github+GithubTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 04..
//

import APIConnect
import APIModels
import APIService
import Mocks

import XCTest
import Vapor

@testable import App

class GithubGithubTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Environment.env = [:]
    }
    
    func testCheck() {
        Environment.env[Github.Payload.Config.githubSecret.rawValue] = "x"
        let headers = [Github.signatureHeaderName: "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"]
        let response = Github.check(Github.Payload(), "y", headers)
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
    
    func testRequestType() {
        let title = "test 4DM-2001, 4DM-2002"
        let branchHeaders = [Github.eventHeaderName: "create"]
        let pullRequestHeaders = [Github.eventHeaderName: "pull_request"]
        let featureBranch = Github.Branch.template(ref: "feature")
        let pullRequest = Github.PullRequest(url: "",
                                             id: 0,
                                             title: title,
                                             body: "",
                                             head: featureBranch,
                                             base: Github.Branch.template())

        let branchRequest = Github.Payload(ref: title,
                                           refType: Github.RefType.branch)
        let branchType = branchRequest.type(headers: branchHeaders)
        XCTAssertEqual(branchType, .branchCreated(title: title, platform: .iOS))
        
        let openedRequest = Github.Payload(action: Github.Action.opened,
                                           pullRequest: pullRequest)
        let openedType = openedRequest.type(headers: pullRequestHeaders)
        XCTAssertEqual(openedType, .pullRequestOpened(title: title, url: "", body: "", platform: .iOS))

        let editedRequest = Github.Payload(action: Github.Action.edited,
                                           pullRequest: pullRequest)
        let editedType = editedRequest.type(headers: pullRequestHeaders)
        XCTAssertEqual(editedType, .pullRequestEdited(title: title, url: "", body: "", platform: .iOS))

        let closedRequest = Github.Payload(action: Github.Action.closed,
                                           pullRequest: pullRequest)
        let closedType = closedRequest.type(headers: pullRequestHeaders)
        XCTAssertEqual(closedType, .pullRequestClosed(title: title,
                                                      head: featureBranch,
                                                      base: Github.Branch.template(),
                                                      merged: false, platform: .iOS))
        
        let labeledRequest = Github.Payload(action: .labeled,
                                            pullRequest: pullRequest,
                                            label: Github.waitingForReviewLabel)
        let labeledType = labeledRequest.type(headers: pullRequestHeaders)
        XCTAssertEqual(labeledType, .pullRequestLabeled(label: Github.waitingForReviewLabel,
                                                        head: featureBranch,
                                                        base: Github.Branch.template(),
                                                        platform: .iOS))

        let wrongRequest = Github.Payload()
        XCTAssertNil(wrongRequest.type(headers: branchHeaders) ?? wrongRequest.type(headers: pullRequestHeaders))
        
        // empty header
        XCTAssertNil(branchRequest.type(headers: nil)
            ?? openedRequest.type(headers: nil)
            ?? closedRequest.type(headers: nil))
        
        // wrong header
        XCTAssertNil(branchRequest.type(headers: pullRequestHeaders) ?? openedRequest.type(headers: branchHeaders))
        
    }
    
    func testGithubRequestChangesRequested() async throws {
        let labelPath = "/issues/1/labels/waiting for review"
        let pullRequestHeaders = [Github.eventHeaderName: Github.Event.pullRequestReview.rawValue]
        let pullRequest = Github.PullRequest(url: "http://test.com/pulls/1",
                                             id: 1,
                                             title: "x",
                                             body: "",
                                             head: Github.Branch.template(),
                                             base: Github.Branch.template(ref: "master"))

        let response = try await Github.githubRequest(
            Github.Payload(
                action: .submitted,
                review: Github.Review(state: .changesRequested),
                pullRequest: pullRequest,
                installation: Github.Installation(id: 1)
            ),
            pullRequestHeaders,
            Service.mockContext
        ).get()
        
        let url = response.right?.url(token: "x")
        XCTAssertEqual(url?.host, "test.com")
        XCTAssertEqual(url?.path, labelPath)
        XCTAssertEqual(response.right?.installationId, 1)
        XCTAssertEqual(response.right?.method, .DELETE)

    }
    
    func testFailedStatus() async throws {
        let headers = [Github.eventHeaderName: Github.Event.status.rawValue]
        
        let response = try await Github.githubRequest(
            Github.Payload(
                installation: Github.Installation(id: 1),
                commit: Github.Commit(sha: "shaxyz"),
                state: .some(.error)),
            headers,
            Service.mockContext
        ).get()
        
        let query = "shaxyz+label:\"\(Github.waitingForReviewLabel.name)\"+state:open"
        XCTAssertNil(response.left)
        let url = response.right?.url(token: "x")
        XCTAssertEqual(url?.host, "api.github.com")
        XCTAssertEqual(url?.path, "/search/issues?q=\(query)")
        XCTAssertEqual(response.right?.installationId, 1)
        XCTAssertEqual(response.right?.method, .GET)
    }
    
    func testPullRequestOpened() async throws {
        Environment.env[Youtrack.Request.Config.youtrackURL.rawValue] = "https://test.com"
        let title = "#4DM-2001 test"
        let body = "body"
        let headers = [Github.eventHeaderName: Github.Event.pullRequest.rawValue]
        let pullRequest = Github.PullRequest(url: "http://test.com/pulls/1",
                                             id: 1,
                                             title: title,
                                             body: "body",
                                             head: Github.Branch.template(),
                                             base: Github.Branch.template(ref: "master"))

        let response = try await Github.githubRequest(
            Github.Payload(
                action: .opened,
                pullRequest: pullRequest,
                installation: Github.Installation(id: 1)
            ),
            headers,
            Service.mockContext
        ).get()
        XCTAssertNil(response.left)
        let url = response.right?.url(token: "x")
        XCTAssertEqual(url?.host, "test.com")
        XCTAssertEqual(url?.path, "/pulls/1")
        XCTAssertEqual(response.right?.installationId, 1)
        XCTAssertEqual(response.right?.method, .PATCH)
        
        let new = "- "
            + (try Youtrack.issueURLs(from: title,
                                      base: "https://test.com",
                                      pattern: "4DM-[0-9]+")[0])
            + "\n\n\(body)"
        
        struct Body: Decodable, Equatable { let body: String }
        
        XCTAssertEqual(try JSONDecoder().decode(Body.self, from: response.right?.body ?? Data()),
                       Body(body: new))
    }

    func testApiChangesRequested() async throws {
        let api = Github.apiWithGithub(Service.mockContext)

        Environment.env = [
            Github.APIRequest.Config.githubAppId.rawValue: Github.APIRequest.Config.githubAppId.rawValue,
            Github.APIRequest.Config.githubPrivateKey.rawValue: Service.privateKeyString
        ]
        
        class MockAPI: BackendAPIType {
            
            func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
                Environment.env[request.host] = request.host

                switch request.host {
                case "api.github.com":
                    return pure(MockHTTPResponse.okResponse(body:"{\"token\":\"x\"}"), Service.mockContext)
                case "test.com":
                    return pure(MockHTTPResponse.okResponse(body:"{\"message\": \"y\"}"), Service.mockContext)
                default:
                    XCTFail("Shouldn't be more api calls")
                    return pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
                }
            }
        }
        try await Service.loadTest(MockAPI())

        let request = Github.APIRequest(installationId: 1, type: .changesRequested(url: "http://test.com/pulls/1"))
        let response = try await api(request).get()
        XCTAssertEqual(response.right, Github.APIResponse(message: "y"))

        let wrongRequest = Github.APIRequest(installationId: 1, type: .changesRequested(url: "/pulls/1"))
        let wrongResponse = try await api(wrongRequest).get()
        XCTAssertEqual(wrongResponse.left, Github.PayloadResponse(error: Youtrack.Error.underlying(HTTPClientError.emptyScheme)))
    }
    
    func testApiFailedStatus() async throws {
        let api = Github.apiWithGithub(Service.mockContext)
        
        Environment.env = [
            Github.APIRequest.Config.githubAppId.rawValue: Github.APIRequest.Config.githubAppId.rawValue,
            Github.APIRequest.Config.githubPrivateKey.rawValue: Service.privateKeyString
        ]
        
        class MockAPI: BackendAPIType {
            
            func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
                Environment.env[request.host] = request.host

                switch request.host {
                case "api.github.com":
                    if request.url.absoluteString.contains("/app/installations") {
                        return pure(MockHTTPResponse.okResponse(body:"{\"token\":\"x\"}"), Service.mockContext)
                    } else if request.url.absoluteString.contains("/search/issues") {
                        let response = Github.SearchResponse(
                            items: [Github.SearchIssue(pullRequest: .init(url: "https://pr.com/1"))])
                        let data = try! JSONEncoder().encode(response)
                        return pure(MockHTTPResponse.okResponse(body:String(data: data, encoding: .utf8)!), Service.mockContext)
                    } else {
                        XCTFail("Shouldn't be more api calls")
                        return pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
                    }
                case "pr.com":
                    let data = try! JSONEncoder().encode(Github.PullRequest(
                        url: "https://test.com/pull/1",
                        id: 1,
                        title: "title",
                        body: "",
                        head: Github.Branch.template(),
                        base: Github.Branch.template(ref: "master")
                    ))
                     return pure(MockHTTPResponse.okResponse(body:String(data: data, encoding: .utf8)!), Service.mockContext)
                case "test.com":
                    return pure(MockHTTPResponse.okResponse(body:"{\"message\": \"y\"}"), Service.mockContext)
                default:
                    XCTFail("Shouldn't be more api calls")
                    return pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
                }
            }
        }
        try await Service.loadTest(MockAPI())
        
        let request = Github.APIRequest(installationId: 1, type: .failedStatus(sha: "shaxyz"))
        let response = try await api(request).get()
        
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
