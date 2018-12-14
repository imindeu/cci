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

enum Youtrack {
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
            
            init(_ githubWebhookType: GithubWebhook.RequestType) {
                switch githubWebhookType {
                case .branchCreated: self = .inProgress
                case .pullRequestOpened: self = .inReview
                case .pullRequestClosed: self = .waitingForDeploy
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
    
    struct Response: Equatable, Codable {
        let value: String?
        
        init (value: String? = nil) {
            self.value = value
        }
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
    static func githubWebhookRequest(_ from: GithubWebhook.Request,
                                     _ headers: Headers?) -> Either<GithubWebhook.Response, Youtrack.Request> {
        guard let (command, title) = Youtrack.commandAndTitle(from, headers) else {
            return .left(GithubWebhook.Response())
        }
        do {
            let regex = try NSRegularExpression(pattern: "4DM-[0-9]+")
            let datas = regex.matches(in: title, options: [], range: NSRange(title.startIndex..., in: title))
                .compactMap { Range($0.range, in: title).map { String(title[$0]) } }
                .map { RequestData(issue: $0, command: command) }
            return .right(Request(data: datas))
        } catch {
            return .left(GithubWebhook.Response(value: error.localizedDescription))
        }
    }
    
    static func apiWithGithubWebhook(_ context: Context)
        -> (Either<GithubWebhook.Response, Youtrack.Request>)
        -> EitherIO<GithubWebhook.Response, [Youtrack.ResponseContainer]> {
            let instantResponse: (GithubWebhook.Response)
                -> EitherIO<GithubWebhook.Response, [ResponseContainer]> = {
                pure(.left($0), context)
            }
            return {
                return $0.either(instantResponse) {
                    request -> EitherIO<GithubWebhook.Response, [ResponseContainer]> in
                    
                    guard let token = Environment.get(Config.youtrackToken) else {
                        return instantResponse(GithubWebhook.Response(error: Youtrack.Error.missingToken))
                    }
                    guard let string = Environment.get(Config.youtrackURL),
                        let url = URL(string: string),
                        let host = url.host else {
                            return instantResponse(GithubWebhook.Response(error: Youtrack.Error.badURL))
                    }
                    return request.data
                        .map(Youtrack.fetch(context, url, host, token))
                        .flatten(on: context)
                        .map { results -> Either<GithubWebhook.Response, [ResponseContainer]> in
                            let initial: Either<GithubWebhook.Response, [ResponseContainer]> = .right([])
                            return results.reduce(initial, Youtrack.flatten)
                        }
                }
            }
    }
    
    static func responseToGithubWebhook(_ from: [Youtrack.ResponseContainer]) -> GithubWebhook.Response {
        let value: String
        if from.isEmpty {
            value = Youtrack.Error.noIssue.localizedDescription
        } else {
            value = from.compactMap { $0.response.value }.joined(separator: "\n")
        }
        return GithubWebhook.Response(value: value)
    }
    
    private static func commandAndTitle(_ request: GithubWebhook.Request, _ headers: Headers?) -> (Command, String)? {
        guard let (githubWebhookType, title) = request.type(headers: headers) else { return nil }
        return (Command(githubWebhookType), title)
    }
    
    private static func path(base: String, issue: String, command: Command) -> String {
        return "\(base)/issue/\(issue)/execute?command=\(command.rawValue)"
    }
    
    private static func fetch(_ context: Context,
                              _ url: URL,
                              _ host: String,
                              _ token: String)
        -> (RequestData)
        -> EitherIO<GithubWebhook.Response, ResponseContainer> {
            
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
                .map { response -> Either<GithubWebhook.Response, ResponseContainer> in
                    guard let responseData = response.body.data else {
                        let youtrackResponse = Response(value: "issue: \(requestData.issue)")
                        return .right(ResponseContainer(response: youtrackResponse,
                                                        data: requestData))
                    }
                    let youtrackResponse = try JSONDecoder().decode(Response.self, from: responseData)
                    return .right(ResponseContainer(response: youtrackResponse, data: requestData))
                }
                .catchMap {
                    return .left(
                        GithubWebhook.Response(
                            value: "issue: \(requestData.issue): " +
                                "\(Youtrack.Error.underlying($0).localizedDescription)"))
                }
        }
    }

    private static func flatten(_ lhs: Either<GithubWebhook.Response, [ResponseContainer]>,
                                _ rhs: Either<GithubWebhook.Response, ResponseContainer>)
        -> Either<GithubWebhook.Response, [ResponseContainer]> {
            
        switch (lhs, rhs) {
        case let (.left(lresult), .left(lnext)):
            let value = (lresult.value ?? "") + "\n" + (lnext.value ?? "" )
            return .left(GithubWebhook.Response(value: value))
        case let (.left(lresult), .right):
            return .left(GithubWebhook.Response(value: lresult.value))
        case let (.right(rresults), .right(rnext)):
            return .right(rresults + [rnext])
        case let (.right, .left(lnext)):
            return .left(GithubWebhook.Response(value: lnext.value))
        }
    }
}
