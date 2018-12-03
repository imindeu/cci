//
//  Circleci.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import APIConnect
import APIModels
import Foundation
import HTTP

enum CircleCiError: Error {
    case noChannel(String)
    case unknownCommand(String)
    case parse(String)
    case underlying(Error)
    case decode
}

extension CircleCiError {
    var text: String {
        switch self {
        case .noChannel(let name):
            return "No project found (channel: \(name))"
        case .unknownCommand(let text):
            return "Unknown command (\(text))"
        case .parse(let string):
            return "Parse error (\(string))"
        case .decode:
            return "Decode error"
        case .underlying(let error):
            if let circleCiError = error as? CircleCiError {
                return circleCiError.text
            }
            return "Unknown error (\(error))"
        }
    }
}

protocol CircleCiJob {
    var name: String { get }
    var project: String { get }
    var branch: String { get }
    var options: [String] { get }
    var username: String { get }
    
    var buildParameters: [String: String] { get }
    var slackResponseFields: [SlackResponse.Field] { get }
    
    static var helpResponse: SlackResponse { get }
    
    static func parse(project: String, parameters: [String], options: [String], username: String) throws
        -> Either<SlackResponse, CircleCiJob>
}

extension CircleCiJob {
    var buildParameters: [String: String] {
        return [
            "DEPLOY_OPTIONS": options.joined(separator: " "),
            "CIRCLE_JOB": name
        ]
    }
    var urlEncodedBranch: String {
        return branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? branch
    }
}

enum CircleCiJobKind: String, CaseIterable {
    case deploy
    case test
}

extension CircleCiJobKind {
    var type: CircleCiJob.Type {
        switch self {
        case .deploy:
            return CircleCiDeployJob.self
        case .test:
            return CircleCiTestJob.self
        }
    }
}

struct CircleCiTestJob: CircleCiJob, Equatable {
    let name: String = CircleCiJobKind.test.rawValue
    let project: String
    let branch: String
    let options: [String]
    let username: String
}

extension CircleCiTestJob {
    var slackResponseFields: [SlackResponse.Field] {
        return [
            SlackResponse.Field(title: "Project", value: project, short: true),
            SlackResponse.Field(title: "Branch", value: branch, short: true),
            SlackResponse.Field(title: "User", value: username, short: true)
        ]
    }

    static var helpResponse: SlackResponse {
        let text = "`test`: test a branch\n" +
            "Usage:\n`/cci test branch [options]`\n" +
            "  - *branch*: branch name to test\n" +
            "  - *options*: optional fastlane options in the xyz:qwo format\n" +
            "  (currently available options, maybe not up to date: " +
            "    restrict_fixme_comments)"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwnIn: ["text"], fields: [])
        let response = SlackResponse(responseType: .ephemeral,
                                     text: "Send commands to <https://circleci.com|CircleCI>",
                                     attachments: [attachment],
                                     mrkdwn: true)
        return response
    }
    
    static func parse(project: String,
                      parameters: [String],
                      options: [String],
                      username: String) throws -> Either<SlackResponse, CircleCiJob> {
        
        guard !parameters.isEmpty else {
            throw CircleCiError.parse("No branch found: (\(parameters.joined(separator: " ")))")
        }
        guard parameters[0] != "help" else {
            return .left(CircleCiTestJob.helpResponse)
        }
        let branch = parameters[0]
        return .right(CircleCiTestJob(project: project, branch: branch, options: options, username: username))
        
    }
}

struct CircleCiDeployJob: CircleCiJob, Equatable {
    let name: String = CircleCiJobKind.deploy.rawValue
    let project: String
    let branch: String
    let options: [String]
    let username: String
    let type: String
}

extension CircleCiDeployJob {
    var buildParameters: [String: String] {
        return [
            "DEPLOY_TYPE": type,
            "DEPLOY_OPTIONS": options.joined(separator: " "),
            "CIRCLE_JOB": name
        ]
    }

    var slackResponseFields: [SlackResponse.Field] {
        return [
            SlackResponse.Field(title: "Project", value: project, short: true),
            SlackResponse.Field(title: "Type", value: type, short: true),
            SlackResponse.Field(title: "User", value: username, short: true),
            SlackResponse.Field(title: "Branch", value: branch, short: true)
        ]
    }

    static var helpResponse: SlackResponse {
        let text = "`deploy`: deploy a build\n" +
            "Usage:\n`/cci deploy type [options] [branch]`\n" +
            "  - *type*: alpha|beta|app_store\n" +
            "  - *options*: optional fastlane options in the xyz:qwo format\n" +
            "    (eg. emails:xy@test.com,zw@test.com groups:qa,beta-customers version:2.0.1)\n" +
            "    (space shouldn't be in the option for now)\n" +
            "  - *branch*: an optional branch name to deploy from\n" +
            "  If emails and groups are both set, emails will be used\n" +
            "  (currently available options, maybe not up to date: " +
            "    emails, groups, use_git, version, skip_xcode_version_check)"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwnIn: ["text"], fields: [])
        let response = SlackResponse(responseType: .ephemeral,
                                     text: "Send commands to <https://circleci.com|CircleCI>",
                                     attachments: [attachment],
                                     mrkdwn: true)
        return response
    }
    
    static func parse(project: String,
                      parameters: [String],
                      options: [String],
                      username: String) throws -> Either<SlackResponse, CircleCiJob> {
        
        if parameters.count == 1 && parameters[0] == "help" {
            return .left(CircleCiDeployJob.helpResponse)
        }
        let types = [
            "alpha": "dev",
            "beta": "master",
            "app_store": "release"]
        if parameters.isEmpty || !types.keys.contains(parameters[0]) {
            throw CircleCiError.parse("Unknown type: (\(parameters.joined(separator: " ")))")
        }
        let type = parameters[0]
        guard let branch = parameters[safe: 1] ?? types[type] else {
            throw CircleCiError.parse("No branch found: (\(parameters.joined(separator: " ")))")
        }
        return .right(CircleCiDeployJob(project: project,
                                        branch: branch,
                                        options: options,
                                        username: username,
                                        type: type))
    }
}

struct CircleCiJobRequest: RequestModel {
    typealias ResponseModel = CircleCiBuildResponse
    typealias Config = CircleCiConfig
    
    enum CircleCiConfig: String, Configuration {
        case tokens = "circleCiTokens"
        case company = "circleCiCompany"
        case vcs = "circleCiVcs"
        case projects = "circleCiProjects"
    }
    
    let job: CircleCiJob
    let responseURL: URL? = nil
}

extension CircleCiJobRequest {
    static var path: (String, String) -> String = { project, branch in
        let projects: [String] = Environment.getArray(CircleCiConfig.projects)
        let circleCiTokens = Environment.getArray(CircleCiConfig.tokens)
        let vcs = Environment.get(CircleCiConfig.vcs)!
        let company = Environment.get(CircleCiConfig.company)!
        let index = projects.index(of: project)! // TODO: catch forced unwrap
        let circleciToken = circleCiTokens[index]
        return "/api/v1.1/project/\(vcs)/\(company)/\(project)/tree/\(branch)?circle-token=\(circleciToken)"
    }
    
    static var helpResponse: SlackResponse {
        let text = "Help:\n- `/cci command [help]`\n" +
            "Current command\n" +
            "  - help: show this message\n" +
            "  - deploy: deploy a build\n" +
            "  - test: test a branch\n\n" +
        "All commands have a help subcommand to show their functionality\n"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwnIn: ["text"], fields: [])
        let response = SlackResponse(responseType: .ephemeral,
                                     text: "Send commands to <https://circleci.com|CircleCI>",
                                     attachments: [attachment],
                                     mrkdwn: true)
        return response
    }
    
    static func slackRequest(_ from: SlackRequest) -> Either<SlackResponse, CircleCiJobRequest> {
        let projects: [String] = Environment.get(CircleCiConfig.projects)?.split(separator: ",").map(String.init) ?? []
        
        guard let index = projects.index(where: { from.channelName.hasPrefix($0) }) else {
            return .left(SlackResponse.error(text: CircleCiError.noChannel(from.channelName).text))
        }
        let project = projects[index]
        
        var parameters = from.text.split(separator: " ").map(String.init).filter({ !$0.isEmpty })
        guard !parameters.isEmpty else {
            return .left(SlackResponse.error(text: CircleCiError.unknownCommand(from.text).text))
        }
        let command = parameters[0]
        parameters.removeFirst()
        
        let isOption: (String) -> Bool = { $0.contains(":") }
        let options = parameters.filter(isOption)
        parameters = parameters.filter { !isOption($0) }
        
        if let job = CircleCiJobKind(rawValue: command) {
            do {
                return try job.type
                    .parse(project: project,
                           parameters: parameters,
                           options: options,
                           username: from.userName)
                    .map { CircleCiJobRequest(job: $0) }
            } catch {
                return .left(SlackResponse.error(text: CircleCiError.underlying(error).text,
                                                 helpResponse: job.type.helpResponse))
            }
        } else if command == "help" {
            return .left(helpResponse)
        } else {
            return .left(SlackResponse.error(text: CircleCiError.unknownCommand(from.text).text))
        }
    }
    
    static func apiWithSlack(_ context: Context)
        -> (Either<SlackResponse, CircleCiJobRequest>)
        -> EitherIO<SlackResponse, CircleCiBuildResponse> {
        
        let instantResponse: (SlackResponse) -> EitherIO<SlackResponse, CircleCiBuildResponse> = {
            pure(.left($0), context)
        }
        return {
            return $0.either(instantResponse) { jobRequest -> EitherIO<SlackResponse, CircleCiBuildResponse> in
                let job = jobRequest.job
                var request = HTTPRequest.init()
                request.method = .POST
                
                request.urlString = CircleCiJobRequest.path(job.project, job.urlEncodedBranch)
                
                do {
                    let body = try JSONEncoder().encode(["build_parameters": job.buildParameters])
                    request.body = HTTPBody(data: body)
                    request.headers = HTTPHeaders([
                        ("Accept", "application/json"),
                        ("Content-Type", "application/json")
                        ])
                    return Environment.api("circleci.com", nil)(context, request)
                        .map { response -> Either<SlackResponse, CircleCiBuildResponse> in
                            if let deployResponse = try response.body.data.map {
                                try JSONDecoder().decode(CircleCiResponse.self, from: $0)
                            } {
                                return .right(CircleCiBuildResponse(response: deployResponse, job: job))
                            } else {
                                throw CircleCiError.decode
                            }
                        }
                        .catchMap {
                            return .left(SlackResponse.error(text: CircleCiError.underlying($0).text,
                                                             helpResponse: CircleCiJobRequest.helpResponse))
                    }
                } catch let error {
                    return instantResponse(SlackResponse.error(text: CircleCiError.underlying(error).text,
                                                               helpResponse: CircleCiJobRequest.helpResponse))
                }
            }
        }
    }
    static func responseToSlack(_ from: CircleCiBuildResponse) -> SlackResponse {
        let job = from.job
        let response = from.response
        let fallback = "Job '\(job.name)' has started at <\(response.buildURL)|#\(response.buildNum)>. " +
            "(project: \(from.job.project), branch: \(job.branch))"
        var fields = job.slackResponseFields
        job.options.forEach { option in
            let array = option.split(separator: ":").map(String.init)
            if array.count == 2 {
                fields.append(SlackResponse.Field(title: array[0], value: array[1], short: true))
            }
        }
        let attachment = SlackResponse.Attachment(
            fallback: fallback,
            text: "Job '\(job.name)' has started at <\(response.buildURL)|#\(response.buildNum)>.",
            color: "#764FA5",
            mrkdwnIn: ["text", "fields"],
            fields: fields)
        return SlackResponse(responseType: .inChannel, text: nil, attachments: [attachment], mrkdwn: true)
    }
}

struct CircleCiBuildResponse {
    let response: CircleCiResponse
    let job: CircleCiJob
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
