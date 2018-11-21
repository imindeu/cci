//
//  Circleci.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import APIConnect
import Foundation

enum CircleCiError: Error {
    case noChannel(String)
    case unknownCommand(String)
    case parse(String)
}

protocol CircleCiJob {
    var name: String { get }
    var project: String { get }
    var branch: String { get }
    var options: [String] { get }
    var username: String { get }
    
    static var helpResponse: SlackResponse { get }
    
    static func parse(project: String, parameters: [String], options:[String], username: String) throws -> Either<SlackResponse, CircleCiJob>
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

struct CircleCiTestJob: CircleCiJob {
    let name: String = CircleCiJobKind.test.rawValue
    let project: String
    let branch: String
    let options: [String]
    let username: String
}

extension CircleCiTestJob {
    static var helpResponse: SlackResponse {
        let text = "`test`: test a branch\n" +
            "Usage:\n`/cci test branch [options]`\n" +
            "  - *branch*: branch name to test\n" +
        "  - *options*: optional fastlane options in the xyz:qwo format\n"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
    }
    
    static func parse(project: String, parameters: [String], options:[String], username: String) throws -> Either<SlackResponse, CircleCiJob> {
        guard parameters.count > 0 else {
            throw CircleCiError.parse("No branch found: (\(parameters.joined(separator: " ")))")
        }
        guard parameters[0] != "help" else {
            return .left(CircleCiTestJob.helpResponse)
        }
        let branch = parameters[0]
        return .right(CircleCiTestJob(project: project, branch: branch, options: options, username: username))
        
    }
}

struct CircleCiDeployJob: CircleCiJob {
    let name: String = CircleCiJobKind.deploy.rawValue
    let project: String
    let branch: String
    let options: [String]
    let username: String
    let type: String
}

extension CircleCiDeployJob {
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
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
    }
    
    static func parse(project: String, parameters: [String], options: [String], username: String) throws -> Either<SlackResponse, CircleCiJob> {
        if parameters.count == 1 && parameters[0] == "help" {
            return .left(CircleCiDeployJob.helpResponse)
        }
        let types = [
            "alpha": "dev",
            "beta": "master",
            "app_store": "release"]
        if parameters.count == 0 || !types.keys.contains(parameters[0]) {
            throw CircleCiError.parse("Unknown type: (\(parameters.joined(separator: " ")))")
        }
        let type = parameters[0]
        guard let branch = parameters[safe: 1] ?? types[type] else {
            throw CircleCiError.parse("No branch found: (\(parameters.joined(separator: " ")))")
        }
        return .right(CircleCiDeployJob(project: project, branch: branch, options: options, username: username, type: type))
    }
}

struct CircleCiJobRequest: RequestModel {
    typealias Response = CircleCiBuildResponse
    typealias Config = CircleCiConfig
    
    enum CircleCiConfig: String, Configuration {
        case circleCiTokens
        case company
        case vcs
        case projects
    }
    
    let job: CircleCiJob
    let responseURL: URL? = nil
}

extension CircleCiJobRequest {
    static var helpResponse: SlackResponse {
        let text = "Help:\n- `/cci command [help]`\n" +
            "Current command\n" +
            "  - help: show this message\n" +
            "  - deploy: deploy a build\n" +
            "  - test: test a branch\n\n" +
        "All commands have a help subcommand to show their functionality\n"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
    }
    
    static func slackRequest(_ from: SlackRequest, _ environment: Environment) -> Either<SlackResponse, CircleCiJobRequest> {
        let projects: [String] = Environment.get(CircleCiConfig.projects)?.split(separator: ",").map(String.init) ?? []
        
        guard let index = projects.index(where: { from.channel_name.hasPrefix($0) }) else {
            return .left(SlackResponse.error(text: CircleCiError.noChannel(from.channel_name).localizedDescription))
        }
        let project = projects[index]
        
        var parameters = from.text.split(separator: " ").map(String.init).filter({ !$0.isEmpty })
        guard parameters.count > 0 else {
            return .left(SlackResponse.error(text: CircleCiError.unknownCommand(from.text).localizedDescription))
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
                           username: from.user_name)
                    .map { CircleCiJobRequest(job: $0) }
            } catch {
                return .left(SlackResponse.error(text: error.localizedDescription, helpResponse: job.type.helpResponse))
            }
        } else if command == "help" {
            return .left(helpResponse)
        } else {
            return .left(SlackResponse.error(text: CircleCiError.unknownCommand(from.text).localizedDescription))
        }
    }
    static func apiWithSlack(_ context: Context, _ environment: Environment) -> (Either<SlackResponse, CircleCiJobRequest>) -> IO<Either<SlackResponse, CircleCiBuildResponse>> {
        fatalError()
    }
    static func responseToSlack(_ with: CircleCiBuildResponse) -> SlackResponse {
        fatalError()
    }
}

struct CircleCiBuildResponse: ResponseModel, Decodable {
    let build_url: String
    let build_num: Int
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
