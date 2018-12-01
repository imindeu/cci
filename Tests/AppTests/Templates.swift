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
                  teamId: String = "",
                  teamDomain: String = "",
                  enterpriseId: String? = nil,
                  enterpriseName: String? = nil,
                  channelId: String = "",
                  channelName: String = "",
                  userId: String = "",
                  userName: String = "",
                  command: String = "",
                  text: String = "",
                  responseUrlString: String = "",
                  triggerId: String = "") -> SlackRequest {
        return SlackRequest(token: token,
                            teamId: teamId,
                            teamDomain: teamDomain,
                            enterpriseId: enterpriseId,
                            enterpriseName: enterpriseName,
                            channelId: channelId,
                            channelName: channelName,
                            userId: userId,
                            userName: userName,
                            command: command,
                            text: text,
                            responseUrlString: responseUrlString,
                            triggerId: triggerId)
    }
}
