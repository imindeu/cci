//
//  Github.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

import APIConnect
import APIModels
import Foundation
import CCryptoOpenSSL

extension GithubWebhookRequest: RequestModel {
    public typealias ResponseModel = GithubWebhookResponse
    public typealias Config = GithubWebhookConfig
    
    public enum GithubWebhookConfig: String, Configuration {
        case githubSecret
    }

    public var responseURL: URL? { return nil }
    
}

extension GithubWebhookRequest {
    static func check(_ from: GithubWebhookRequest) -> GithubWebhookResponse? {
        let token = Environment.get(Config.githubSecret)
        return nil
    }
}

public struct GithubWebhookResponse: Encodable {}
