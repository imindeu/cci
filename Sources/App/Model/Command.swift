//
//  CircleciCommand.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 14..
//

import Foundation
import Vapor

enum CommandError: Error {
    case noChannel(channel: String)
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
        case .noChannel(let channel):
            return SlackResponse.error(helpResponse: Command.helpResponse, text: "No project found (channel: \(channel))")
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

    struct C {
        static let help = "help"
        static let deploy = "deploy"
        static let test = "test"
    }

    static var helpCommands: [String: HelpResponse.Type] =
        [C.deploy: CircleciDeployJobRequest.self,
         C.test: CircleciTestJobRequest.self,
         C.help: Command.self]
    
}

extension Command: HelpResponse {
    static var helpResponse: SlackResponse {
        let text = "Help:\n- `/cci command [help]`\n" +
            "Current command\n" +
            "  - \(C.help): show this message\n" +
            "  - \(C.deploy): deploy a build\n" +
            "  - \(C.test): test a branch\n\n" +
            "All commands have a help subcommand to show their functionality\n"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
        
    }
}

extension Command {
    init(slack: SlackRequest) throws {
        let projects = Environment.current.projects
        
        guard let index = projects.index(where: { slack.channel_name.hasPrefix($0) }) else {
            throw CommandError.noChannel(channel: slack.channel_name)
        }
        let project = projects[index]

        var parameters = slack.text.split(separator: " ").map(String.init).filter({ !$0.isEmpty })
        guard parameters.count > 0 else {
            throw CommandError.unknownCommand(text: slack.text)
        }
        let command = parameters[0]
        parameters.removeFirst()
        
        let isOption: (String) -> Bool = { $0.contains(":") }
        let options = parameters.filter(isOption)
        parameters = parameters.filter { !isOption($0) }

        if command == C.help || (parameters.count > 0 && parameters[0] == C.help) {
            if let type = Command.helpCommands[command] {
                self = .help(type)
            } else {
                throw CommandError.unknownCommand(text: slack.text)
            }
        } else if command == C.deploy {
            let request = try CircleciDeployJobRequest.parse(project: project, parameters: parameters, options: options, username: slack.user_name)
            self = .deploy(request)
        } else if command == C.test {
            let request = try CircleciTestJobRequest.parse(project: project, parameters: parameters, options: options, username: slack.user_name)
            self = .test(request)
        } else {
            throw CommandError.unknownCommand(text: slack.text)
        }
    }
    
    func fetch(worker: Worker) -> Future<SlackResponseRepresentable> {
        switch self {
        case .deploy(let request):
            return request.fetch(worker: worker)
        case .test(let request):
            return request.fetch(worker: worker)
        case .help(let type):
            return Future.map(on: worker) { type.helpResponse }
        }
    }
    
}
