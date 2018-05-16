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
    case noChannel(channel: String)
    case noType(text: String)
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
            return SlackResponse.error(text: "Unknown command (\(text))")
        case .noChannel(let channel):
            return SlackResponse.error(text: "Unknown channel (\(channel))")
        case .noType(let text):
            return SlackResponse.error(text: "Unknown command (\(text))")
        case .unknownError:
            return SlackResponse.error(text: "Unknown error")
        }

    }
}

typealias Deploy = (project: String, type: String, branch: String, version: String?, groups: String?, emails: String?)

enum Command {
    case deploy(Deploy)
    case help
}

extension Command {
    init(channel: String, text: String) throws {
        if text.hasPrefix("deploy") {
            let projects = AppEnvironment.current.projects
            let types = [
                "alpha": "dev",
                "beta": "master",
                "app_store": "master"]
            
            guard let index = projects.index(where: { channel.hasPrefix($0) }) else {
                throw CommandError.noChannel(channel: channel)
            }
            let project = projects[index]

            var words = text.split(separator: " ").map(String.init)
            words.removeFirst()
            
            var type: String? = nil
            var branch: String? = nil
            var version: String? = nil
            var groups: String? = nil
            var emails: String? = nil

            for word in words {
                if let value = types[word] {
                    type = word
                    branch = value
                } else if word.contains("@") {
                    emails = word
                } else if word.range(of: "^\\d+.\\d+.\\d+$", options: .regularExpression) != nil {
                    version = word
                } else {
                    groups = word
                }
            }
            
            if type == nil || branch == nil {
                throw CommandError.noType(text: text)
            }
            self = .deploy((project: project, type: type!, branch: branch!, version: version, groups: groups, emails: emails))
        } else if text == "help" {
            self = .help
        } else {
            throw CommandError.unknownCommand(text: text)
        }
    }
    
    func fetch(worker: Worker) -> Future<SlackResponseRepresentable> {
        switch self {
        case .deploy(let deploy):
            return CircleciDeployResponse.fetch(worker: worker, deploy: deploy)
        case .help:
            let text = "Commands:\n- deploy:\n`/cci deploy type [version] [emails] [groups]`\n" +
                "   - *type*: alpha|beta|app_store\n" +
                "   - *version*: next version number (2.0.1)\n" +
                "   - *emails*: coma separated spaceless list of emails to send to (xy@imind.eu,zw@test.com)\n" +
                "   - *groups*: coma separated spaceless list of groups to send to (qa,beta-customers)\n\n" +
            "   If emails and groups are both set, emails will be used"
            let attachment = SlackResponse.Attachment(
                fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
            let response = SlackResponse(responseType: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
            return Future.map(on: worker) { response }
        }
    }
    
}
