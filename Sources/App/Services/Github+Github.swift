//
//  Github+Github.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 07..
//

import APIConnect
import APIService
import APIModels

import Foundation

import Vapor

public extension Github {
    static func isDev(branch: Branch) -> Bool { return branch.ref == "dev" }
    static func isMaster(branch: Branch) -> Bool { return ["master", "fourd", "oc", "sp"].contains(branch.ref) }
    static func isRelease(branch: Branch) -> Bool { return ["release", "release_oc", "release_sp"].contains(branch.ref) }
    
    static func isMain(branch: Branch) -> Bool { return isDev(branch: branch) || isMaster(branch: branch) || isRelease(branch: branch) }
}

public extension Github.Label {
    static let waitingForReview = Github.Label(name: "waiting for review")
    static let stale = Github.Label(name: "stale")
}

public extension Github {
    struct PayloadResponse: Equatable, Codable, Sendable {
        public let value: String?
        
        public init(value: String? = nil) {
            self.value = value
        }
        
        public init(error: Swift.Error) {
            self.value = error.localizedDescription
        }
    }
    
    struct APIRequest: Equatable, Sendable {
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
    
    enum PlatformType: String, Sendable {
        case android
        case iOS
    }
    
    enum RequestType: Equatable, Sendable {
        case branchCreated(title: String, platform: PlatformType)
        case branchPushed(Branch)
        case pullRequestOpened(title: String, url: String, body: String, platform: PlatformType)
        case pullRequestEdited(title: String, url: String, body: String, platform: PlatformType)
        case pullRequestClosed(title: String, head: Branch, base: Branch, platform: PlatformType)
        case pullRequestLabeled(label: Label, head: Branch, base: Branch, platform: PlatformType)
        case changesRequested(url: String)
        case failedStatus(sha: String)
        case getPullRequest(url: String)
        case getStatus(sha: String, url: String)
        
        case getOpenPullRequests
        case markPullRequestStale(issueId: Int)
        
        // For testing purposes
        case testStatus(url: String)
        
        var title: String? {
            switch self {
            case .branchCreated(let t, _), .pullRequestClosed(let t, _, _, _), .pullRequestOpened(let t, _, _, _):
                return t
            default:
                return nil
            }
        }
        
        var platform: PlatformType? {
            switch self {
            case .branchCreated(_, let platform),.pullRequestClosed(_, _, _, let platform), .pullRequestOpened(_, _, _, let platform):
                return platform
            default:
                return nil
            }
        }
        
        var checkStale: Bool { false }
    }
}

extension Github.Payload: RequestModel {
    public typealias ResponseModel = Github.PayloadResponse
    
    public enum Config: String, Configuration {
        case githubSecret
    }
}

extension Github.Payload {
    // (1b) Incoming webhook to local request
    func type(headers: Headers?) -> Github.RequestType? {
        let event = headers?.get(Github.eventHeaderName).flatMap(Github.Event.init)
        let platform: Github.PlatformType
        switch Github.Url.Repository(rawValue: repository?.name ?? "N/A") {
        case .ios:
            platform = .iOS
        case .android:
            platform = .android
        case .none:
            platform = .iOS
        }
        
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
            return .pullRequestClosed(title: pr.title, head: pr.head, base: pr.base, platform: platform)
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
        case .failedStatus, .getPullRequest, .getStatus, .getOpenPullRequests, .testStatus: return .GET
        case .markPullRequestStale: return .POST
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
                
                return try? Service.encoder.encode(Body(body: new))
            } else {
                return nil
            }
        case .markPullRequestStale:
            struct Body: Encodable { let labels: [String] }
            
            return try? Service.encoder.encode(Body(labels: [Github.Label.stale.name]))
        default: return nil
        }
    }
    
    public func url(token: String) -> URL? {
        switch self.type {
        case let .changesRequested(url: url):
            return URL
                .init(string: url.replacingOccurrences(
                    of: "/\(Github.Path.pulls.rawValue)",
                    with: "/\(Github.Path.issues.rawValue)"
                ))?
                .appendingPathComponent(Github.Path.labels.rawValue)
                .appendingPathComponent(Github.Label.waitingForReview.name)
        case let .failedStatus(sha: sha):
            return Github.Url.search
                .appendingPathComponent(Github.Path.issues.rawValue)
                .appending(queryItems: [.init(
                    name: "q",
                    value: "\(sha)"
                        + "+label:\"\(Github.Label.waitingForReview.name)\""
                        + "+state:open"
                )])
        case let .pullRequestOpened(_, url: url, _, _),
             let .pullRequestEdited(_, url: url, _, _),
             let .getPullRequest(url: url):
            return URL(string: url)
        case let .getStatus(sha: sha, url: url):
            return URL(string: url)?
                .appendingPathComponent(Github.Path.commits.rawValue)
                .appendingPathComponent(sha)
                .appendingPathComponent(Github.Path.statuses.rawValue)
        case .getOpenPullRequests:
            return Github.Url.ios
                .appendingPathComponent(Github.Path.pulls.rawValue)
                .appending(queryItems: [
                    .init(name: "state", value: "open"),
                    .init(name: "per_page", value: "100")
                ])
        case let .markPullRequestStale(issueId):
            return Github.Url.ios
                .appendingPathComponent(Github.Path.issues.rawValue)
                .appendingPathComponent("\(issueId)")
                .appendingPathComponent(Github.Path.labels.rawValue)
        case let .testStatus(url):
            return URL(string: url)
        default: return nil
        }
    }

    public func headers(token: String) -> [(String, String)] {
        return [
            ("Authorization", "token \(token)"),
            ("Accept", "application/vnd.github+json"),
            ("X-GitHub-Api-Version", "2022-11-28"),
            ("User-Agent", "cci-imind")
        ]
    }
}

extension Github {
    
    static func check(_ from: Github.Payload,
                      _ body: String?,
                      _ headers: Headers?) -> Github.PayloadResponse? {
        guard !Environment.isDebugMode() else { return nil }
        
        let secret = Environment.get(Payload.Config.githubSecret)
        let signature = headers?.get(signatureHeaderName)
        return verify(body: body, secret: secret, signature: signature)
            ? nil
            : PayloadResponse(error: Error.signature)
    }

    // (1a) Core: incoming webhook
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
    
    // (2a) Core: action
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
                            do {
                                return try fetchRequest(token: $0, request: request, context: context)
                                    .clean()
                            } catch {
                                return leftIO(context)(PayloadResponse(error: Error.underlying(error)))
                            }
                        }
                } catch {
                    return leftIO(context)(PayloadResponse(error: Error.underlying(error)))
                }
            }
    }
    
    // (3) Core: response back
    static func responseToGithub(_ from: APIResponse) -> PayloadResponse {
        return PayloadResponse(value: from.message.map { $0 + " (\(from.errors ?? []))" })
    }
    
    static func fetchAccessToken(_ installationId: Int,
                                 _ context: Context) throws -> IO<String> {
        guard let appId = Environment.get(APIRequest.Config.githubAppId) else { throw Error.jwt }
        
        let jwtToken = context.next().makePromise(of: String.self)
        jwtToken.completeWithTask { try await jwt(appId: appId) }
        return jwtToken.futureResult
            .flatMapThrowingIO { jwtToken in
                try accessToken(jwtToken: jwtToken, installationId: installationId)
                    .flatMapThrowing { token in
                        guard let token = token else { throw Error.accessToken }
                        return token
                    }
            }
    }
    
    @Sendable
    static func reduce(_ responses: [PayloadResponse]) -> PayloadResponse {
        return responses
            .reduce(PayloadResponse()) { result, next in
                guard let value = next.value else {
                    return result
                }
                let response = (result.value.map { $0 + "\n" } ?? "") + value
                return PayloadResponse(value: response)
            }
    }
    
}

private extension Github {
    // (2b) Local: action
    static func fetchRequest(token: String, request: APIRequest, context: Context) throws -> TokenedIO<APIResponse?> {
        let instant = pure(Tokened<APIResponse?>(token, nil), context)
        let req: TokenedIO<APIResponse?>
        switch request.type {
        case .changesRequested:
            req = try Service.fetch(request, APIResponse.self, token, isDebugMode: Environment.isDebugMode())
        case .failedStatus:
            req = try Service.fetch(request, SearchResponse<SearchIssue>.self, token, isDebugMode: Environment.isDebugMode())
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
                req = instant
            } else {
                req = try Service.fetch(request, APIResponse.self, token, isDebugMode: Environment.isDebugMode())
            }
        case .testStatus:
            req = try Service.fetch(request, [Github.Status].self, token, isDebugMode: Environment.isDebugMode())
                .map { _ in Github.APIResponse(message: "success", errors: nil) }
        default:
            req = instant
        }
        
        return request.type.checkStale
            ? req.flatMapThrowingIO { result in try checkStalePullRequests(context, token, result) }
            : req
    }
}

// MARK: - Utility

private extension Github {
    private static let staleInterval: TimeInterval = 3 * 7 * 24 * 60 * 60 // 3 weeks
    
    static func checkStalePullRequests(
        _ context: Context,
        _ token: String,
        _ originalResult: Tokened<Github.APIResponse?>
    ) throws -> EventLoopFuture<Tokened<Github.APIResponse?>> {
        let now = Date()
        let request = Github.APIRequest(type: .getOpenPullRequests)
        return try Service.fetch(request, [Github.PullRequest].self, token, isDebugMode: Environment.isDebugMode())
            .flatMapThrowingIO { result in
                guard let pulls = result.value else {
                    return context.next().makeSucceededFuture(originalResult)
                }
                
                let tasks = try pulls
                    .compactMap { pull -> TokenedIO<[Github.Label]?>? in
                        guard
                            !pull.labels.contains(Github.Label.stale),
                            let updatedAt = pull.updatedAt,
                            now.timeIntervalSince(updatedAt) > Self.staleInterval
                        else { return nil }
                        
                        let request = Github.APIRequest(type: .markPullRequestStale(issueId: pull.issueId))
                        return try Service.fetch(request, [Github.Label].self, token, isDebugMode: Environment.isDebugMode())
                    }
                
                return EventLoopFuture.whenAllComplete(tasks, on: context.next())
                    .map { _ in originalResult }
            }
    }
}

extension TokenedIO where Value == Tokened<Github.APIResponse?> {
    func clean() -> EitherIO<Github.PayloadResponse, Github.APIResponse> {
        return map { $0.value }
            .flatMapErrorThrowing {
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
            .flatMapErrorThrowing { .left(Github.PayloadResponse(error: Github.Error.underlying($0))) }
    }
}
