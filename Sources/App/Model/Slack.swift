//
//  Slack.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//
import APIConnect
import APIModels
import Foundation
import HTTP

enum SlackError: Error {
    case badToken
    case missingResponseURL
    case combined([SlackError])
}

extension SlackError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .badToken: return "Bad slack token"
        case .missingResponseURL: return "Missing slack token"
        case .combined(let errors):
            return errors.map { $0.localizedDescription }.joined(separator: ", ")
        }
    }
}

extension SlackRequest: DelayedRequestModel {
    public typealias ResponseModel = SlackResponse
    public typealias Config = SlackConfig
    
    public enum SlackConfig: String, Configuration {
        case slackToken
    }
    
    public var responseURL: URL? { return URL(string: responseUrlString) }
}

extension SlackRequest {
    static func check(_ from: SlackRequest, _ payload: String? = nil, _ headers: Headers? = nil) -> SlackResponse? {
        var errors: [SlackError] = []
        let token = Environment.get(Config.slackToken)
        if token == nil || from.token != token! {
            errors.append(.badToken)
        }
        if from.responseURL == nil {
            errors.append(.missingResponseURL)
        }
        guard !errors.isEmpty else { return nil }
        return SlackResponse.error(SlackError.combined(errors))
    }
    static func api(_ request: SlackRequest, _ context: Context) -> (SlackResponse) -> IO<Void> {
        return { response in
            guard let url = request.responseURL,
                let hostname = url.host,
                let body = try? JSONEncoder().encode(response) else {
                    
                return Environment.emptyApi(context).map { _ in () }
            }
            let returnAPI = Environment
                .api(hostname, url.port)
            let request = HTTPRequest(method: .POST,
                                      url: url.path,
                                      headers: HTTPHeaders([("Content-Type", "application/json")]),
                                      body: HTTPBody(data: body))
            return returnAPI(context, request).map { _ in () }
        }
    }
    static func instant(_ context: Context) -> (SlackRequest) -> IO<SlackResponse?> {
        return const(pure(SlackResponse.instant, context))
    }
}

extension SlackResponse {
    static var instant: SlackResponse? {
        return nil
    }
}

extension SlackResponse {
    static func error(_ error: LocalizedError, helpResponse: SlackResponse? = nil) -> SlackResponse {
        let text = error.localizedDescription
        let attachment = SlackResponse.Attachment(fallback: text, text: text, color: "danger", mrkdwnIn: [], fields: [])
        guard let helpResponse = helpResponse else {
            return SlackResponse(responseType: .ephemeral, text: nil, attachments: [attachment], mrkdwn: true)
        }
        var copy = helpResponse
        let attachments = copy.attachments
        copy.attachments = [attachment] + attachments
        return copy
    }
    
}
