//
//  Github+Github.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 07..
//

import APIConnect
import APIModels

import protocol Foundation.LocalizedError
import struct Foundation.Data
import struct Foundation.URL
import class Foundation.JSONEncoder

import enum HTTP.HTTPMethod

public extension Github {
    
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
        public let installationId: Int?
        public let type: RequestType
        
        public init(installationId: Int, type: RequestType) {
            self.installationId = installationId
            self.type = type
        }
        
        public init(type: RequestType) {
            self.installationId = nil
            self.type = type
        }

    }
    
    public enum RequestType: Equatable {
        case branchCreated(title: String)
        case pullRequestOpened(title: String, url: String, body: String)
        case pullRequestEdited(title: String, url: String, body: String)
        case pullRequestClosed(title: String)
        case pullRequestLabeled(label: Label, head: Branch, base: Branch)
        case changesRequested(url: String)
        case failedStatus(sha: String)
        case getPullRequest(url: String)
        
        var title: String? {
            switch self {
            case .branchCreated(let t), .pullRequestClosed(let t), .pullRequestOpened(let t, _, _):
                return t
            default:
                return nil
            }
        }
        
    }
    
    public enum Error: LocalizedError {
        case signature
        case jwt
        case accessToken
        case installation
        case underlying(Swift.Error)
        
        public var errorDescription: String? {
            switch self {
            case .signature: return "Bad github webhook signature"
            case .jwt: return "JWT token problem"
            case .accessToken: return "Bad github access token"
            case .installation: return "No installation"
            case .underlying(let error):
                return (error as? LocalizedError).map { $0.localizedDescription } ?? "Unknown error (\(error))"
            }
        }
    }
    
}

extension Github.Payload: RequestModel {
    public typealias ResponseModel = Github.PayloadResponse
    
    public enum Config: String, Configuration {
        case githubSecret
    }
}

extension Github.Payload {
    func type(headers: Headers?) -> Github.RequestType? {
        let event = headers?.get(Github.eventHeaderName).flatMap(Github.Event.init)
        switch (event, action,
                label, review?.state,
                pullRequest,
                ref, refType,
                commit?.sha, state) {
            
        case let (.some(.pullRequest), .some(.closed), _, _, .some(pr), _, _, _, _):
            return .pullRequestClosed(title: pr.title)
        case let (.some(.pullRequest), .some(.opened), _, _, .some(pr), _, _, _, _):
            return .pullRequestOpened(title: pr.title, url: pr.url, body: pr.body)
        case let (.some(.pullRequest), .some(.reopened), _, _, .some(pr), _, _, _, _):
            return .pullRequestOpened(title: pr.title, url: pr.url, body: pr.body)
        case let (.some(.pullRequest), .some(.edited), _, _, .some(pr), _, _, _, _):
            return .pullRequestEdited(title: pr.title, url: pr.url, body: pr.body)
            
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

extension Github.APIRequest: RequestModel {
    public typealias ResponseModel = Github.APIResponse
    
    public enum Config: String, Configuration {
        case githubAppId
        case githubPrivateKey
    }
    
}

extension Github.APIRequest: HTTPRequestable {
    
    public var method: HTTPMethod? {
        switch self.type {
        case .pullRequestOpened, .pullRequestEdited: return .PATCH
        case .changesRequested: return .DELETE
        case .failedStatus, .getPullRequest: return .GET
        default: return nil
        }
    }
    
    public var body: Data? {
        switch self.type {
        case let .pullRequestOpened(title: title, _, body: body),
             let .pullRequestEdited(title: title, _, body: body):
            let issues =
                (try? Youtrack.issueURLs(from: title,
                                         base: Environment.get(Youtrack.Request.Config.youtrackURL),
                                         pattern: "4DM-[0-9]+")
                .filter { !body.contains($0) }
                .map { "- \($0)" }) ?? []
            if !issues.isEmpty {
                let new = issues.joined(separator: "\n") + "\n\n" + body
                
                struct Body: Encodable { let body: String }
                
                return try? JSONEncoder().encode(Body(body: new))
            } else {
                return nil
            }
        default: return nil
        }
    }
    
    public func url(token: String) -> URL? {
        let waitingForReview = Github.waitingForReviewLabel.name
        switch self.type {
        case let .changesRequested(url: url):
            return URL(string: url.replacingOccurrences(of: "/pulls", with: "/issues"))?
                .appendingPathComponent("labels")
                .appendingPathComponent(waitingForReview)
        case let .failedStatus(sha: sha):
            let query = "issues?q=\(sha)+label:\"\(waitingForReview)\"+state:open"
            return URL(string: "https://api.github.com/search/")?.appendingPathComponent(query)
        case let .pullRequestOpened(_, url: url, _),
             let .pullRequestEdited(_, url: url, _),
             let .getPullRequest(url: url):
            return URL(string: url)
        default: return nil
        }
    }

    public func headers(token: String) -> [(String, String)] {
        return [
            ("Authorization", "token \(token)"),
            ("Accept", "application/vnd.github.machine-man-preview+json"),
            ("User-Agent", "cci-imind")
        ]
    }
}

extension Github {
    
    static func check(_ from: Github.Payload,
                      _ body: String?,
                      _ headers: Headers?) -> Github.PayloadResponse? {
        
        let secret = Environment.get(Payload.Config.githubSecret)
        let signature = headers?.get(signatureHeaderName)
        return verify(body: body, secret: secret, signature: signature)
            ? nil
            : PayloadResponse(error: Error.signature)
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
                do {
                    guard let appId = Environment.get(APIRequest.Config.githubAppId),
                        let privateKey = Environment.get(APIRequest.Config.githubPrivateKey)?
                            .replacingOccurrences(of: "\\n", with: "\n") else {
                                throw Error.jwt
                    }
                    guard let installationId = request.installationId else {
                        throw Error.installation
                    }
                    return accessToken(context: context,
                                       jwtToken: try jwt(appId: appId, privateKey: privateKey),
                                       installationId: installationId,
                                       api: Environment.api)
                        .map { token in
                            guard let token = token else {
                                throw Error.accessToken
                            }
                            return token
                        }
                        .flatMap {
                            try fetchRequest(installationId: installationId,
                                             token: $0,
                                             request: request,
                                             context: context)
                            .clean()
                        }
                } catch {
                    return leftIO(context)(PayloadResponse(error: Error.underlying(error)))
                }
            }
    }
    
    static func responseToGithub(_ from: APIResponse) -> PayloadResponse {
        return PayloadResponse(value: from.message.map { $0 + " (\(from.errors ?? []))" })
    }
    
    private static func fetchRequest(installationId: Int,
                                     token: String,
                                     request: APIRequest,
                                     context: Context) throws -> TokenedIO<APIResponse?> {
        let instant = pure(Tokened<APIResponse?>(token, nil), context)
        switch request.type {
        case .changesRequested:
            return try Service.fetch(request, APIResponse.self, token, context, Environment.api)
        case .failedStatus:
            return try Service.fetch(request, SearchResponse<SearchIssue>.self, token, context, Environment.api)
                .map { result -> String? in
                    return result?.items?
                        .compactMap { item -> String? in
                            return item.pullRequest?.url
                        }
                        .first
                }
                .fetch(context, PullRequest.self) { APIRequest(type: .getPullRequest(url: $0 )) }
                .fetch(context, APIResponse.self) { APIRequest(type: .changesRequested(url: $0.url)) }
        case .pullRequestOpened, .pullRequestEdited:
            if request.body == nil {
                return instant
            } else {
                return try Service.fetch(request, APIResponse.self, token, context, Environment.api)
            }
        default:
            return instant
        }
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
    
}

extension TokenedIO where T == Tokened<Github.APIResponse?> {
    func clean() -> EitherIO<Github.PayloadResponse, Github.APIResponse> {
        return map { $0.value }
            .catchMap {
                if case DecodingError.typeMismatch = $0 {
                    return nil
                } else {
                    throw $0
                }
            }
            .map {
                let response = $0 ?? Github.APIResponse()
                return response
            }
            .map { .right($0) }
            .catchMap { .left(Github.PayloadResponse(error: Github.Error.underlying($0))) }
    }
    
}
