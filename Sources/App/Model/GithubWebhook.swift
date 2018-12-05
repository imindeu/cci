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

enum GithubWebhookType: String {
    case branch
    case opened
    case closed
}

extension GithubWebhookRequest {
    static var headerName: String { return "X-Hub-Signature" }
    
    var type: (GithubWebhookType, String)? {
        switch (action, pullRequest?.title, ref, refType) {
        case let (GithubWebhookType.closed.rawValue, .some(title), _, _):
            return (.closed, title)
        case let (GithubWebhookType.opened.rawValue, .some(title), _, _):
            return (.opened, title)
        case let (_, _, .some(title), GithubWebhookType.branch.rawValue):
            return (.branch, title)
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
        let signature = headers?.get(GithubWebhookRequest.headerName)
        return verify(payload: payload, secret: secret, signature: signature)
            ? nil
            : GithubWebhookResponse(error: GithubWebhookError.signature)
    }
}

public struct GithubWebhookResponse: Equatable, Codable {
    public let failure: String?
    
    public init(failure: String? = nil) {
        self.failure = failure
    }
    
    public init(error: LocalizedError) {
        self.failure = error.localizedDescription
    }
}
