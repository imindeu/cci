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
    let text: String
    let attachements: [[String:String]]
}
