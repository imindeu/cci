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

extension SlackRequest: RequestModel {
    public typealias ResponseModel = SlackResponse
    public typealias Config = SlackConfig
    
    public enum SlackConfig: String, Configuration {
        case slackToken
    }
    
    public var responseURL: URL? { return URL(string: responseUrlString) }
}

extension SlackRequest {
    static func check(_ from: SlackRequest) -> SlackResponse? {
        var texts: [String] = []
        let token = Environment.get(Config.slackToken)
        if token == nil || from.token != token! {
            texts.append("token")
        }
        if from.responseURL == nil {
            texts.append("response_url")
        }
        guard texts.count > 0 else { return nil }
        return SlackResponse.error(text: "Error: bad \(texts.joined(separator: ", "))")
    }
    static func api(_ request: SlackRequest, _ context: Context) -> (SlackResponse) -> IO<Void> {
        return { response in
            guard let url = request.responseURL, let hostname = url.host, let body = try? JSONEncoder().encode(response) else {
                return Environment.emptyApi(context).map { _ in () }
            }
            let returnAPI = Environment
                .api(hostname, url.port)
            let request = HTTPRequest.init(method: .POST,
                                           url: url.path,
                                           headers: HTTPHeaders([("Content-Type", "application/json")]),
                                           body: HTTPBody(data: body))
            return returnAPI(context, request).map { _ in () }
        }
    }
    static func instant(_ context: Context) -> (SlackRequest) -> IO<SlackResponse> {
        return const(pure(SlackResponse.instant, context))
    }
}

extension SlackResponse {
    static var instant: SlackResponse {
        return SlackResponse(responseType: .ephemeral,
                             text: "",
                             attachments: [],
                             mrkdwn: false)
    }
}

extension SlackResponse {
    static func error(text: String, helpResponse: SlackResponse? = nil) -> SlackResponse {
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
