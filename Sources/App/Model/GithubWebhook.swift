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

public extension GithubWebhook {
    public struct Response: Equatable, Codable {
        public let value: String?
        
        public init(value: String? = nil) {
            self.value = value
        }
        
        public init(error: LocalizedError) {
            self.value = error.localizedDescription
        }
    }
    
    public enum RequestType: String, Equatable {
        case branchCreated
        case pullRequestOpened
        case pullRequestClosed
    }
    
    public enum Error: LocalizedError {
        case signature

        public var errorDescription: String? {
            switch self {
            case .signature: return "Bad github webhook signature"
            }
        }
    }

}

fileprivate typealias Response = GithubWebhook.Response
fileprivate typealias Request = GithubWebhook.Request
fileprivate typealias Event = GithubWebhook.Event
fileprivate typealias RefType = GithubWebhook.RefType
fileprivate typealias Action = GithubWebhook.Action 

extension Request {
    static var signatureHeaderName: String { return "X-Hub-Signature" }
    static var eventHeaderName: String { return "X-GitHub-Event" }
    
    func type(headers: Headers?) -> (GithubWebhook.RequestType, String)? {
        let event = headers?.get(Request.eventHeaderName).flatMap(Event.init)
        
        switch (event, action, pullRequest?.title, ref, refType) {
        case let (.some(.pullRequest), .some(.closed), .some(title), _, _):
            return (.pullRequestClosed, title)
        case let (.some(.pullRequest), .some(.opened), .some(title), _, _):
            return (.pullRequestOpened, title)
        case let (.some(.create), _, _, .some(title), .some(.branch)):
            return (.branchCreated, title)
        default:
            return nil
        }
    }
}

extension Request: RequestModel {
    public typealias ResponseModel = GithubWebhook.Response
    
    public enum Config: String, Configuration {
        case githubSecret
    }
}

extension Request {
    
    static func verify(payload: String?, secret: String?, signature: String?) -> Bool {
        guard let payload = payload,
            let secret = secret,
            let signature = signature,
            let digest = try? HMAC(algorithm: .sha1).authenticate(payload, key: secret) else {
            return false
        }
        return signature == "sha1=\(digest.hexEncodedString())"
    }
    
    static func check(_ from: GithubWebhook.Request, _ payload: String?, _ headers: Headers?) -> GithubWebhook.Response? {
        let secret = Environment.get(Config.githubSecret)
        let signature = headers?.get(Request.signatureHeaderName)
        return verify(payload: payload, secret: secret, signature: signature)
            ? nil
            : Response(error: GithubWebhook.Error.signature)
    }
}
