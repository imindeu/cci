//
//  Slack.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//
import APIConnect
import Foundation
import HTTP

struct SlackRequest: RequestModel, Decodable {
    typealias ResponseModel = SlackResponse
    typealias Config = SlackConfig
    
    enum SlackConfig: String, Configuration {
        case slackToken
    }
    
    let token: String
    let team_id: String
    let team_domain: String
    let enterprise_id: String?
    let enterprise_name: String?
    let channel_id: String
    let channel_name: String
    let user_id: String
    let user_name: String
    let command: String
    let text: String
    let response_url: String
    let trigger_id: String
    
    var responseURL: URL? { return URL(string: response_url) }
}

extension SlackRequest {
    static func check(_ from: SlackRequest) -> SlackResponse? {
        guard URL(string: from.response_url) != nil else {
            return SlackResponse.error(text: "Error: bad response_url")
        }
        return nil
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
        return const(pure(SlackResponse(response_type: .ephemeral, text: nil, attachments: [], mrkdwn: false), context))
    }
}

struct SlackResponse: Equatable, Encodable {
    enum ResponseType: String, Encodable {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    let response_type: ResponseType
    let text: String?
    var attachments: [Attachment]
    let mrkdwn: Bool?
    
    struct Attachment: Equatable, Encodable {
        let fallback: String?
        let text: String?
        let color: String?
        let mrkdwn_in: [String]
        let fields: [Field]
    }
    
    struct Field: Equatable, Encodable {
        let title: String?
        let value: String?
        let short: Bool?
    }
}

extension SlackResponse.Field: Decodable {}
extension SlackResponse.Attachment: Decodable {}
extension SlackResponse.ResponseType: Decodable {}
extension SlackResponse: Decodable {}

extension SlackResponse {
    static func error(text: String, helpResponse: SlackResponse? = nil) -> SlackResponse {
        let attachment = SlackResponse.Attachment(fallback: text, text: text, color: "danger", mrkdwn_in: [], fields: [])
        guard let helpResponse = helpResponse else {
            return SlackResponse(response_type: .ephemeral, text: nil, attachments: [attachment], mrkdwn: true)
        }
        var copy = helpResponse
        let attachments = copy.attachments
        copy.attachments = [attachment] + attachments
        return copy
    }
}
