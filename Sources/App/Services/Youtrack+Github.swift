//
//  Youtrack+Github.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 07..
//

import APIConnect
import APIModels

import Foundation

extension Youtrack {
    enum Error: LocalizedError {
        case decode(String)
        case missingToken
        case badURL
        case underlying(Swift.Error)
        case noIssue
        
        public var errorDescription: String? {
            switch self {
            case .decode(let body): return "Decode error (\(body))"
            case .missingToken: return "Missing youtrack token"
            case .badURL: return "Bad youtrack URL"
            case .underlying(let error):
                if let localizedError = error as? LocalizedError {
                    return localizedError.localizedDescription
                }
                return "Unknown error (\(error))"
                
            case .noIssue: return "No youtrack issue found"
            }
        }
    }
    
    struct Request: Equatable, Codable {
        enum Command: String, Equatable, Codable {
            case inProgress = "4DM%20iOS%20state%20In%20Progress"
            case inReview = "4DM%20iOS%20state%20In%20Review"
            case waitingForDeploy = "4DM%20iOS%20state%20Waiting%20for%20deploy"
            
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

extension Youtrack {
    static func githubRequest(_ from: Github.Payload,
                              _ headers: Headers?) -> Either<Github.PayloadResponse, Request> {
        guard let type = from.type(headers: headers),
            let command = Request.Command(type),
            let title = type.title else {
                return .left(Github.PayloadResponse())
        }
        do {
            let datas = try issues(from: title)
                .map { Request.RequestData(issue: $0, command: command) }
            return .right(Request(data: datas))
        } catch {
            return .left(Github.PayloadResponse(value: error.localizedDescription))
        }
    }
    
    static func apiWithGithub(_ context: Context)
        -> (Request)
        -> EitherIO<Github.PayloadResponse, [ResponseContainer]> {
            return { request -> EitherIO<Github.PayloadResponse, [ResponseContainer]> in
                guard let token = Environment.get(Request.Config.youtrackToken) else {
                    return leftIO(context)(Github.PayloadResponse(error: Error.missingToken))
                }
                guard let string = Environment.get(Request.Config.youtrackURL),
                    let url = URL(string: string),
                    let host = url.host else {
                        return leftIO(context)(Github.PayloadResponse(error: Error.badURL))
                }
                return request.data
                    .map(fetch(context, url, host, token, Environment.api))
                    .flatten(on: context)
                    .map { results -> Either<Github.PayloadResponse, [ResponseContainer]> in
                        let initial: Either<Github.PayloadResponse, [ResponseContainer]> = .right([])
                        return results.reduce(initial, flatten)
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
    
    private static func flatten(_ lhs: Either<Github.PayloadResponse, [ResponseContainer]>,
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
