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
    case decode
    case missingToken
    case badURL
    case underlying(Error)
    case noIssue
}

extension YoutrackError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .decode: return "Decode error"
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
        
        init(_ githubWebhookType: GithubWebhookType) {
            switch githubWebhookType {
            case .branch: self = .inProgress
            case .opened: self = .inReview
            case .closed: self = .waitingForDeploy
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
    typealias Config = YoutrackConfig
    
    public enum YoutrackConfig: String, Configuration {
        case youtrackToken
        case youtrackURL
    }

}

extension YoutrackRequest {
    static func githubWebhookRequest(_ from: GithubWebhookRequest) -> Either<GithubWebhookResponse, YoutrackRequest> {
        guard let (command, title) = YoutrackRequest.commandAndTitle(from) else {
            return .left(GithubWebhookResponse())
        }
        do {
            let regex = try NSRegularExpression(pattern: "4DM-[0-9]+")
            let datas = regex.matches(in: title, options: [], range: NSRange(title.startIndex..., in: title))
                .compactMap { Range($0.range, in: title).map { String(title[$0]) } }
                .map { RequestData(issue: $0, command: command) }
            return .right(YoutrackRequest(data: datas))
        } catch {
            return .left(GithubWebhookResponse(value: error.localizedDescription))
        }
    }
    
    static func apiWithGithubWebhook(_ context: Context)
        -> (Either<GithubWebhookResponse, YoutrackRequest>)
        -> EitherIO<GithubWebhookResponse, [YoutrackResponseContainer]> {
            let instantResponse: (GithubWebhookResponse)
                -> EitherIO<GithubWebhookResponse, [YoutrackResponseContainer]> = {
                pure(.left($0), context)
            }
            return {
                return $0.either(instantResponse) {
                    request -> EitherIO<GithubWebhookResponse, [YoutrackResponseContainer]> in
                    
                    guard let token = Environment.get(Config.youtrackToken) else {
                        return instantResponse(GithubWebhookResponse(error: YoutrackError.missingToken))
                    }
                    guard let string = Environment.get(Config.youtrackURL),
                        let url = URL(string: string),
                        let host = url.host else {
                            return instantResponse(GithubWebhookResponse(error: YoutrackError.badURL))
                    }
                    return request.data
                        .map(YoutrackRequest.fetch(context, url, host, token))
                        .flatten(on: context)
                        .map { results -> Either<GithubWebhookResponse, [YoutrackResponseContainer]> in
                            let initial: Either<GithubWebhookResponse, [YoutrackResponseContainer]> = .right([])
                            return results.reduce(initial, YoutrackRequest.flatten)
                        }
                }
            }
    }
    
    static func responseToGithubWebhook(_ from: [YoutrackResponseContainer]) -> GithubWebhookResponse {
        let value: String
        if from.isEmpty {
            value = YoutrackError.noIssue.localizedDescription
        } else {
            value = from.compactMap { $0.response.value }.joined(separator: "\n")
        }
        return GithubWebhookResponse(value: value)
    }
    
    private static func commandAndTitle(_ request: GithubWebhookRequest) -> (Command, String)? {
        guard let (githubWebhookType, title) = request.type else { return nil }
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
        -> EitherIO<GithubWebhookResponse, YoutrackResponseContainer> {
            
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
                .map { response -> Either<GithubWebhookResponse, YoutrackResponseContainer> in
                    let decode: (Data) throws -> YoutrackResponse = { data in
                        return try JSONDecoder().decode(YoutrackResponse.self, from: data)
                    }
                    guard let youtrackResponse = try response.body.data.map(decode) else {
                        throw YoutrackError.decode
                    }
                    return .right(YoutrackResponseContainer(response: youtrackResponse, data: requestData))
                }
                .catchMap {
                    return .left(
                        GithubWebhookResponse(
                            value: "issue: \(requestData.issue): " +
                                "\(YoutrackError.underlying($0).localizedDescription)"))
                }
        }
    }

    private static func flatten(_ lhs: Either<GithubWebhookResponse, [YoutrackResponseContainer]>,
                                _ rhs: Either<GithubWebhookResponse, YoutrackResponseContainer>)
        -> Either<GithubWebhookResponse, [YoutrackResponseContainer]> {
            
        switch (lhs, rhs) {
        case let (.left(lresult), .left(lnext)):
            let value = (lresult.value ?? "") + "\n" + (lnext.value ?? "" )
            return .left(GithubWebhookResponse(value: value))
        case let (.left(lresult), .right):
            return .left(GithubWebhookResponse(value: lresult.value))
        case let (.right(rresults), .right(rnext)):
            return .right(rresults + [rnext])
        case let (.right, .left(lnext)):
            return .left(GithubWebhookResponse(value: lnext.value))
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
