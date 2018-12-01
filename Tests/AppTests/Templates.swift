//
//  Templates.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

import APIConnect
import Vapor
@testable import App

func context() throws -> Context {
    let app = try Application()
    return Request(using: app)
}

extension SlackRequest {
    static func template(token: String = "",
                  team_id: String = "",
                  team_domain: String = "",
                  enterprise_id: String? = nil,
                  enterprise_name: String? = nil,
                  channel_id: String = "",
                  channel_name: String = "",
                  user_id: String = "",
                  user_name: String = "",
                  command: String = "",
                  text: String = "",
                  response_url: String = "",
                  trigger_id: String = "") -> SlackRequest {
        return SlackRequest(token: token,
                            team_id: team_id,
                            team_domain: team_domain,
                            enterprise_id: enterprise_id,
                            enterprise_name: enterprise_name,
                            channel_id: channel_id,
                            channel_name: channel_name,
                            user_id: user_id,
                            user_name: user_name,
                            command: command,
                            text: text,
                            response_url: response_url,
                            trigger_id: trigger_id)
    }
}
