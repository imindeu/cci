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

enum YoutrackError: Error {
    case decode(String)
    case missingToken
    case badURL
    case underlying(Error)
    case noIssue
}

extension YoutrackError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .decode(let body): return "Decode error (\(body))"
        case .missingToken: return "Missing youtrack token"
        case .badURL: return "Bad youtrack URL"
        case .underlying(let error):
            if let youtrackError = error as? YoutrackError {
                return youtrackError.localizedDescription
            }
            return "Unknown error (\(error))"

        case .noIssue: return "No youtrack issue found"
        }
    }
}
struct YoutrackRequest: Equatable, Codable {
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

extension YoutrackRequest: RequestModel {
    typealias ResponseModel = [YoutrackResponseContainer]
    
    public enum Config: String, Configuration {
        case youtrackToken
        case youtrackURL
    }

}

extension YoutrackRequest {
    static func githubWebhookRequest(_ from: GithubWebhook.Request,
                                     _ headers: Headers?) -> Either<GithubWebhook.Response, YoutrackRequest> {
        guard let (command, title) = YoutrackRequest.commandAndTitle(from, headers) else {
            return .left(GithubWebhook.Response())
        }
        do {
            let regex = try NSRegularExpression(pattern: "4DM-[0-9]+")
            let datas = regex.matches(in: title, options: [], range: NSRange(title.startIndex..., in: title))
                .compactMap { Range($0.range, in: title).map { String(title[$0]) } }
                .map { RequestData(issue: $0, command: command) }
            return .right(YoutrackRequest(data: datas))
        } catch {
            return .left(GithubWebhook.Response(value: error.localizedDescription))
        }
    }
    
    static func apiWithGithubWebhook(_ context: Context)
        -> (Either<GithubWebhook.Response, YoutrackRequest>)
        -> EitherIO<GithubWebhook.Response, [YoutrackResponseContainer]> {
            let instantResponse: (GithubWebhook.Response)
                -> EitherIO<GithubWebhook.Response, [YoutrackResponseContainer]> = {
                pure(.left($0), context)
            }
            return {
                return $0.either(instantResponse) {
                    request -> EitherIO<GithubWebhook.Response, [YoutrackResponseContainer]> in
                    
                    guard let token = Environment.get(Config.youtrackToken) else {
                        return instantResponse(GithubWebhook.Response(error: YoutrackError.missingToken))
                    }
                    guard let string = Environment.get(Config.youtrackURL),
                        let url = URL(string: string),
                        let host = url.host else {
                            return instantResponse(GithubWebhook.Response(error: YoutrackError.badURL))
                    }
                    return request.data
                        .map(YoutrackRequest.fetch(context, url, host, token))
                        .flatten(on: context)
                        .map { results -> Either<GithubWebhook.Response, [YoutrackResponseContainer]> in
                            let initial: Either<GithubWebhook.Response, [YoutrackResponseContainer]> = .right([])
                            return results.reduce(initial, YoutrackRequest.flatten)
                        }
                }
            }
    }
    
    static func responseToGithubWebhook(_ from: [YoutrackResponseContainer]) -> GithubWebhook.Response {
        let value: String
        if from.isEmpty {
            value = YoutrackError.noIssue.localizedDescription
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
        -> EitherIO<GithubWebhook.Response, YoutrackResponseContainer> {
            
        return { requestData in
            var httpRequest = HTTPRequest()
            httpRequest.method = .POST
            httpRequest.urlString = YoutrackRequest.path(base: url.path,
                                                         issue: requestData.issue,
                                                         command: requestData.command)
            httpRequest.headers = HTTPHeaders([
                ("Accept", "application/json"),
                ("Content-Type", "application/json"),
                ("Authorization", "Bearer \(token)")
            ])
            return Environment.api(host, url.port)(context, httpRequest)
                .map { response -> Either<GithubWebhook.Response, YoutrackResponseContainer> in
                    guard let responseData = response.body.data else {
                        let youtrackResponse = YoutrackResponse(value: "issue: \(requestData.issue)")
                        return .right(YoutrackResponseContainer(response: youtrackResponse,
                                                                data: requestData))
                    }
                    let youtrackResponse = try JSONDecoder().decode(YoutrackResponse.self, from: responseData)
                    return .right(YoutrackResponseContainer(response: youtrackResponse, data: requestData))
                }
                .catchMap {
                    return .left(
                        GithubWebhook.Response(
                            value: "issue: \(requestData.issue): " +
                                "\(YoutrackError.underlying($0).localizedDescription)"))
                }
        }
    }

    private static func flatten(_ lhs: Either<GithubWebhook.Response, [YoutrackResponseContainer]>,
                                _ rhs: Either<GithubWebhook.Response, YoutrackResponseContainer>)
        -> Either<GithubWebhook.Response, [YoutrackResponseContainer]> {
            
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

struct YoutrackResponseContainer: Equatable, Codable {
    let response: YoutrackResponse
    let data: YoutrackRequest.RequestData
}

struct YoutrackResponse: Equatable, Codable {
    let value: String?
    
    init (value: String? = nil) {
        self.value = value
    }
}
