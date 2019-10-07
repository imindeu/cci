//
//  Circleci.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import APIConnect
import APIService

import enum APIModels.CircleCi
import enum APIModels.Github
import enum APIModels.Slack

import protocol Foundation.LocalizedError
import struct Foundation.Data
import struct Foundation.URL
import class Foundation.JSONEncoder

import struct HTTP.HTTPHeaders
import struct HTTP.HTTPRequest
import enum HTTP.HTTPMethod

extension CircleCi {

    enum Error: LocalizedError {
        case noChannel(String)
        case noBranch(String)
        case unknownCommand(String)
        case unknownApp(String)
        case unknownType(String)
        case noProject(String)
        case invalidDeployCombination(String)
        case decode
        case badResponse(String?)
        case underlying(Swift.Error)
        
        public var errorDescription: String? {
            switch self {
            case .noChannel(let name): return "No project found (channel: \(name))"
            case .unknownCommand(let text): return "Unknown command (\(text))"
            case .noBranch(let string): return "No branch found (\(string))"
            case .unknownApp(let text): return "Unknown app (\(text))"
            case .unknownType(let text): return "Unknown type (\(text))"
            case .noProject(let text): return "No project (\(text))"
            case .invalidDeployCombination(let text): return "Invalid deploy combination: (\(text))"
            case .decode: return "Decode error"
            case .badResponse(let message): return "CircleCi message: \"\(message ?? "")\""
            case .underlying(let error):
                return (error as? LocalizedError).map { $0.localizedDescription } ?? "Unknown error (\(error))"
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

protocol CircleCiJob: TokenRequestable {
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

extension CircleCiJob {
    var method: HTTPMethod? { return .POST }
    
    var body: Data? {
        return try? JSONEncoder().encode(["build_parameters": buildParameters])
    }
    
    func url(token: String) -> URL? {
        return URL(string: "https://circleci.com/"
            + CircleCi.path(project, urlEncodedBranch)
            + "?circle-token=\(token)")
    }
    
    func headers(token: String) -> [(String, String)] {
        return [
            ("Accept", "application/json"),
            ("Content-Type", "application/json")
        ]
    }
}

enum CircleCiJobKind: String, CaseIterable {
    case deploy
    case test
    case buildsim
}

private extension CircleCiJobKind {
    var type: CircleCiJob.Type {
        switch self {
        case .deploy:
            return CircleCiDeployJob.self
        case .test:
            return CircleCiTestJob.self
        case .buildsim:
            return CircleCiBuildsimJob.self
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

struct CircleCiBuildsimJob: CircleCiJob, Equatable {
    let name: String = CircleCiJobKind.buildsim.rawValue
    let project: String
    let branch: String
    let options: [String]
    let username: String
}

extension CircleCiBuildsimJob {
    var slackResponseFields: [Slack.Response.Field] {
        return [
            Slack.Response.Field(title: "Project", value: project, short: true),
            Slack.Response.Field(title: "Branch", value: branch, short: true),
            Slack.Response.Field(title: "User", value: username, short: true)
        ]
    }
    
    static var helpResponse: Slack.Response {
        let text = "`buildsim`: build a simulator app from a branch\n" +
            "Usage:\n`/cci buildsim branch [options]`\n" +
            "  - *branch*: branch name to build app from\n" +
            "  - *options*: optional fastlane options in the xyz:qwo format\n" +
            "  (currently there are no options for this job)"
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
            return .left(CircleCiBuildsimJob.helpResponse)
        }
        let branch = parameters[0]
        return .right(CircleCiBuildsimJob(project: project, branch: branch, options: options, username: username))
        
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
    private enum App: String, CaseIterable {
        case fourd
        case mi

        func branch(for deployType: DeployType) throws -> String {
            switch (self, deployType) {
            case (_, .alpha): return "dev"
            case (.fourd, .beta): return "fourd"
            case (.fourd, .appStore): return "release"
            case (.mi, .beta): return "mi"
            default: throw CircleCi.Error.invalidDeployCombination("\(self.rawValue) - \(deployType)")
            }
        }
        
        var projectName: String {
            switch self {
            case .fourd: return "FourDMotion"
            case .mi: return "MotionInsights"
            }
        }
    }

    private enum DeployType: String {
        case alpha
        case beta
        case appStore = "app_store"
    }

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
            "Usage:\n`/cci deploy app type [options] [branch]`\n" +
            "  - *type*: alpha|beta|app_store\n" +
            "  - *app*: fourd|mi\n" +
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

        var options = options
        let branch: String
        let type: String
        if project == "4dmotion-ios" {
            guard let appRaw = parameters[safe: 0], let app = App(rawValue: appRaw) else {
                throw CircleCi.Error.unknownApp(parameters.joined(separator: " "))
            }
            
            guard let deployTypeRaw = parameters[safe: 1], let deployType = DeployType(rawValue: deployTypeRaw) else {
                throw CircleCi.Error.unknownType(parameters.joined(separator: " "))
            }
            
            let isSingleProject: Bool
            // If building from a custom branch, build only the selected app
            if let customBranch = parameters[safe: 2] {
                branch = customBranch
                isSingleProject = true
                options += ["use_git:false"]
            } else {
                branch = try app.branch(for: deployType)
                isSingleProject = deployType == .alpha
            }
            
            type = deployType.rawValue
            options += ["branch:\(branch)"]
            if isSingleProject {
                options += ["project_name:\(app.projectName)"]
            } else {
                // If not building a single app, then start with the one specified
                var apps = App.allCases.filter { $0 != app }
                apps.insert(app, at: 0)
                let appNames = apps.map { $0.projectName }.joined(separator: ",")
                options += ["project_names:\(appNames)"]
            }
        } else {
            // For other (not 4d projects)
            let types = [
                "alpha": "dev",
                "beta": "master",
                "app_store": "release"]
            if parameters.isEmpty || !types.keys.contains(parameters[0]) {
                throw CircleCi.Error.unknownType(parameters.joined(separator: " "))
            }
            type = parameters[0]
            guard let b = parameters[safe: 1] ?? types[type] else {
                throw CircleCi.Error.noBranch(parameters.joined(separator: " "))
            }
            
            branch = b
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
        let vcs = Environment.get(JobRequest.Config.vcs)!
        let company = Environment.get(JobRequest.Config.company)!
        return "/api/v1.1/project/\(vcs)/\(company)/\(project)/tree/\(branch)"
    }
    
    static var helpResponse: Slack.Response {
        let text = "Help:\n- `/cci command [help]`\n" +
            "Current command\n" +
            "  - help: show this message\n" +
            "  - deploy: deploy a build\n" +
            "  - test: test a branch\n" +
            "  - buildsim: build a simulator app from a branch\n\n" +
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
                             _ headers: Headers?,
                             _ context: Context) -> EitherIO<Slack.Response, JobRequest> {
        let projects: [String] = Environment.getArray(JobRequest.Config.projects)
        
        guard let index = projects.index(where: { from.channelName.hasPrefix($0) }) else {
            return leftIO(context)(Slack.Response.error(Error.noChannel(from.channelName)))
        }
        let project = projects[index]
        
        var parameters = from.text.split(separator: " ").map(String.init).filter({ !$0.isEmpty })
        guard !parameters.isEmpty else {
            return leftIO(context)(Slack.Response.error(Error.unknownCommand(from.text)))
        }
        let command = parameters[0]
        parameters.removeFirst()
        
        let isOption: (String) -> Bool = { $0.contains(":") }
        let options = parameters.filter(isOption)
        parameters = parameters.filter { !isOption($0) }
        
        if let job = CircleCiJobKind(rawValue: command) {
            do {
                let request = try job.type
                    .parse(project: project,
                           parameters: parameters,
                           options: options,
                           username: from.userName)
                    .map { JobRequest(job: $0) }
                return pure(request, context)
            } catch {
                return leftIO(context)(Slack.Response.error(Error.underlying(error),
                                                            helpResponse: job.type.helpResponse))
            }
        } else if command == "help" {
            return leftIO(context)(helpResponse)
        } else {
            return leftIO(context)(Slack.Response.error(Error.unknownCommand(from.text)))
        }
    }
    
    static func apiWithSlack(_ context: Context)
        -> (JobRequest)
        -> EitherIO<Slack.Response, BuildResponse> {
            return { jobRequest -> EitherIO<Slack.Response, BuildResponse> in
                do {
                    let projects: [String] = Environment.getArray(JobRequest.Config.projects)
                    let circleCiTokens = Environment.getArray(JobRequest.Config.tokens)
                    guard let index = projects.index(of: jobRequest.job.project) else {
                        throw Error.noProject(jobRequest.job.project)
                    }
                    let circleciToken = circleCiTokens[index]

                    return try Service.fetch(jobRequest.job, Response.self, circleciToken, context, Environment.api)
                        .map { response in
                            guard let value = response.value else {
                                throw Error.decode
                            }
                            return .right(BuildResponse(response: value, job: jobRequest.job))
                        }
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
                              _ headers: Headers?,
                              _ context: Context) -> EitherIO<Github.PayloadResponse, JobRequest> {
        let defaultResponse: EitherIO<Github.PayloadResponse, JobRequest> = leftIO(context)(Github.PayloadResponse())
        guard let type = from.type(headers: headers), let repo = from.repository?.name else {
            return defaultResponse
        }
        switch type {
        case let .pullRequestLabeled(label: Github.waitingForReviewLabel, head: head, base: base):
            do {
                if Github.isMaster(branch: base) || Github.isRelease(branch: base) {
                    return try CircleCiTestJob.parse(project: repo,
                                                     parameters: [head.ref],
                                                     options: ["restrict_fixme_comments:true"],
                                                     username: "cci")
                        .either({ _ in return defaultResponse }, { rightIO(context)(JobRequest(job: $0)) })
                } else {
                    guard let installationId = from.installation?.id else {
                        return defaultResponse
                    }
                    let githubRequest = Github.APIRequest(installationId: installationId,
                                                          type: .getStatus(sha: head.sha, url: head.repo.url))
                    return try Github.fetchAccessToken(installationId, context)
                        .flatMap {
                            return try Service.fetch(githubRequest, [Github.Status].self, $0, context, Environment.api)
                        }
                        .flatMap { response in
                            guard let statuses = response.value, statuses.first?.state != .success else {
                                return defaultResponse
                            }
                            return try CircleCiTestJob.parse(project: repo,
                                                             parameters: [head.ref],
                                                             options: [],
                                                             username: "cci")
                                .either({ _ in return defaultResponse }, { rightIO(context)(JobRequest(job: $0)) })
                        }
                }
            } catch {
                return defaultResponse
            }
        default: return defaultResponse
        }
    }
    
    static func slackToGithubResponse(_ response: Slack.Response) -> Github.PayloadResponse {
        return Github.PayloadResponse(value: response.attachments.first?.fallback)
    }

}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
