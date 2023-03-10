//
//  Circleci.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import Foundation
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

    struct JobTriggerRequest: RequestModel {
        typealias ResponseModel = JobTriggerResponse
        
        enum Config: String, Configuration {
            case tokens = "circleCiTokens"
            case company = "circleCiCompany"
            case vcs = "circleCiVcs"
            case projects = "circleCiProjects"
        }
        
        let request: CircleCiJobTriggerRequest
    }
    
    struct JobTriggerResponse {
        let responseObject: CircleCi.JobTrigger.Response
        let request: CircleCiJobTriggerRequest
    }
}

extension CircleCi.JobTrigger.Response {
    func url(project: CircleCiProject) -> URL? {
        guard
            let vcs = Environment.get(CircleCi.JobTriggerRequest.Config.vcs),
            let company = Environment.get(CircleCi.JobTriggerRequest.Config.company)
        else {
            return nil
        }

        return URL(string: "https://app.circleci.com/pipelines/\(vcs)/\(company)/\(project.rawValue)/\(self.number ?? 0)")
    }
}

enum CircleCiProject: RawRepresentable, Equatable {
    case iOS4DM
    case android4DM
    case unknown(String)
    
    var rawValue: String {
        switch self {
        case .iOS4DM: return "4dmotion-ios"
        case .android4DM: return "4dmotion-android"
        case let .unknown(rawValue): return rawValue
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "4dmotion-ios": self = .iOS4DM
        case "4dmotion-android": self = .android4DM
        default: self = .unknown(rawValue)
        }
    }
    
    static func == (lhs: CircleCiProject, rhs: CircleCiProject) -> Bool {
        switch (lhs, rhs) {
        case (.iOS4DM, .iOS4DM), (.android4DM, .android4DM): return true
        case let (.unknown(lrw), .unknown(rrw)): return lrw == rrw
        default: return false
        }
    }
}

// The `project` param is parsed from the `circleCiProjects` Docker's param:
// - matching the prefix of the slack command's channel.
// - accessed via Environment
// - this identifies the project on Circle CI
protocol CircleCiRequest: TokenRequestable {
    var project: CircleCiProject { get }
    var method: HTTPMethod? { get }
    var body: Data? { get }
    
    func url(token: String) -> URL?
    func headers(token: String) -> [(String, String)]
}

extension CircleCiRequest {
    func headers(token: String) -> [(String, String)] {
        return [("Content-Type", "application/json"), ("Circle-Token", token)]
    }
}

struct CircleCiJobInfoRequest: CircleCiRequest {
    let project: CircleCiProject
    let jobNumber: Int
    let method: HTTPMethod? = .GET
    let body: Data? = nil
    
    func url(token: String) -> URL? {
        guard
            let vcs = Environment.get(CircleCi.JobTriggerRequest.Config.vcs),
            let company = Environment.get(CircleCi.JobTriggerRequest.Config.company)
        else {
            return nil
        }

        return URL(string: "https://circleci.com/api/v2/project/\(vcs)/\(company)/\(project.rawValue)/job/\(jobNumber)")
    }
}

protocol CircleCiJobTriggerRequest: CircleCiRequest {
    var branch: String { get }
    var name: String { get }
    var type: String { get }
    var options: [String] { get }
    var username: String { get }
    
    var slackResponseFields: [Slack.Response.Field] { get }

    static func parse(project: CircleCiProject, parameters: [String], options: [String], username: String) throws
        -> Either<Slack.Response, CircleCiJobTriggerRequest>
    
    static var helpResponse: Slack.Response { get }
}

struct CircleCiJobTriggerRequestBody: Codable, Equatable {
    struct Parameters: Codable, Equatable {
        let job: String
        let deploy_type: String
        let options: String
    }
    
    let branch: String
    let parameters: Parameters
}

extension CircleCiJobTriggerRequest {
    var method: HTTPMethod? { return .POST }
    
    var urlEncodedBranch: String {
        return branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? branch
    }
    
    var body: Data? {
        return try? JSONEncoder().encode(
            CircleCiJobTriggerRequestBody(
                branch: branch,
                parameters: .init(
                    job: name,
                    deploy_type: type,
                    options: options.joined(separator: " ")
                )
            )
        )
    }
    
    func url(token: String) -> URL? {
        guard
            let vcs = Environment.get(CircleCi.JobTriggerRequest.Config.vcs),
            let company = Environment.get(CircleCi.JobTriggerRequest.Config.company)
        else {
            return nil
        }
                
        return URL(string: "https://circleci.com/api/v2/project/\(vcs)/\(company)/\(project.rawValue)/pipeline")
    }
}

enum CircleCiJobKind: String, CaseIterable {
    case deploy
    case test
    case buildsim
}

private extension CircleCiJobKind {
    var type: CircleCiJobTriggerRequest.Type {
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

struct CircleCiTestJob: CircleCiJobTriggerRequest, Equatable {
    let project: CircleCiProject
    let branch: String
    let name: String = CircleCiJobKind.test.rawValue
    let type: String = ""
    let options: [String]
    let username: String
}

extension CircleCiTestJob {
    var slackResponseFields: [Slack.Response.Field] {
        return [
            Slack.Response.Field(title: "Project", value: project.rawValue, short: true),
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
    
    static func parse(project: CircleCiProject,
                      parameters: [String],
                      options: [String],
                      username: String) throws -> Either<Slack.Response, CircleCiJobTriggerRequest> {
        
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

struct CircleCiBuildsimJob: CircleCiJobTriggerRequest, Equatable {
    let project: CircleCiProject
    let branch: String
    let name: String = CircleCiJobKind.buildsim.rawValue
    let type: String = ""
    let options: [String]
    let username: String
}

extension CircleCiBuildsimJob {
    var slackResponseFields: [Slack.Response.Field] {
        return [
            Slack.Response.Field(title: "Project", value: project.rawValue, short: true),
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
    
    static func parse(project: CircleCiProject,
                      parameters: [String],
                      options: [String],
                      username: String) throws -> Either<Slack.Response, CircleCiJobTriggerRequest> {
        
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

struct CircleCiDeployJob: CircleCiJobTriggerRequest, Equatable {
    let project: CircleCiProject
    let branch: String
    let name: String = CircleCiJobKind.deploy.rawValue
    let type: String
    let options: [String]
    let username: String
}

extension CircleCiDeployJob {
    private enum App: String, CaseIterable {
        case fourd
        case mi
        case oc
        case sp

        func branch(for deployType: DeployType) throws -> String {
            switch (self, deployType) {
            case (_, .alpha): return "dev"
            case (.fourd, .beta): return "fourd"
            case (.fourd, .appStore): return "release"
            case (.mi, .beta): return "mi"
            case (.oc, .beta): return "oc"
            case (.oc, .appStore): return "release_oc"
            case (.sp, .beta): return "sp"
            case (.sp, .appStore): return "release_sp"
            default: throw CircleCi.Error.invalidDeployCombination("\(self.rawValue) - \(deployType)")
            }
        }
        
        func projectName(for project: CircleCiProject) throws -> String {
            switch (project, self) {
            case (.iOS4DM, .fourd): return "FourDMotion"
            case (.iOS4DM, .mi): return "MotionInsights"
            case (.iOS4DM, .oc): return "OrthoCor"
            case (.iOS4DM, .sp): return "SinglePlane"
            case (.android4DM, .oc): return "orthocor"
            default: throw CircleCi.Error.invalidDeployCombination("\(self.rawValue) - \(project.rawValue)")
            }
        }
    }

    private enum DeployType: String {
        case alpha
        case beta
        case appStore = "app_store"
    }
    
    var slackResponseFields: [Slack.Response.Field] {
        return [
            Slack.Response.Field(title: "Project", value: project.rawValue, short: true),
            Slack.Response.Field(title: "Type", value: type, short: true),
            Slack.Response.Field(title: "User", value: username, short: true),
            Slack.Response.Field(title: "Branch", value: branch, short: true)
        ]
    }
    
    static var helpResponse: Slack.Response {
        let text = "`deploy`: deploy a build\n" +
            "Usage:\n`/cci deploy app type [options] [branch]`\n" +
            "  - *type*: alpha|beta|app_store\n" +
            "  - *app*: fourd|mi|oc|sp\n" +
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
    
    static func parse(project: CircleCiProject,
                      parameters: [String],
                      options: [String],
                      username: String) throws -> Either<Slack.Response, CircleCiJobTriggerRequest> {
        
        if parameters.count == 1 && parameters[0] == "help" {
            return .left(CircleCiDeployJob.helpResponse)
        }

        var options = options
        let branch: String
        let type: String
        
        switch project {
        case .iOS4DM, .android4DM:
            guard let appRaw = parameters[safe: 0], let app = App(rawValue: appRaw) else {
                throw CircleCi.Error.unknownApp(parameters.joined(separator: " "))
            }
            
            guard let deployTypeRaw = parameters[safe: 1], let deployType = DeployType(rawValue: deployTypeRaw) else {
                throw CircleCi.Error.unknownType(parameters.joined(separator: " "))
            }
            
            if let customBranch = parameters[safe: 2] {
                branch = customBranch
                options += ["test_release:true"]
            } else {
                branch = try app.branch(for: deployType)
            }
            
            type = deployType.rawValue
            options += ["branch:\(branch)"]
            options += ["project_name:\(try app.projectName(for: project))"]
        case .unknown:
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
                                        type: type,
                                        options: options,
                                        username: username))
    }
}

extension CircleCi {
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
                             _ context: Context) -> EitherIO<Slack.Response, JobTriggerRequest> {
        let spacePlaceholderString = "[CCI_SPACE_PLACEHOLDER_STRING]"

        let projects: [String] = Environment.getArray(JobTriggerRequest.Config.projects)
        guard let index = projects.index(where: { from.channelName.hasPrefix($0) }) else {
            return leftIO(context)(Slack.Response.error(Error.noChannel(from.channelName)))
        }

        guard let project = CircleCiProject(rawValue: projects[index]) else {
            return leftIO(context)(Slack.Response.error(Error.noProject(from.channelName)))
        }

        var rawText = from.text
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
        print("rawText: \(rawText)")
        rawText.matchingStrings(regex: "\"(.*?)\"").forEach { textArray in
            if let part = textArray.first {
                let partWithoutSpaces = part.replacingOccurrences(of: " ", with: spacePlaceholderString)
                rawText = rawText.replacingOccurrences(of: part, with: partWithoutSpaces)
            }
        }

        var parameters = rawText.split(separator: " ")
            .map(String.init)
            .map { $0
                    .replacingOccurrences(of: spacePlaceholderString, with: "%20" )
                    .replacingOccurrences(of: "\"", with: "")
            }
            .filter({ !$0.isEmpty })
        
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
                    .map { JobTriggerRequest(request: $0) }
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
        -> (JobTriggerRequest)
        -> EitherIO<Slack.Response, JobTriggerResponse> {
            return { jobRequest -> EitherIO<Slack.Response, JobTriggerResponse> in
                do {
                    let projects: [String] = Environment.getArray(JobTriggerRequest.Config.projects)
                    let circleCiTokens = Environment.getArray(JobTriggerRequest.Config.tokens)
                    guard let index = projects.index(of: jobRequest.request.project.rawValue) else {
                        throw Error.noProject(jobRequest.request.project.rawValue)
                    }
                    let circleciToken = circleCiTokens[index]

                    return try Service.fetch(jobRequest.request, JobTrigger.Response.self, circleciToken, context, Environment.api, isDebugMode: Environment.isDebugMode())
                        .map { jobTriggerResponse in
                            guard let jobTriggerResponseObject = jobTriggerResponse.value else {
                                throw Error.decode
                            }
                            
                            return .right(JobTriggerResponse(responseObject: jobTriggerResponseObject, request: jobRequest.request))
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
    
    static func responseToSlack(_ from: JobTriggerResponse) -> Slack.Response {
        guard let buildNum = from.responseObject.number else {
            return Slack.Response.error(Error.badResponse(from.responseObject.message))
        }
        
        let request = from.request
        let buildURL = from.responseObject.url(project: request.project)?.absoluteString ?? "N/A"
        let fallback = "Job '\(request.name)' has started at <\(buildURL)|#\(buildNum)>. " +
        "(project: \(request.project), branch: \(request.branch))"
        var fields = request.slackResponseFields
        request.options.forEach { option in
            let array = option.split(separator: ":").map(String.init)
            if array.count == 2 {
                fields.append(Slack.Response.Field(title: array[0], value: array[1], short: true))
            }
        }
        let attachment = Slack.Response.Attachment(
            fallback: fallback,
            text: "Job '\(request.name)' has started at <\(buildURL)|#\(buildNum)>.",
            color: "#764FA5",
            mrkdwnIn: ["text", "fields"],
            fields: fields)
        
        if Environment.isDebugMode() {
            print("\n\n ==================== ")
            print(" RESPONSE TO SLACK\n")
            print("\(from)\n")
            print("\(attachment)\n")
        }
        
        return Slack.Response(responseType: .inChannel, text: nil, attachments: [attachment], mrkdwn: true)
    }

    // MARK: Github
    static func githubRequest(_ from: Github.Payload,
                              _ headers: Headers?,
                              _ context: Context) -> EitherIO<Github.PayloadResponse, JobTriggerRequest> {
        let defaultResponse: EitherIO<Github.PayloadResponse, JobTriggerRequest> = leftIO(context)(Github.PayloadResponse())
        guard
            let type = from.type(headers: headers),
            let repo = from.repository?.name,
            let project = CircleCiProject(rawValue: repo)
        else {
            return defaultResponse
        }
        
        switch type {
        case let .pullRequestLabeled(label: Github.waitingForReviewLabel, head: head, base: base, platform: platform):
            do {
                if Github.isMaster(branch: base) || Github.isRelease(branch: base) {
                    return try CircleCiTestJob.parse(project: project,
                                                     parameters: [head.ref],
                                                     options: ["restrict_fixme_comments:true"],
                                                     username: "cci")
                        .either({ _ in return defaultResponse }, { rightIO(context)(JobTriggerRequest(request: $0)) })
                } else {
                    guard let installationId = from.installation?.id else {
                        return defaultResponse
                    }
                    let githubRequest = Github.APIRequest(installationId: installationId,
                                                          type: .getStatus(sha: head.sha, url: head.repo.url))
                    return try Github.fetchAccessToken(installationId, context)
                        .flatMap {
                            return try Service.fetch(githubRequest, [Github.Status].self, $0, context, Environment.api, isDebugMode: Environment.isDebugMode())
                        }
                        .flatMap { response in
                            guard let statuses = response.value, statuses.first?.state != .success else {
                                return defaultResponse
                            }
                            return try CircleCiTestJob.parse(project: project,
                                                             parameters: [head.ref],
                                                             options: [],
                                                             username: "cci")
                                .either({ _ in return defaultResponse }, { rightIO(context)(JobTriggerRequest(request: $0)) })
                        }
                }
            } catch {
                return defaultResponse
            }
        case let .pullRequestClosed(_, _, base: base, merged: merged, platform: platform) where Github.isMain(branch: base) && merged:
            do {
                let options = Github.isMaster(branch: base) || Github.isRelease(branch: base)
                    ? ["restrict_fixme_comments:true"] : []
                return try CircleCiTestJob.parse(project: project,
                                                 parameters: [base.ref],
                                                 options: options,
                                                 username: "cci")
                .either({ _ in return defaultResponse }, { rightIO(context)(JobTriggerRequest(request: $0)) })
            } catch {
                return defaultResponse
            }
        case let .branchPushed(branch) where Github.isMain(branch: branch):
            do {
                let options = Github.isMaster(branch: branch) || Github.isRelease(branch: branch)
                    ? ["restrict_fixme_comments:true"] : []
                return try CircleCiTestJob.parse(project: project,
                                                 parameters: [branch.ref],
                                                 options: options,
                                                 username: "cci")
                .either({ _ in return defaultResponse }, { rightIO(context)(JobTriggerRequest(request: $0)) })
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

extension String {
    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
}
