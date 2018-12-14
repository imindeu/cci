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

private typealias Response = Github.PayloadResponse
private typealias Payload = Github.Payload
private typealias Event = Github.Event
private typealias RefType = Github.RefType
private typealias Action = Github.Action

extension Github {
    static var signatureHeaderName: String { return "X-Hub-Signature" }
    static var eventHeaderName: String { return "X-GitHub-Event" }
}
extension Payload: RequestModel {
    public typealias ResponseModel = Github.PayloadResponse
    
    public enum Config: String, Configuration {
        case githubSecret
    }
}

extension Payload {
    func type(headers: Headers?) -> (Github.RequestType, String)? {
        let event = headers?.get(Github.eventHeaderName).flatMap(Event.init)
        
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

public extension Github {
    public struct PayloadResponse: Equatable, Codable {
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

extension Github {
    static func verify(payload: String?, secret: String?, signature: String?) -> Bool {
        guard let payload = payload,
            let secret = secret,
            let signature = signature,
            let digest = try? HMAC(algorithm: .sha1).authenticate(payload, key: secret) else {
            return false
        }
        return signature == "sha1=\(digest.hexEncodedString())"
    }
    
    static func check(_ from: Github.Payload,
                      _ payload: String?,
                      _ headers: Headers?) -> Github.PayloadResponse? {
        
        let secret = Environment.get(Payload.Config.githubSecret)
        let signature = headers?.get(Github.signatureHeaderName)
        return verify(payload: payload, secret: secret, signature: signature)
            ? nil
            : PayloadResponse(error: Github.Error.signature)
    }
}
