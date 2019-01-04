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
    
    public struct APIRequest: Equatable {
        public let installationId: Int
        public let type: RequestType
        
        public init(installationId: Int, type: RequestType) {
            self.installationId = installationId
            self.type = type
        }
    }
    
    public enum RequestType: Equatable {
        case branchCreated(title: String)
        case pullRequestOpened(title: String)
        case pullRequestClosed(title: String)
        case pullRequestLabeled(label: Label, head: Branch, base: Branch)
        case changesRequested(url: String)
        case failedStatus(sha: String)
        case getPullRequest(url: String)
        
        var title: String? {
            switch self {
            case .branchCreated(let t), .pullRequestClosed(let t), .pullRequestOpened(let t):
                return t
            default:
                return nil
            }
        }
        
        var url: URL? {
            let waitingForReview = Github.waitingForReviewLabel.name
            switch self {
            case let .changesRequested(url: url):
                return URL(string: url)?
                    .appendingPathComponent("labels")
                    .appendingPathComponent(waitingForReview)
            case let .failedStatus(sha: sha):
                let query = "\(sha)+label:\"\(waitingForReview)\"+state:open"
                return URL(string: "https://api.github.com/search/issues?q=\(query)")
            case let .getPullRequest(url: url):
                return URL(string: url)
            default: return nil
            }
        }
        
        var method: HTTPMethod? {
            switch self {
            case .changesRequested: return .DELETE
            case .failedStatus, .getPullRequest: return .GET
            default: return nil
            }
        }
    }
    
    public enum Error: LocalizedError {
        case signature
        case jwt
        case accessToken
        case noMethod
        case noURL
        case badUrl(String)
        case underlying(Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .signature: return "Bad github webhook signature"
            case .jwt: return "JWT token problem"
            case .accessToken: return "Bad github access token"
            case .noMethod: return "Type doesn't have a method"
            case .noURL: return "Type doesn't have an url"
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
    func type(headers: Headers?) -> Github.RequestType? {
        let event = headers?.get(Github.eventHeaderName).flatMap(Event.init)
        switch (event, action,
                label, review?.state,
                pullRequest,
                ref, refType,
                commit?.sha, state) {
            
        case let (.some(.pullRequest), .some(.closed), _, _, .some(pr), _, _, _, _):
            return .pullRequestClosed(title: pr.title)
        case let (.some(.pullRequest), .some(.opened), _, _, .some(pr), _, _, _, _):
            return .pullRequestOpened(title: pr.title)
        case let (.some(.pullRequest), .some(.reopened), _, _, .some(pr), _, _, _, _):
            return .pullRequestOpened(title: pr.title)

        case let (.some(.create), _, _, _, _, .some(title), .some(.branch), _, _):
            return .branchCreated(title: title)
            
        case let (.some(.pullRequest), .some(.labeled), .some(label), _, .some(pr), _, _, _, _):
            return .pullRequestLabeled(label: label, head: pr.head, base: pr.base)
            
        case let (.some(.pullRequestReview), .some(.submitted), _, .some(.changesRequested), .some(pr), _, _, _, _):
            return .changesRequested(url: pr.url)
            
        case let (.some(.status), _, _, _, _, _, _, .some(sha), .some(.error)):
            return .failedStatus(sha: sha)
        case let (.some(.status), _, _, _, _, _, _, .some(sha), .some(.failure)):
            return .failedStatus(sha: sha)

//        case (_, _, _, _, _, _, _, _, _):

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
    
    fileprivate struct Tokened<A> {
        let token: String
        let value: A
        
        init(_ token: String, _ value: A) {
            self.token = token
            self.value = value
        }
    }
    
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
        let signature = headers?.get(signatureHeaderName)
        return verify(body: body, secret: secret, signature: signature)
            ? nil
            : PayloadResponse(error: Error.signature)
    }
    
    // app
    static func jwt(date: Date = Date()) throws -> String {
        guard let appId = Environment.get(APIRequest.Config.githubAppId),
            let privateKey = Environment.get(APIRequest.Config.githubPrivateKey)?
                .replacingOccurrences(of: "\\n", with: "\n") else {
            throw Error.jwt
        }
        struct PayloadData: JWTPayload {
            let iat: Int
            let exp: Int
            let iss: String
            
            func verify(using signer: JWTSigner) throws {  }
        }
        let iat = Int(date.timeIntervalSince1970)
        let exp = Int(date.addingTimeInterval(10 * 60).timeIntervalSince1970)
        let signer = try JWTSigner.rs256(key: RSAKey.private(pem: privateKey))
        let jwt = JWT<PayloadData>(payload: PayloadData(iat: iat, exp: exp, iss: appId))
        let data = try jwt.sign(using: signer)
        guard let string = String(data: data, encoding: .utf8) else { throw Error.signature }
        return string
    }
    
    static func accessToken(context: Context, jwtToken: String, installationId: Int) -> () -> IO<String> {
        return {
            let api = Environment.api("api.github.com", nil)
            let headers = HTTPHeaders([
                ("Authorization", "Bearer \(jwtToken)"),
                ("Accept", "application/vnd.github.machine-man-preview+json"),
                ("User-Agent", "cci-imind")
            ])
            let request = HTTPRequest(method: .POST,
                                      url: "/app/installations/\(installationId)/access_tokens",
                                      headers: headers,
                                      body: "")
            struct TokenResponse: Decodable {
                let token: String
            }
            
            return api(context, request)
                .decode(TokenResponse.self)
                .map { response in
                    guard let response = response else {
                        throw Error.accessToken
                    }
                    return response.token
                }
        }
    }
    
    static func githubRequest(_ from: Payload,
                              _ headers: Headers?) -> Either<PayloadResponse, APIRequest> {
        let defaultResponse: Either<PayloadResponse, APIRequest> = .left(PayloadResponse())
        guard let type = from.type(headers: headers),
            let installationId = from.installation?.id else {
            return defaultResponse
        }
        return .right(APIRequest(installationId: installationId, type: type))
    }
    
    static func apiWithGithub(_ context: Context)
        -> (APIRequest)
        -> EitherIO<PayloadResponse, APIResponse> {
            return { request -> EitherIO<PayloadResponse, APIResponse> in
                let installationId = request.installationId
                do {
                    switch request.type {
                    case .changesRequested:
                        return try fetch(request, APIResponse.self, context)
                            .clean()
                    case .failedStatus:
                        return try fetch(request, APISearchResponse<IssueResult>.self, context)
                            .mapTokened { result -> String? in
                                return result?.items?
                                    .compactMap { item -> String? in
                                        return item.pullRequest?.url
                                    }
                                    .first
                            }
                            .fetch(context, PullRequest.self, installationId) { .getPullRequest(url: $0 ) }
                            .fetch(context, APIResponse.self, installationId) { .changesRequested(url: $0.url) }
                            .clean()
                    default:
                        return leftIO(context)(PayloadResponse())
                    }
                } catch {
                    return leftIO(context)(PayloadResponse(error: Error.underlying(error)))
                }
            }
    }
    
    static func responseToGithub(_ from: APIResponse) -> PayloadResponse {
        return PayloadResponse(value: from.message.map { $0 + " (\(from.errors ?? []))" })
    }
    
    static func reduce(_ responses: [PayloadResponse?]) -> PayloadResponse? {
        return responses
            .reduce(PayloadResponse()) { next, result in
                guard let value = next.value else {
                    return result ?? PayloadResponse()
                }
                let response = (result?.value.map { $0 + "\n" } ?? "") + value
                return PayloadResponse(value: response)
            }

    }
    
    static func reviewText(_ reviewers: [User]) -> String {
        let list = reviewers
            .map { user in return "@\(user.login)" }
            .joined(separator: ", ")
        return "\(list) please review this pr"
    }
    
    fileprivate static func fetch<A: Decodable>(_ request: APIRequest,
                                                _ responseType: A.Type,
                                                _ context: Context,
                                                _ token: String? = nil) throws -> IO<Tokened<A?>> {
        guard let method = request.type.method else {
            throw Error.noMethod
        }
        guard let url = request.type.url else {
            throw Error.noURL
        }
        guard let host = url.host,
            let path = url.path
                .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed) else {
                    throw Error.badUrl(url.absoluteString)
        }
        
        let tokenFetch: () -> IO<String> = try token.map { t in { pure(t, context) } }
            ?? accessToken(context: context, jwtToken: try jwt(), installationId: request.installationId)
        
        return tokenFetch()
            .flatMap { accessToken in
                let api = Environment.api(host, url.port)
                let headers = HTTPHeaders([
                    ("Authorization", "token \(accessToken)"),
                    ("Accept", "application/vnd.github.machine-man-preview+json"),
                    ("User-Agent", "cci-imind")
                ])
                
                let httpRequest = HTTPRequest(method: method,
                                              url: path,
                                              headers: headers)
                
                return api(context, httpRequest)
                    .decode(responseType)
                    .map { Tokened(accessToken, $0) }
            }
    }
}

private extension IO where T == Github.Tokened<APIResponse?> {
    func clean() -> EitherIO<Github.PayloadResponse, APIResponse> {
        return map { $0.value }
            .catchMap {
                if case DecodingError.typeMismatch = $0 {
                    return nil
                } else {
                    throw $0
                }
            }
            .map {
                let response = $0 ?? APIResponse()
                return response
            }
            .map { .right($0) }
            .catchMap { .left(Github.PayloadResponse(error: Github.Error.underlying($0))) }
    }
    
}

private extension IO {
    func mapTokened<A, B>(_ callback: @escaping (A) throws -> B) -> IO<Github.Tokened<B>> where T == Github.Tokened<A> {
        return map { tokened in return Github.Tokened(tokened.token, try callback(tokened.value)) }
    }
    
    private func fetchTokened<A: Decodable>(_ context: Context, _ returnType: A.Type)
        -> IO<Github.Tokened<A?>> where T == Github.Tokened<APIRequest?> {
            
        return self.flatMap { tokened in
            guard let value = tokened.value else { return pure(Github.Tokened<A?>(tokened.token, nil), context) }
            return try Github.fetch(value, returnType, context, tokened.token)
        }
    }
    
    func fetch<A, B: Decodable>(_ context: Context,
                                _ returnType: B.Type,
                                _ installationId: Int,
                                _ type: @escaping (A) -> Github.RequestType)
        -> IO<Github.Tokened<B?>> where T == Github.Tokened<A?> {
        
        return mapTokened { value -> APIRequest? in
            return value.map {
                APIRequest(installationId: installationId, type: type($0))
            }
        }.fetchTokened(context, returnType)
    }
}
