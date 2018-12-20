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
import JWT
import HTTP

private typealias Response = Github.PayloadResponse
private typealias Payload = Github.Payload
private typealias Event = Github.Event
private typealias RefType = Github.RefType
private typealias Action = Github.Action
private typealias APIResponse = Github.APIResponse
private typealias APIRequest = Github.APIRequest

extension Github {
    static var signatureHeaderName: String { return "X-Hub-Signature" }
    static var eventHeaderName: String { return "X-GitHub-Event" }
    
    static var waitingForReviewLabel: Label { return Label(name: "waiting for review") }
    
    static var devBranch: Branch { return Branch(ref: "dev") }
    static var masterBranch: Branch { return Branch(ref: "master") }
    static var releaseBranch: Branch { return Branch(ref: "release") }
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
    
    public struct APIRequest: Equatable, Codable {
        public let installationId: Int
        public let url: URL
        public let body: Data
    }
    
    public enum RequestType {
        case branchCreated
        case pullRequestOpened
        case pullRequestClosed
        case pullRequestLabeled
    }
    
    public enum Error: LocalizedError {
        case signature
        case jwt
        case accessToken
        case badUrl(String)
        case underlying(Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .signature: return "Bad github webhook signature"
            case .jwt: return "JWT token problem"
            case .accessToken: return "Bad github access token"
            case .badUrl(let url): return "Bad github response url (\(url))"
            case .underlying(let error):
                if let localizedError = error as? LocalizedError {
                    return localizedError.localizedDescription
                    
                }
                return "Unknown error (\(error))"
            }
        }
    }

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
        switch (event, action, pullRequest?.label, pullRequest?.title, ref, refType) {
            
        case let (.some(.pullRequest), .some(.closed), _, .some(title), _, _):
            return (.pullRequestClosed, title)
            
        case let (.some(.pullRequest), .some(.opened), _, .some(title), _, _):
            return (.pullRequestOpened, title)
            
        case let (.some(.create), _, _, _, .some(title), .some(.branch)):
            return (.branchCreated, title)
            
        case let (.some(.pullRequest), .some(.labeled), .some(Github.waitingForReviewLabel), .some(title), _, _):
            return (.pullRequestLabeled, title)

        default:
            return nil
        }
    }
}

extension APIRequest: RequestModel {
    public typealias ResponseModel = Github.APIResponse
    
    public enum Config: String, Configuration {
        case githubAppId
        case githubPrivateKey
    }
    
}

extension Github {
    
    // MARK: webhook
    static func verify(body: String?, secret: String?, signature: String?) -> Bool {
        guard let body = body,
            let secret = secret,
            let signature = signature,
            let digest = try? HMAC(algorithm: .sha1).authenticate(body, key: secret) else {
            return false
        }
        return signature == "sha1=\(digest.hexEncodedString())"
    }
    
    static func check(_ from: Github.Payload,
                      _ body: String?,
                      _ headers: Headers?) -> Github.PayloadResponse? {
        
        let secret = Environment.get(Payload.Config.githubSecret)
        let signature = headers?.get(Github.signatureHeaderName)
        return verify(body: body, secret: secret, signature: signature)
            ? nil
            : PayloadResponse(error: Github.Error.signature)
    }
    
    // app
    static func jwt(date: Date = Date()) throws -> String {
        guard let appId = Environment.get(APIRequest.Config.githubAppId),
            let privateKey = Environment.get(APIRequest.Config.githubPrivateKey) else {
            throw Error.jwt
        }
        struct PayloadData: JWTPayload {
            let iat: Date
            let exp: ExpirationClaim
            let iss: String
            
            func verify(using signer: JWTSigner) throws { try exp.verifyNotExpired() }
        }
        let iat = date
        let exp = ExpirationClaim(value: iat.addingTimeInterval(10 * 60))
        let signer = try JWTSigner.rs256(key: RSAKey.private(pem: privateKey))
        let jwt = JWT<PayloadData>(payload: PayloadData(iat: iat, exp: exp, iss: appId))
        let data = try jwt.sign(using: signer)
        guard let string = String(data: data, encoding: .utf8) else { throw Error.signature }
        return string
    }
    
    static func accessToken(context: Context, jwtToken: String, installationId: Int) -> IO<String> {
        let api = Environment.api("api.github.com", nil)
        var request = HTTPRequest()
        request.method = .POST
        request.urlString = "app/installations/\(installationId)/access_tokens"
        request.headers = HTTPHeaders([
            ("Authorization", "Bearer \(jwtToken)"),
            ("Accept", "application/vnd.github.machine-man-preview+json")
        ])
        struct TokenResponse: Decodable {
            let token: String
        }

        return api(context, request)
            .decode(TokenResponse.self)
            .map { response in
                guard let response = response else {
                    throw Github.Error.accessToken
                }
                return response.token
            }
    }
    
    static func githubRequest(_ from: Github.Payload,
                              _ headers: Headers?) -> Either<Github.PayloadResponse, Github.APIRequest> {
        let defaultResponse: Either<Github.PayloadResponse, Github.APIRequest> = .left(PayloadResponse())
        guard let (type, _) = from.type(headers: headers) else {
            return defaultResponse
        }
        switch type {
        case .pullRequestLabeled:
            guard let installationId = from.installation?.id,
                let comments = from.pullRequest?.links.comments.href,
                let url = URL(string: comments) else {
                return defaultResponse
            }
            guard let reviewers = from.pullRequest?.requestedReviewers, !reviewers.isEmpty else {
                return defaultResponse
            }
            
            do {
                let body = try JSONEncoder().encode(Github.IssueComment(body: reviewText(reviewers)))
                return .right(APIRequest(installationId: installationId, url: url, body: body))
            } catch {
                return defaultResponse
            }
        default: return defaultResponse
        }
    }
    
    static func apiWithGithub(_ context: Context)
        -> (Either<Github.PayloadResponse, Github.APIRequest>)
        -> EitherIO<Github.PayloadResponse, Github.APIResponse> {
            
            let instantResponse: (Github.PayloadResponse)
                -> EitherIO<Github.PayloadResponse, APIResponse> = {
                    pure(.left($0), context)
            }
            return {
                return $0.either(instantResponse, fetch(context))
            }
    }
    
    static func responseToGithub(_ from: Github.APIResponse) -> Github.PayloadResponse {
        return PayloadResponse(value: from.message.map { $0 + " (\(from.errors ?? []))" })
    }
    
    static func reduce(_ responses: [Github.PayloadResponse?]) -> Github.PayloadResponse? {
        return responses
            .reduce(Github.PayloadResponse()) { next, result in
                guard let value = next.value else {
                    return result ?? Github.PayloadResponse()
                }
                let response = (result?.value.map { $0 + "\n" } ?? "") + value
                return Github.PayloadResponse(value: response)
            }

    }
    
    static func reviewText(_ reviewers: [User]) -> String {
        let current = reviewers
            .map { user in return "@\(user.login)" }
            .joined(separator: ", ")
        return "\(current) please review this pr"
    }

    private static func fetch(_ context: Context) -> (APIRequest)
        -> EitherIO<Github.PayloadResponse, Github.APIResponse> {
        
        return { request -> EitherIO<PayloadResponse, APIResponse> in
            do {
                return accessToken(context: context,
                                   jwtToken: try jwt(),
                                   installationId: request.installationId).flatMap { accessToken in
                    guard let host = request.url.host else {
                        return pure(
                            .left(PayloadResponse(error: Github.Error.badUrl(request.url.absoluteString))),
                            context)
                    }
                    let api = Environment.api(host, request.url.port)
                    let headers = HTTPHeaders([
                        ("Authorization", "token \(accessToken)"),
                        ("Accept", "application/vnd.github.machine-man-preview+json")
                    ])
                    let httpRequest = HTTPRequest(method: .POST,
                                                  url: request.url.path,
                                                  version: HTTPVersion(major: 1, minor: 1),
                                                  headers: headers,
                                                  body: request.body)
                    return api(context, httpRequest)
                        .decode(APIResponse.self)
                        .map {
                            let response = $0 ?? APIResponse()
                            return Either<PayloadResponse, APIResponse>.right(response)
                        }
                }
            } catch {
                return pure(.left(PayloadResponse(error: Github.Error.underlying(error))), context)
            }
        }
    }
}
