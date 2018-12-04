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
        let signature = headers?.get("HTTP_X_HUB_SIGNATURE")
        return verify(payload: payload, secret: secret, signature: signature)
            ? nil
            : GithubWebhookResponse(failure: "bad signature")
    }
}

public struct GithubWebhookResponse: Equatable, Codable {
    public let failure: String?
    
    public init(failure: String? = nil) {
        self.failure = failure
    }
}
