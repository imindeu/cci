//
//  CircleciCommand.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 14..
//

import Foundation
import Vapor

enum CommandError: Error {
    case unknowCommand(text: String)
    case noChannel(channel: String)
    case noType(text: String)
}

extension CommandError {
    var slackResponse: SlackResponse {
        switch self {
        case .unknowCommand(let text):
            return SlackResponse(responseType: .ephemeral, text: "Unknown command (\(text))", attachments: [])
        case .noChannel(let channel):
            return SlackResponse(responseType: .ephemeral, text: "Unknown channel (\(channel))", attachments: [])
        case .noType(let text):
            return SlackResponse(responseType: .ephemeral, text: "Unknown command (\(text))", attachments: [])
        }

    }
}

enum Command {
    case deploy(project: String, type: String, branch: String, version: String?, groups: String?, emails: String?)
    case help
}

extension Command {
    init(channel: String, text: String, projects: [String]) throws {
        if text.hasPrefix("deploy") {
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
            self = .deploy(project: project, type: type!, branch: branch!, version: version, groups: groups, emails: emails)
        } else if text == "help" {
            self = .help
        } else {
            throw CommandError.unknowCommand(text: text)
        }
    }
    
    func parse(config: AppConfig) -> Either<HTTPRequest, SlackResponse> {
        switch self {
        case .deploy(let project, let type, let branch, let version, let groups, let emails):
            var request = HTTPRequest.init()
            request.method = .POST
            var params: [String] = [
                "build_parameters[CIRCLE_JOB]=deploy",
                "build_paramaters[TYPE]=\(type)",
                "circle-token=\(config.circleciToken)"
            ]
            if let version = version {
                params.append("build_parameters[NEW_VERSION]=\(version)")
            }
            if let groups = groups {
                params.append("build_parameters[GROUPS]=\(groups)")
            }
            if let emails = emails {
                params.append("build_parameters[EMAILS]=\(emails)")
            }
            request.urlString = "/api/v1.1/project/\(config.vcs)/\(config.company)/\(project)/tree/\(branch)?\(params.joined(separator: "&"))"
            print("urlString: \(request.urlString)")
            request.headers = HTTPHeaders([("Accept", "application/json")])
            return .left(request)
        case .help:
            return .right(SlackResponse(responseType: .ephemeral, text: "Send commands to Circleci", attachments: [
                ["text": "Commands:\n * deploy:\n/cci deploy type [version] [emails] [groups]\n   * type: alpha|beta|app_store\n   * version: next version number (2.0.1)\n   * emails: coma separated spaceless list of emails to send to (xy@imind.eu,zw@test.com)\n   * groups: coma separated spaceless list of groups to send to (qa,beta-customers)\n\nIf emails and groups are both set, emails will be used"]
                ]))
        }
    }

}
