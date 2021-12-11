//
//  Youtrack+Github.swift
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

import enum HTTP.HTTPMethod

extension Youtrack {
    enum Error: LocalizedError {
        case decode(String)
        case missingToken
        case badURL
        case noIssue
        case underlying(Swift.Error)
        
        public var errorDescription: String? {
            switch self {
            case .decode(let body): return "Decode error (\(body))"
            case .missingToken: return "Missing youtrack token"
            case .badURL: return "Bad youtrack URL"
            case .noIssue: return "No youtrack issue found"
            case .underlying(let error):
                return (error as? LocalizedError).map { $0.localizedDescription } ?? "Unknown error (\(error))"
            }
        }
    }
    
    struct Request: Equatable, Codable {
        enum Command: String, Equatable, Codable {
            case inProgress = "4DM iOS state In Progress"
            case inReview = "4DM iOS state In Review"
            case waitingForDeploy = "4DM iOS state Waiting for deploy"
            
            init?(_ githubWebhookType: Github.RequestType) {
                switch githubWebhookType {
                case .branchCreated: self = .inProgress
                case .pullRequestOpened: self = .inReview
                case .pullRequestClosed: self = .waitingForDeploy
                default: return nil
                }
            }
        }
        
        struct RequestData: Equatable, Codable {
            let issue: String
            let command: Command
        }
        
        let data: [RequestData]
    }
    
    struct ResponseContainer: Equatable, Codable {
        let response: Response
        let data: Request.RequestData
    }
    
}

extension Youtrack.Request: RequestModel {
    typealias ResponseModel = [Youtrack.ResponseContainer]
    
    public enum Config: String, Configuration {
        case youtrackToken
        case youtrackURL
    }
}

extension Youtrack.Request.RequestData: TokenRequestable {
    var method: HTTPMethod? {
        return .POST
    }
    
    var body: Data? {
        return "{\"query\": \"\(command.rawValue)\", \"issues\": [ { \"idReadable\": \"\(issue)\" } ] }"
            .data(using: .utf8)
    }
    
    func url(token: String) -> URL? {
        guard let string = Environment.get(Youtrack.Request.Config.youtrackURL),
            let base = URL(string: string)?.absoluteString else {
                return nil
        }
        return URL(string: Youtrack.path(base: base, issue: issue, command: command))
    }
    
    func headers(token: String) -> [(String, String)] {
        return [
            ("Accept", "application/json"),
            ("Content-Type", "application/json"),
            ("Authorization", "Bearer \(token)")
        ]
    }
    
}

extension Youtrack {
    static func githubRequest(_ from: Github.Payload,
                              _ headers: Headers?,
                              _ context: Context) -> EitherIO<Github.PayloadResponse, Request> {
        guard let type = from.type(headers: headers),
            let command = Request.Command(type),
            let title = type.title else {
                return leftIO(context)(Github.PayloadResponse())
        }
        do {
            let datas = try issues(from: title, pattern: "4DM-[0-9]+")
                .map { Request.RequestData(issue: $0, command: command) }
            return rightIO(context)(Request(data: datas))
        } catch {
            return leftIO(context)(Github.PayloadResponse(value: error.localizedDescription))
        }
    }
    
    static func apiWithGithub(_ context: Context)
        -> (Request)
        -> EitherIO<Github.PayloadResponse, [ResponseContainer]> {
            return { request -> EitherIO<Github.PayloadResponse, [ResponseContainer]> in
                guard let token = Environment.get(Request.Config.youtrackToken) else {
                    return leftIO(context)(Github.PayloadResponse(error: Error.missingToken))
                }
                do {
                    return try request.data
                        .map(fetch(context, token, Environment.api))
                        .flatten(on: context)
                        .map { results -> Either<Github.PayloadResponse, [ResponseContainer]> in
                            let initial: Either<Github.PayloadResponse, [ResponseContainer]> = .right([])
                            return results.reduce(initial, flatten)
                        }
                } catch {
                    return leftIO(context)(Github.PayloadResponse(error: Error.underlying(error)))
                }
            }
    }
    
    static func responseToGithub(_ from: [ResponseContainer]) -> Github.PayloadResponse {
        let value: String
        if from.isEmpty {
            value = Error.noIssue.localizedDescription
        } else {
            value = from.compactMap { $0.response.value }.joined(separator: "\n")
        }
        return Github.PayloadResponse(value: value)
    }
}

private extension Youtrack {
    
    static func path(base: String, issue: String, command: Request.Command) -> String {
        if base.hasSuffix("/") {
            return "\(base)commands"
        }
        return "\(base)/commands"
    }

    static func fetch(_ context: Context,
                      _ token: String,
                      _ api: @escaping API)
        -> (Request.RequestData) throws
        -> EitherIO<Github.PayloadResponse, ResponseContainer> {
            
            return { data in
                try Service.fetch(data, Response.self, token, context, Environment.api, isDebugMode: Environment.isDebugMode())
                    .map { response in
                        let youtrackResponse = response.value ?? Response(value: "issue: \(data.issue)")
                        return .right(ResponseContainer(response: youtrackResponse, data: data))
                    }
                    .catchMap {
                        return .left(
                            Github.PayloadResponse(
                                value: "issue: \(data.issue): " +
                                "\(Error.underlying($0).localizedDescription)"))
                    }
            }
    }

    static func flatten(_ lhs: Either<Github.PayloadResponse, [ResponseContainer]>,
                        _ rhs: Either<Github.PayloadResponse, ResponseContainer>)
        -> Either<Github.PayloadResponse, [ResponseContainer]> {
            
            switch (lhs, rhs) {
            case let (.left(lresult), .left(lnext)):
                let value = (lresult.value ?? "") + "\n" + (lnext.value ?? "" )
                return .left(Github.PayloadResponse(value: value))
            case let (.left(lresult), .right):
                return .left(Github.PayloadResponse(value: lresult.value))
            case let (.right(rresults), .right(rnext)):
                return .right(rresults + [rnext])
            case let (.right, .left(lnext)):
                return .left(Github.PayloadResponse(value: lnext.value))
            }
    }

}
