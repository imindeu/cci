//
//  CircleciCommand.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 14..
//

import Foundation
import Vapor

enum CommandError: Error {
    case unknownCommand(text: String)
    case unknownError
}

extension CommandError {
    static func any(error: Error) -> CommandError {
        if let error = error as? CommandError {
            return error
        } else {
            return .unknownError
        }
    }
}

extension CommandError: SlackResponseRepresentable {
    var slackResponse: SlackResponse {
        switch self {
        case .unknownCommand(let text):
            return SlackResponse.error(helpResponse: Command.helpResponse, text: "Unknown command (\(text))")
        case .unknownError:
            return SlackResponse.error(helpResponse: Command.helpResponse, text: "Unknown error")
        }

    }
}

enum Command {
    
    case deploy(CircleciDeployJobRequest)
    case test(CircleciTestJobRequest)
    case help(HelpResponse.Type)
    
    static var helpCommands: [String: HelpResponse.Type] =
        ["deploy": CircleciDeployJobRequest.self,
         "test": CircleciTestJobRequest.self,
         "help": Command.self]
}

extension Command: HelpResponse {
    static var helpResponse: SlackResponse {
        let text = "Help:\n- `/cci command [help]`\n" +
            "Current command\n" +
            "   - help: show this message\n" +
            "   - deploy: deploy a build\n" +
            "   - test: test a branch\n\n" +
            "All commands have a help subcommand to show their functionality\n"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
        
    }
}

extension Command {
    init(channel: String, text: String) throws {
        var words = text.split(separator: " ").map(String.init)
        guard words.count > 0 else {
            throw CommandError.unknownCommand(text: text)
        }
        let command = words[0]
        words.removeFirst()

        if command == "help" || (words.count > 0 && words[0] == "help") {
            if let type = Command.helpCommands[command] {
                self = .help(type)
            } else {
                throw CommandError.unknownCommand(text: text)
            }
        } else if command == "deploy" {
            let request = try CircleciDeployJobRequest.parse(channel: channel, words: words)
            self = .deploy(request)
        } else if command == "test" {
            let request = try CircleciTestJobRequest.parse(channel: channel, words: words)
            self = .test(request)
        } else {
            throw CommandError.unknownCommand(text: text)
        }
    }
    
    func fetch(worker: Worker) -> Future<SlackResponseRepresentable> {
        switch self {
        case .deploy(let request):
            return CircleciDeploy.fetch(worker: worker, request: request)
        case .test(let request):
            return CircleciTest.fetch(worker: worker, request: request)
        case .help(let type):
            return Future.map(on: worker) { type.helpResponse }
        }
    }
    
}
