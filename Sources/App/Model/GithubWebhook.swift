//
//  Github.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

import APIConnect
import APIModels
import Foundation
import Crypto

enum GithubWebhookError: Error {
    case signature
}

extension GithubWebhookError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .signature: return "Bad github webhook signature"
        }
    }
}

enum GithubWebhookType: String, Equatable {
    case branchCreated
    case pullRequestOpened
    case pullRequestClosed
}

enum GithubWebhookEventType: String {
    case create = "create"
    case pullRequest = "pull_request"
}

extension GithubWebhookRequest {
    static var signatureHeaderName: String { return "X-Hub-Signature" }
    static var eventHeaderName: String { return "X-GitHub-Event" }
    
    func type(headers: Headers?) -> (GithubWebhookType, String)? {
        let event = headers?.get(GithubWebhookRequest.eventHeaderName).flatMap(GithubWebhookEventType.init)
        let pullRequestType = action.flatMap(GithubWebhookType.init)
        let branchType = refType.flatMap(GithubWebhookType.init)
        switch (event, pullRequestType, pullRequest?.title, ref, branchType) {
        case let (.some(.pullRequest), .some(.pullRequestClosed), .some(title), _, _):
            return (.pullRequestClosed, title)
        case let (.some(.pullRequest), .some(.pullRequestOpened), .some(title), _, _):
            return (.pullRequestOpened, title)
        case let (.some(.create), _, _, .some(title), .some(.branchCreated)):
            return (.branchCreated, title)
        default:
            return nil
        }
    }
}

extension GithubWebhookRequest: RequestModel {
    public typealias ResponseModel = GithubWebhookResponse
    public typealias Config = GithubWebhookConfig
    
    public enum GithubWebhookConfig: String, Configuration {
        case githubSecret
    }
}

extension GithubWebhookRequest {
    
    static func verify(payload: String?, secret: String?, signature: String?) -> Bool {
        guard let payload = payload,
            let secret = secret,
            let signature = signature,
            let digest = try? HMAC(algorithm: .sha1).authenticate(payload, key: secret) else {
            return false
        }
        return signature == "sha1=\(digest.hexEncodedString())"
    }
    
    static func check(_ from: GithubWebhookRequest, _ payload: String?, _ headers: Headers?) -> GithubWebhookResponse? {
        let secret = Environment.get(Config.githubSecret)
        let signature = headers?.get(GithubWebhookRequest.signatureHeaderName)
        return verify(payload: payload, secret: secret, signature: signature)
            ? nil
            : GithubWebhookResponse(error: GithubWebhookError.signature)
    }
}

public struct GithubWebhookResponse: Equatable, Codable {
    public let value: String?
    
    public init(value: String? = nil) {
        self.value = value
    }
    
    public init(error: LocalizedError) {
        self.value = error.localizedDescription
    }
}
