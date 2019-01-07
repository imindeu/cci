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

extension CircleCi {

    enum Error: LocalizedError {
        case noChannel(String)
        case noBranch(String)
        case unknownCommand(String)
        case unknownType(String)
        case decode
        case badResponse(String?)
        case underlying(Swift.Error)
        
        public var errorDescription: String? {
            switch self {
            case .noChannel(let name):
                return "No project found (channel: \(name))"
            case .unknownCommand(let text):
                return "Unknown command (\(text))"
            case .noBranch(let string):
                return "No branch found (\(string))"
            case .unknownType(let text):
                return "Unknown type (\(text))"
            case .decode:
                return "Decode error"
            case .badResponse(let message):
                return "CircleCi message: \"\(message ?? "")\""
            case .underlying(let error):
                if let localizedError = error as? LocalizedError {
                    return localizedError.localizedDescription
                    
                }
                return "Unknown error (\(error))"
            }
        }
    }

    struct JobRequest: RequestModel {
        typealias ResponseModel = BuildResponse
        
        enum Config: String, Configuration {
            case tokens = "circleCiTokens"
            case company = "circleCiCompany"
            case vcs = "circleCiVcs"
            case projects = "circleCiProjects"
        }
        
        let job: CircleCiJob
    }
    
    struct BuildResponse {
        let response: Response
        let job: CircleCiJob
    }
}

protocol CircleCiJob {
    var name: String { get }
    var project: String { get }
    var branch: String { get }
    var options: [String] { get }
    var username: String { get }
    
    var buildParameters: [String: String] { get }
    var slackResponseFields: [Slack.Response.Field] { get }
    
    static var helpResponse: Slack.Response { get }
    
    static func parse(project: String, parameters: [String], options: [String], username: String) throws
        -> Either<Slack.Response, CircleCiJob>
}

extension CircleCiJob {
    var buildParameters: [String: String] {
        return [
            "CCI_OPTIONS": options.joined(separator: " "),
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

private extension CircleCiJobKind {
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
    var slackResponseFields: [Slack.Response.Field] {
        return [
            Slack.Response.Field(title: "Project", value: project, short: true),
            Slack.Response.Field(title: "Branch", value: branch, short: true),
            Slack.Response.Field(title: "User", value: username, short: true)
        ]
    }
    
    static var helpResponse: Slack.Response {
        let text = "`test`: test a branch\n" +
            "Usage:\n`/cci test branch [options]`\n" +
            "  - *branch*: branch name to test\n" +
            "  - *options*: optional fastlane options in the xyz:qwo format\n" +
            "  (currently available options, maybe not up to date: " +
        "    restrict_fixme_comments)"
        let attachment = Slack.Response.Attachment(
            fallback: text, text: text, color: "good", mrkdwnIn: ["text"], fields: [])
        let response = Slack.Response(responseType: .ephemeral,
                                      text: "Send commands to <https://circleci.com|CircleCI>",
                                      attachments: [attachment],
                                      mrkdwn: true)
        return response
    }
    
    static func parse(project: String,
                      parameters: [String],
                      options: [String],
                      username: String) throws -> Either<Slack.Response, CircleCiJob> {
        
        guard !parameters.isEmpty else {
            throw CircleCi.Error.noBranch(parameters.joined(separator: " "))
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
            "CCI_DEPLOY_TYPE": type,
            "CCI_OPTIONS": options.joined(separator: " "),
            "CIRCLE_JOB": name
        ]
    }
    
    var slackResponseFields: [Slack.Response.Field] {
        return [
            Slack.Response.Field(title: "Project", value: project, short: true),
            Slack.Response.Field(title: "Type", value: type, short: true),
            Slack.Response.Field(title: "User", value: username, short: true),
            Slack.Response.Field(title: "Branch", value: branch, short: true)
        ]
    }
    
    static var helpResponse: Slack.Response {
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
        let attachment = Slack.Response.Attachment(
            fallback: text, text: text, color: "good", mrkdwnIn: ["text"], fields: [])
        let response = Slack.Response(responseType: .ephemeral,
                                      text: "Send commands to <https://circleci.com|CircleCI>",
                                      attachments: [attachment],
                                      mrkdwn: true)
        return response
    }
    
    static func parse(project: String,
                      parameters: [String],
                      options: [String],
                      username: String) throws -> Either<Slack.Response, CircleCiJob> {
        
        if parameters.count == 1 && parameters[0] == "help" {
            return .left(CircleCiDeployJob.helpResponse)
        }
        let types = [
            "alpha": "dev",
            "beta": "master",
            "app_store": "release"]
        if parameters.isEmpty || !types.keys.contains(parameters[0]) {
            throw CircleCi.Error.unknownType(parameters.joined(separator: " "))
        }
        let type = parameters[0]
        guard let branch = parameters[safe: 1] ?? types[type] else {
            throw CircleCi.Error.noBranch(parameters.joined(separator: " "))
        }
        return .right(CircleCiDeployJob(project: project,
                                        branch: branch,
                                        options: options,
                                        username: username,
                                        type: type))
    }
}

extension CircleCi {
    
    static var path: (String, String) -> String = { project, branch in
        let projects: [String] = Environment.getArray(JobRequest.Config.projects)
        let circleCiTokens = Environment.getArray(JobRequest.Config.tokens)
        let vcs = Environment.get(JobRequest.Config.vcs)!
        let company = Environment.get(JobRequest.Config.company)!
        let index = projects.index(of: project)! // TODO: catch forced unwrap
        let circleciToken = circleCiTokens[index]
        return "/api/v1.1/project/\(vcs)/\(company)/\(project)/tree/\(branch)?circle-token=\(circleciToken)"
    }
    
    static var helpResponse: Slack.Response {
        let text = "Help:\n- `/cci command [help]`\n" +
            "Current command\n" +
            "  - help: show this message\n" +
            "  - deploy: deploy a build\n" +
            "  - test: test a branch\n\n" +
        "All commands have a help subcommand to show their functionality\n"
        let attachment = Slack.Response.Attachment(
            fallback: text, text: text, color: "good", mrkdwnIn: ["text"], fields: [])
        let response = Slack.Response(responseType: .ephemeral,
                                      text: "Send commands to <https://circleci.com|CircleCI>",
                                      attachments: [attachment],
                                      mrkdwn: true)
        return response
    }
    
    // MARK: Slack
    static func slackRequest(_ from: Slack.Request,
                             _ headers: Headers? = nil) -> Either<Slack.Response, JobRequest> {
        let projects: [String] = Environment.getArray(JobRequest.Config.projects)
        
        guard let index = projects.index(where: { from.channelName.hasPrefix($0) }) else {
            return .left(Slack.Response.error(Error.noChannel(from.channelName)))
        }
        let project = projects[index]
        
        var parameters = from.text.split(separator: " ").map(String.init).filter({ !$0.isEmpty })
        guard !parameters.isEmpty else {
            return .left(Slack.Response.error(Error.unknownCommand(from.text)))
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
                    .map { JobRequest(job: $0) }
            } catch {
                return .left(Slack.Response.error(Error.underlying(error),
                                                  helpResponse: job.type.helpResponse))
            }
        } else if command == "help" {
            return .left(helpResponse)
        } else {
            return .left(Slack.Response.error(Error.unknownCommand(from.text)))
        }
    }
    
    static func apiWithSlack(_ context: Context)
        -> (JobRequest)
        -> EitherIO<Slack.Response, BuildResponse> {
            return { jobRequest -> EitherIO<Slack.Response, BuildResponse> in
                do {
                    return try fetch(job: jobRequest.job, context: context)
                        .map { .right($0) }
                        .catchMap { .left(
                            Slack.Response.error(Error.underlying($0),
                                                 helpResponse: helpResponse))
                        }
                } catch {
                    return leftIO(context)(
                        Slack.Response.error(Error.underlying(error),
                                             helpResponse: helpResponse))
                }
            }
    }
    
    static func responseToSlack(_ from: BuildResponse) -> Slack.Response {
        guard let buildURL = from.response.buildURL, let buildNum = from.response.buildNum else {
            return Slack.Response.error(Error.badResponse(from.response.message))
        }
        let job = from.job
        let fallback = "Job '\(job.name)' has started at <\(buildURL)|#\(buildNum)>. " +
        "(project: \(from.job.project), branch: \(job.branch))"
        var fields = job.slackResponseFields
        job.options.forEach { option in
            let array = option.split(separator: ":").map(String.init)
            if array.count == 2 {
                fields.append(Slack.Response.Field(title: array[0], value: array[1], short: true))
            }
        }
        let attachment = Slack.Response.Attachment(
            fallback: fallback,
            text: "Job '\(job.name)' has started at <\(buildURL)|#\(buildNum)>.",
            color: "#764FA5",
            mrkdwnIn: ["text", "fields"],
            fields: fields)
        return Slack.Response(responseType: .inChannel, text: nil, attachments: [attachment], mrkdwn: true)
    }

    // MARK: Github
    static func githubRequest(_ from: Github.Payload,
                              _ headers: Headers?) -> Either<Github.PayloadResponse, JobRequest> {
        let defaultResponse: Either<Github.PayloadResponse, JobRequest> = .left(Github.PayloadResponse())
        guard let type = from.type(headers: headers), let repo = from.repository?.name else {
            return defaultResponse
        }
        switch type {
        case let .pullRequestLabeled(label: Github.waitingForReviewLabel, head: head, base: base):
            do {
                var options: [String] = []
                if [Github.masterBranch, Github.releaseBranch].contains(base) {
                    options.append("restrict_fixme_comments:true")
                }
                return try CircleCiTestJob.parse(project: repo,
                                                 parameters: [head.ref],
                                                 options: options,
                                                 username: "cci")
                    .either({ _ in return defaultResponse }, { .right(JobRequest(job: $0)) })
            } catch {
                return defaultResponse
            }
        default: return defaultResponse
        }
    }
    
    static func apiWithGithub(_ context: Context)
        -> (JobRequest)
        -> EitherIO<Github.PayloadResponse, BuildResponse> {
            return { jobRequest -> EitherIO<Github.PayloadResponse, BuildResponse> in
                do {
                    return try fetch(job: jobRequest.job, context: context)
                        .map { .right($0) }
                        .catchMap { .left(Github.PayloadResponse(error: Error.underlying($0))) }
                } catch {
                    return leftIO(context)(Github.PayloadResponse(error: Error.underlying(error)))
                }
            }
    }
    
    static func responseToGithub(_ from: BuildResponse) -> Github.PayloadResponse {
        return Github.PayloadResponse(value: "buildURL: \(from.response.buildURL ?? ""), "
            + "buildNum: \(from.response.buildNum ?? -1)")
    }
    
    private static func fetch(job: CircleCiJob, context: Context) throws -> IO<BuildResponse> {
        let body = try JSONEncoder().encode(["build_parameters": job.buildParameters])
        let headers = HTTPHeaders([
            ("Accept", "application/json"),
            ("Content-Type", "application/json")
        ])
        let httpRequest = HTTPRequest(method: .POST,
                                      url: path(job.project, job.urlEncodedBranch),
                                      headers: headers,
                                      body: body)
        return Environment.api("circleci.com", nil)(context, httpRequest)
            .decode(Response.self)
            .map { response in
                guard let response = response else {
                    throw Error.decode
                }
                return BuildResponse(response: response, job: job)
            }
    }

}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}