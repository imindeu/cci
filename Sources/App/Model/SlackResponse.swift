//
//  SlackResponse.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 10..
//

import Foundation
import Vapor

struct SlackResponse: Content {
    enum ResponseType: String, Content {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    let responseType: ResponseType
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

extension SlackResponse {
    static func error(text: String) -> SlackResponse {
        let attachment = SlackResponse.Attachment(
            fallback: nil,
            text: text,
            color: "danger",
            mrkdwn_in: [],
            fields: [])
        return SlackResponse(responseType: .ephemeral, text: nil, attachments: [attachment], mrkdwn: true)

    }
}
