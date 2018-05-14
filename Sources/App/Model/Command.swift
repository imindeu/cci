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
            return SlackResponse(responseType: .ephemeral, text: "Unknown command (\(text))", attachements: [])
        case .noChannel(let channel):
            return SlackResponse(responseType: .ephemeral, text: "Unknown channel (\(channel))", attachements: [])
        case .noType(let text):
            return SlackResponse(responseType: .ephemeral, text: "Unknown command (\(text))", attachements: [])
        }

    }
}

enum Command {
    case deploy(project: String, job: String, branch: String, version: String?, groups: String?, emails: String?)
    case help
}

extension Command {
    init(channel: String, text: String, projects: [String]) throws {
        if text.hasPrefix("deploy") {
            let types = [
                "alpha": ("deploy_alpha", "dev"),
                "beta": ("deploy_beta", "master"),
                "appstore": ("deploy_appstore", "master")]
            
            guard let index = projects.index(where: { channel.hasPrefix($0) }) else {
                throw CommandError.noChannel(channel: channel)
            }
            let project = projects[index]

            var words = text.split(separator: " ").map(String.init)
            words.removeFirst()
            
            var job: String? = nil
            var branch: String? = nil
            var version: String? = nil
            var groups: String? = nil
            var emails: String? = nil

            for word in words {
                if types.keys.contains(word), let (key, value) = types[word] {
                    job = key
                    branch = value
                } else if word.contains("@") {
                    emails = word
                } else if word.range(of: "^\\d+.\\d+.\\d+$", options: .regularExpression) != nil {
                    version = word
                } else {
                    groups = word
                }
            }
            
            if job == nil || branch == nil {
                throw CommandError.noType(text: text)
            }
            self = .deploy(project: project, job: job!, branch: branch!, version: version, groups: groups, emails: emails)
        } else if text == "help" {
            self = .help
        } else {
            throw CommandError.unknowCommand(text: text)
        }
    }
    
    func parse(config: AppConfig) -> Either<HTTPRequest, SlackResponse> {
        switch self {
        case .deploy(let project, let job, let branch, let version, let groups, let emails):
            var request = HTTPRequest.init()
            request.method = .POST
            var params: [String] = [
                "build_parameters[CIRCLE_JOB]=\(job)",
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
            return .right(SlackResponse(responseType: .ephemeral, text: "Send commands to Circleci", attachements: [
                    ["text": "Commands:\n * deploy:\n/cci deploy alpha 2.0.1 qa,beta-customers"]
                ]))
        }
    }

}
