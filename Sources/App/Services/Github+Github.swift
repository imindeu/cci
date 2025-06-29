//
//  Github+Github.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 07..
//

import APIConnect
import APIService

import enum APIModels.Github
import enum APIModels.Youtrack

import protocol Foundation.LocalizedError
import struct Foundation.Data
import struct Foundation.URL
import class Foundation.JSONEncoder

import enum HTTP.HTTPMethod

public extension Github {
    
    static var waitingForReviewLabel: Label { return Label(name: "waiting for review") }
    
    static func isDev(branch: Branch) -> Bool { return branch.ref == "dev" }
    static func isMaster(branch: Branch) -> Bool { return ["master", "fourd", "oc", "sp"].contains(branch.ref) }
    static func isRelease(branch: Branch) -> Bool { return ["release", "release_oc", "release_sp"].contains(branch.ref) }
    
    static func isMain(branch: Branch) -> Bool { return isDev(branch: branch) || isMaster(branch: branch) || isRelease(branch: branch) }
}

public extension Github {
    struct PayloadResponse: Equatable, Codable {
        public let value: String?
        
        public init(value: String? = nil) {
            self.value = value
        }
        
        public init(error: LocalizedError) {
            self.value = error.localizedDescription
        }
    }
    
    struct APIRequest: Equatable {
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
    
    enum PlatformType: String {
        case android
        case iOS
    }
    
    enum RequestType: Equatable {
        case branchCreated(title: String, platform: PlatformType)
        case branchPushed(Branch)
        case pullRequestOpened(title: String, url: String, body: String, platform: PlatformType)
        case pullRequestEdited(title: String, url: String, body: String, platform: PlatformType)
        case pullRequestClosed(title: String, head: Branch, base: Branch, merged: Bool, platform: PlatformType)
        case pullRequestLabeled(label: Label, head: Branch, base: Branch, platform: PlatformType)
        case changesRequested(url: String)
        case failedStatus(sha: String)
        case getPullRequest(url: String)
        case getStatus(sha: String, url: String)
        
        var title: String? {
            switch self {
            case .branchCreated(let t, _), .pullRequestClosed(let t, _, _, _, _), .pullRequestOpened(let t, _, _, _):
                return t
            default:
                return nil
            }
        }
        
        var platform: PlatformType? {
            switch self {
            case .branchCreated(_, let platform),.pullRequestClosed(_, _, _, _, let platform), .pullRequestOpened(_, _, _, let platform):
                return platform
            default:
                return nil
            }
        }
    }
    
    enum Error: LocalizedError {
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
        let platform: Github.PlatformType = repository?.name == "4dmotion-ios" ? .iOS : .android
        
        switch (event,
                action,
                label,
                review?.state,
                pullRequest,
                ref,
                refType,
                commit?.sha,
                state,
                repository) {
            
        case let (.some(.pullRequest), .some(.closed), _, _, .some(pr), _, _, _, _, _):
            return .pullRequestClosed(title: pr.title, head: pr.head, base: pr.base, merged: pr.merged, platform: platform)
        case let (.some(.pullRequest), .some(.opened), _, _, .some(pr), _, _, _, _, _):
            return .pullRequestOpened(title: pr.title, url: pr.url, body: pr.body ?? "", platform: platform)
        case let (.some(.pullRequest), .some(.reopened), _, _, .some(pr), _, _, _, _, _):
            return .pullRequestOpened(title: pr.title, url: pr.url, body: pr.body ?? "", platform: platform)
        case let (.some(.pullRequest), .some(.edited), _, _, .some(pr), _, _, _, _, _):
            return .pullRequestEdited(title: pr.title, url: pr.url, body: pr.body ?? "", platform: platform)
            
        case let (.some(.create), _, _, _, _, .some(title), .some(.branch), _, _, _):
            return .branchCreated(title: title, platform: platform)
        case let (.some(.push), _, _, _, _, .some(ref), _, _, _, .some(repository)):
            let branch = ref.components(separatedBy: "/").last
            return .branchPushed(.init(ref: branch ?? ref, sha: "", repo: repository))
            
        case let (.some(.pullRequest), .some(.labeled), .some(label), _, .some(pr), _, _, _, _, _):
            return .pullRequestLabeled(label: label, head: pr.head, base: pr.base, platform: platform)
            
        case let (.some(.pullRequestReview), .some(.submitted), _, .some(.changesRequested), .some(pr), _, _, _, _, _):
            return .changesRequested(url: pr.url)
            
        case let (.some(.status), _, _, _, _, _, _, .some(sha), .some(.error), _):
            return .failedStatus(sha: sha)
        case let (.some(.status), _, _, _, _, _, _, .some(sha), .some(.failure), _):
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

extension Github.APIRequest: TokenRequestable {
    
    public var method: HTTPMethod? {
        switch self.type {
        case .pullRequestOpened, .pullRequestEdited: return .PATCH
        case .changesRequested: return .DELETE
        case .failedStatus, .getPullRequest, .getStatus: return .GET
        default: return nil
        }
    }
    
    public var body: Data? {
        switch self.type {
        case let .pullRequestOpened(title: title, _, body: body, platform: _),
            let .pullRequestEdited(title: title, _, body: body, platform: _):
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
        case let .pullRequestOpened(_, url: url, _, _),
             let .pullRequestEdited(_, url: url, _, _),
             let .getPullRequest(url: url):
            return URL(string: url)
        case let .getStatus(sha: sha, url: url):
            return URL(string: url)?
                .appendingPathComponent("commits")
                .appendingPathComponent(sha)
                .appendingPathComponent("statuses")
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
                              _ headers: Headers?,
                              _ context: Context) -> EitherIO<PayloadResponse, APIRequest> {
        let defaultResponse: EitherIO<PayloadResponse, APIRequest> = leftIO(context)(PayloadResponse())
        guard let type = from.type(headers: headers),
            let installationId = from.installation?.id else {
                return defaultResponse
        }
        return rightIO(context)(APIRequest(installationId: installationId, type: type))
    }
    
    static func apiWithGithub(_ context: Context)
        -> (APIRequest)
        -> EitherIO<PayloadResponse, APIResponse> {
            return { request -> EitherIO<PayloadResponse, APIResponse> in
                do {
                    guard let installationId = request.installationId else {
                        throw Error.installation
                    }
                    return try fetchAccessToken(installationId, context)
                        .flatMap {
                            try fetchRequest(token: $0,
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
    
    static func fetchAccessToken(_ installationId: Int,
                                 _ context: Context) throws -> IO<String> {
        guard let appId = Environment.get(APIRequest.Config.githubAppId),
            let privateKey = Environment.get(APIRequest.Config.githubPrivateKey)?
                .replacingOccurrences(of: "\\n", with: "\n") else {
                    throw Error.jwt
        }
        guard let jwtToken = try jwt(appId: appId, privateKey: privateKey) else {
            throw Error.signature
        }
        return accessToken(context: context,
                           jwtToken: jwtToken,
                           installationId: installationId,
                           api: Environment.api)
            .map { token in
                guard let token = token else {
                    throw Error.accessToken
                }
                return token
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

private extension Github {
    
    static func fetchRequest(token: String,
                             request: APIRequest,
                             context: Context) throws -> TokenedIO<APIResponse?> {
        let instant = pure(Tokened<APIResponse?>(token, nil), context)
        switch request.type {
        case .changesRequested:
            return try Service.fetch(request, APIResponse.self, token, context, Environment.api, isDebugMode: Environment.isDebugMode())
        case .failedStatus:
            return try Service.fetch(request, SearchResponse<SearchIssue>.self, token, context, Environment.api, isDebugMode: Environment.isDebugMode())
                .map { result -> String? in
                    return result?.items?
                        .compactMap { item -> String? in
                            return item.pullRequest?.url
                        }
                        .first
                }
                .fetch(context, PullRequest.self, Environment.api) { APIRequest(type: .getPullRequest(url: $0 )) }
                .fetch(context, APIResponse.self, Environment.api) { APIRequest(type: .changesRequested(url: $0.url)) }
        case .pullRequestOpened, .pullRequestEdited:
            if request.body == nil {
                return instant
            } else {
                return try Service.fetch(request, APIResponse.self, token, context, Environment.api, isDebugMode: Environment.isDebugMode())
            }
        default:
            return instant
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
