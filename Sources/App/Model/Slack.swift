//
//  Slack.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import Foundation
import Vapor

struct SlackCommand: Content {
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
}

protocol SlackResponseRepresentable {
    var slackResponse: SlackResponse { get }
}

struct SlackResponse: Content {
    enum ResponseType: String, Content {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    let response_type: ResponseType
    let text: String?
    let attachments: [Attachment]
    let mrkdwn: Bool?
    
    struct Attachment: Content {
        let fallback: String?
        let text: String?
        let color: String?
        let mrkdwn_in: [String]
        let fields: [Field]
    }
    
    struct Field: Content {
        let title: String?
        let value: String?
        let short: Bool?
    }
}

extension SlackResponse: SlackResponseRepresentable {
    var slackResponse: SlackResponse { return self }
}

extension SlackResponse {
    static func error(text: String) -> SlackResponse {
        let attachment = SlackResponse.Attachment(
            fallback: nil,
            text: text,
            color: "danger",
            mrkdwn_in: [],
            fields: [])
        return SlackResponse(response_type: .ephemeral, text: nil, attachments: [attachment], mrkdwn: true)
        
    }
}
