//
//  Slack.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//
import APIConnect
import Foundation
import HTTP

struct SlackRequest: Codable {
    let token: String
    let teamId: String
    let teamDomain: String
    let enterpriseId: String?
    let enterpriseName: String?
    let channelId: String
    let channelName: String
    let userId: String
    let userName: String
    let command: String
    let text: String
    let responseUrlString: String
    let triggerId: String
    
    enum CodingKeys: String, CodingKey {
        case token
        case teamId = "team_id"
        case teamDomain = "team_domain"
        case enterpriseId = "enterprise_id"
        case enterpriseName = "enterprise_name"
        case channelId = "channel_id"
        case channelName = "channel_name"
        case userId = "user_id"
        case userName = "user_name"
        case command
        case text
        case responseUrlString = "response_url"
        case triggerId = "trigger_id"
    }
}

extension SlackRequest: RequestModel {
    typealias ResponseModel = SlackResponse
    typealias Config = SlackConfig
    
    enum SlackConfig: String, Configuration {
        case slackToken
    }
    
    var responseURL: URL? { return URL(string: responseUrlString) }
}

extension SlackRequest {
    static func check(_ from: SlackRequest) -> SlackResponse? {
        guard from.responseURL != nil else {
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

struct SlackResponse: Equatable, Codable {
    enum ResponseType: String, Codable {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    let response_type: ResponseType
    let text: String?
    var attachments: [Attachment]
    let mrkdwn: Bool?
    
    struct Attachment: Equatable, Codable {
        let fallback: String?
        let text: String?
        let color: String?
        let mrkdwn_in: [String]
        let fields: [Field]
    }
    
    struct Field: Equatable, Codable {
        let title: String?
        let value: String?
        let short: Bool?
    }
}

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
