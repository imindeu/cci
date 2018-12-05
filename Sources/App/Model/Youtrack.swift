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
    case underlying(Error)
}

extension YoutrackError {
    var text: String {
        switch self {
        case .decode: return "Decode error"
        case .underlying(let error):
            if let youtrackError = error as? YoutrackError {
                return youtrackError.text
            }
            return "Unknown error (\(error))"

        }
    }
}
struct YoutrackRequest: Equatable, Codable {
    enum Command: String, Equatable, Codable {
        case inProgress = "4DM%20iOS%20state%20In%20Progress"
        case inReview = "4DM%20iOS%20state%20In%20Review"
        case waitingForDeploy = "4DM%20iOS%20state%20Waiting%20for%20deploy"
    }
    
    let issue: String
    let command: Command
}

extension YoutrackRequest: RequestModel {
    typealias ResponseModel = YoutrackResponseContainer
    typealias Config = YoutrackConfig
    
    public enum YoutrackConfig: String, Configuration {
        case youtrackToken
        case youtrackURL
    }

}

extension YoutrackRequest {
    static func githubWebhookRequest(_ from: GithubWebhookRequest) -> Either<GithubWebhookResponse, [YoutrackRequest]> {
           guard let (command, title) = from.youtrackData else {
            return .left(GithubWebhookResponse())
        }
        do {
            let regex = try NSRegularExpression(pattern: "4DM-[0-9]+")
            let requests = regex.matches(in: title, options: [], range: NSRange(title.startIndex..., in: title))
                .compactMap { Range($0.range, in: title).map { String(title[$0]) } }
                .map { YoutrackRequest(issue: $0, command: command) }
            return .right(requests)
        } catch {
            return .left(GithubWebhookResponse(failure: error.localizedDescription))
        }
    }
    
    static func apiWithGithubWebhook(_ context: Context)
        -> (Either<GithubWebhookResponse, [YoutrackRequest]>)
        -> EitherIO<GithubWebhookResponse, [YoutrackResponseContainer]> {
            let instantResponse: (GithubWebhookResponse)
                -> EitherIO<GithubWebhookResponse, [YoutrackResponseContainer]> = {
                pure(.left($0), context)
            }
            return {
                return $0.either(instantResponse) {
                    requests -> EitherIO<GithubWebhookResponse, [YoutrackResponseContainer]> in
                    
                    guard let token = Environment.get(Config.youtrackToken) else {
                        return instantResponse(GithubWebhookResponse(failure: "missing youtrack token"))
                    }
                    guard let string = Environment.get(Config.youtrackURL),
                        let url = URL(string: string),
                        let host = url.host else {
                            return instantResponse(GithubWebhookResponse(failure: "bad youtrack url"))
                    }
                    return requests.map(YoutrackRequest.fetch(context, url, host, token))
                    .flatten(on: context)
                    .map { results -> Either<GithubWebhookResponse, [YoutrackResponseContainer]> in
                        let initial: Either<GithubWebhookResponse, [YoutrackResponseContainer]> = .right([])
                        return results.reduce(initial, YoutrackRequest.flatten)
                    }
                    
                }
            }
    }
    
    static func responseToGithubWebhook(_ from: [YoutrackResponseContainer]) -> GithubWebhookResponse {
        return GithubWebhookResponse()
    }
    
    private static func path(base: String, issue: String, command: Command) -> String {
        return "\(base)/issue/\(issue)/execute?command=\(command.rawValue)"
    }
    
    private static func fetch(_ context: Context,
                              _ url: URL,
                              _ host: String,
                              _ token: String)
        -> (_ request: YoutrackRequest)
        -> EitherIO<GithubWebhookResponse, YoutrackResponseContainer> {
            
        return { request in
            var httpRequest = HTTPRequest()
            httpRequest.method = .POST
            httpRequest.urlString = YoutrackRequest.path(base: url.path, issue: request.issue, command: request.command)
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
                    return .right(YoutrackResponseContainer(response: youtrackResponse, request: request))
                }
                .catchMap {
                    return .left(
                        GithubWebhookResponse(failure: "issue: \(request.issue): \(YoutrackError.underlying($0).text)")
                    )
                }
        }
    }

    private static func flatten(_ lhs: Either<GithubWebhookResponse, [YoutrackResponseContainer]>,
                                _ rhs: Either<GithubWebhookResponse, YoutrackResponseContainer>)
        -> Either<GithubWebhookResponse, [YoutrackResponseContainer]> {
            
        switch (lhs, rhs) {
        case let (.left(lresult), .left(lnext)):
            let failure = (lresult.failure ?? "") + "\n" + (lnext.failure ?? "" )
            return .left(GithubWebhookResponse(failure: failure))
        case let (.left(lresult), .right):
            return .left(GithubWebhookResponse(failure: lresult.failure))
        case let (.right(rresults), .right(rnext)):
            return .right(rresults + [rnext])
        case let (.right, .left(lnext)):
            return .left(GithubWebhookResponse(failure: lnext.failure))
        }
    }
}

private extension GithubWebhookRequest {
    var youtrackData: (YoutrackRequest.Command, String)? {
        switch (action, pullRequest?.title, ref, refType) {
        case let ("closed", .some(title), _, _):
            return (.waitingForDeploy, title)
        case let ("opened", .some(title), _, _):
            return (.inReview, title)
        case let (_, _, .some(title), "branch"):
            return (.inProgress, title)
        default:
            return nil
        }
    }
}

struct YoutrackResponseContainer: Equatable, Codable {
    let response: YoutrackResponse
    let request: YoutrackRequest
}

struct YoutrackResponse: Equatable, Codable {
    let value: String?
    
    init (value: String? = nil) {
        self.value = value
    }
}
