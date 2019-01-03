//
//  Youtrack.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//
import APIConnect
import APIModels
import Foundation
import HTTP
import Core

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
        let response: Youtrack.Response
        let data: Youtrack.Request.RequestData
    }

}

extension Request: RequestModel {
    typealias ResponseModel = [Youtrack.ResponseContainer]
    
    public enum Config: String, Configuration {
        case youtrackToken
        case youtrackURL
    }

}

private typealias Request = Youtrack.Request
private typealias Config = Youtrack.Request.Config
private typealias Command = Youtrack.Request.Command
private typealias RequestData = Youtrack.Request.RequestData
private typealias Response = Youtrack.Response
private typealias ResponseContainer = Youtrack.ResponseContainer

extension Youtrack {
    static func githubRequest(_ from: Github.Payload,
                              _ headers: Headers?) -> Either<Github.PayloadResponse, Youtrack.Request> {
        guard let (command, title) = Youtrack.commandAndTitle(from, headers) else {
            return .left(Github.PayloadResponse())
        }
        do {
            let regex = try NSRegularExpression(pattern: "4DM-[0-9]+")
            let datas = regex.matches(in: title, options: [], range: NSRange(title.startIndex..., in: title))
                .compactMap { Range($0.range, in: title).map { String(title[$0]) } }
                .map { RequestData(issue: $0, command: command) }
            return .right(Request(data: datas))
        } catch {
            return .left(Github.PayloadResponse(value: error.localizedDescription))
        }
    }
    
    static func apiWithGithub(_ context: Context)
        -> (Either<Github.PayloadResponse, Youtrack.Request>)
        -> EitherIO<Github.PayloadResponse, [Youtrack.ResponseContainer]> {
            let instantResponse: (Github.PayloadResponse)
                -> EitherIO<Github.PayloadResponse, [ResponseContainer]> = {
                pure(.left($0), context)
            }
            return {
                return $0.either(instantResponse) {
                    request -> EitherIO<Github.PayloadResponse, [ResponseContainer]> in
                    
                    guard let token = Environment.get(Config.youtrackToken) else {
                        return instantResponse(Github.PayloadResponse(error: Youtrack.Error.missingToken))
                    }
                    guard let string = Environment.get(Config.youtrackURL),
                        let url = URL(string: string),
                        let host = url.host else {
                            return instantResponse(Github.PayloadResponse(error: Youtrack.Error.badURL))
                    }
                    return request.data
                        .map(Youtrack.fetch(context, url, host, token))
                        .flatten(on: context)
                        .map { results -> Either<Github.PayloadResponse, [ResponseContainer]> in
                            let initial: Either<Github.PayloadResponse, [ResponseContainer]> = .right([])
                            return results.reduce(initial, Youtrack.flatten)
                        }
                }
            }
    }
    
    static func responseToGithub(_ from: [Youtrack.ResponseContainer]) -> Github.PayloadResponse {
        let value: String
        if from.isEmpty {
            value = Youtrack.Error.noIssue.localizedDescription
        } else {
            value = from.compactMap { $0.response.value }.joined(separator: "\n")
        }
        return Github.PayloadResponse(value: value)
    }
    
    private static func commandAndTitle(_ request: Github.Payload, _ headers: Headers?) -> (Command, String)? {
        guard let type = request.type(headers: headers),
            let command = Command(type),
            let title = type.title else { return nil }
        return (command, title)
    }
    
    private static func path(base: String, issue: String, command: Command) -> String {
        return "\(base)/issue/\(issue)/execute?command=\(command.rawValue)"
    }
    
    private static func fetch(_ context: Context,
                              _ url: URL,
                              _ host: String,
                              _ token: String)
        -> (RequestData)
        -> EitherIO<Github.PayloadResponse, ResponseContainer> {
            
        return { requestData in
            var httpRequest = HTTPRequest()
            httpRequest.method = .POST
            httpRequest.urlString = Youtrack.path(base: url.path,
                                                  issue: requestData.issue,
                                                  command: requestData.command)
            httpRequest.headers = HTTPHeaders([
                ("Accept", "application/json"),
                ("Content-Type", "application/json"),
                ("Authorization", "Bearer \(token)")
            ])
            return Environment.api(host, url.port)(context, httpRequest)
                .decode(Response.self)
                .map { response in
                    let youtrackResponse = response ?? Response(value: "issue: \(requestData.issue)")
                    return .right(ResponseContainer(response: youtrackResponse, data: requestData))
                }
                .catchMap {
                    return .left(
                        Github.PayloadResponse(
                            value: "issue: \(requestData.issue): " +
                                "\(Youtrack.Error.underlying($0).localizedDescription)"))
                }
        }
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
