//
//  Circleci.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import Foundation
import Vapor

enum CircleciError: Error {
    case parseError(helpResponse: SlackResponse, text: String)
    case fetchError(helpResponse: SlackResponse, error: Error)
    case decodeError(helpResponse: SlackResponse)
}

extension CircleciError: SlackResponseRepresentable {
    var slackResponse: SlackResponse {
        switch self {
        case .fetchError(let helpResponse, let error):
            return SlackResponse.error(helpResponse: helpResponse, text: "Fetch error \(error)")
        case .decodeError(let helpResponse):
            return SlackResponse.error(helpResponse: helpResponse, text: "Decode error")
        case .parseError(let helpResponse, let text):
            return SlackResponse.error(helpResponse: helpResponse, text: "Parse error \(text)")
        }
    }
}

protocol CircleciRequest: HelpResponse {
    static func parse(channel: String, words: [String]) throws -> Self
    func request() throws -> HTTPRequest
}

protocol CircleciJobRequest: CircleciRequest {}

struct CircleciTestJobRequest {
    let project: String
    let branch: String
}

extension CircleciTestJobRequest: CircleciJobRequest {
    
    func request() throws -> HTTPRequest {
        let environment = AppEnvironment.current
        var request = HTTPRequest.init()
        request.method = .POST
        let buildParameters: [String:String] = [
            "CIRCLE_JOB": "test"
        ]
        
        request.urlString = "/api/v1.1/project/\(environment.vcs)/\(environment.company)/\(project)/tree/\(branch)?circle-token=\(environment.circleciToken)"
        
        let body = try JSONEncoder().encode(["build_parameters": buildParameters])
        request.body = HTTPBody(data: body)
        request.headers = HTTPHeaders([
            ("Accept", "application/json"),
            ("Content-Type", "application/json")
            ])
        return request
    }
    
    static func parse(channel: String, words: [String]) throws -> CircleciTestJobRequest {
        let projects = AppEnvironment.current.projects
        
        guard let index = projects.index(where: { channel.hasPrefix($0) }) else {
            throw CircleciError.parseError(helpResponse: CircleciTestJobRequest.helpResponse, text: "No channel: (\(channel))")
        }
        guard words.count > 0 else {
            throw CircleciError.parseError(helpResponse: CircleciTestJobRequest.helpResponse, text: "No branch")
        }
        let project = projects[index]
        let branch = words[0]
        return CircleciTestJobRequest(project: project, branch: branch)
    }
    
    static var helpResponse: SlackResponse {
        let text = "`test`: test a branch\n" +
            "Usage:\n`/cci test branch`\n"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
    }
}

struct CircleciDeployJobRequest {
    let project: String
    let type: String
    let branch: String
    let version: String?
    let groups: String?
    let emails: String?
    
}

extension CircleciDeployJobRequest: CircleciJobRequest {
    
    func request() throws -> HTTPRequest {
        let environment = AppEnvironment.current
        var request = HTTPRequest.init()
        request.method = .POST
        var buildParameters: [String:String] = [
            "CIRCLE_JOB": "deploy",
            "DEPLOY_TYPE": type
        ]
        if let version = version {
            buildParameters["DEPLOY_VERSION"] = version
        }
        if let groups = groups {
            buildParameters["DEPLOY_GROUPS"] = groups
        }
        if let emails = emails {
            buildParameters["DEPLOY_EMAILS"] = emails
        }
        
        request.urlString = "/api/v1.1/project/\(environment.vcs)/\(environment.company)/\(project)/tree/\(branch)?circle-token=\(environment.circleciToken)"
        
        let body = try JSONEncoder().encode(["build_parameters": buildParameters])
        request.body = HTTPBody(data: body)
        request.headers = HTTPHeaders([
            ("Accept", "application/json"),
            ("Content-Type", "application/json")
            ])
        return request
    }
    
    static func parse(channel: String, words: [String]) throws -> CircleciDeployJobRequest {
        let projects = AppEnvironment.current.projects
        
        guard let index = projects.index(where: { channel.hasPrefix($0) }) else {
            throw CircleciError.parseError(helpResponse: CircleciDeployJobRequest.helpResponse, text: "No channel: (\(channel))")
        }
        let project = projects[index]
        
        let types = [
            "alpha": "dev",
            "beta": "master",
            "app_store": "master"]
        
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
            throw CircleciError.parseError(helpResponse: CircleciDeployJobRequest.helpResponse, text: "No type: (\(words.joined(separator: " ")))")
        }
        return CircleciDeployJobRequest(project: project, type: type!, branch: branch!, version: version, groups: groups, emails: emails)
    }

    static var helpResponse: SlackResponse {
        let text = "`deploy`: deploy a build\n" +
            "Usage:\n`/cci deploy type [version] [emails] [groups]`\n" +
            "   - *type*: alpha|beta|app_store\n" +
            "   - *version*: next version number (2.0.1)\n" +
            "   - *emails*: coma separated spaceless list of emails to send to (xy@imind.eu,zw@test.com)\n" +
            "   - *groups*: coma separated spaceless list of groups to send to (qa,beta-customers)\n\n" +
        "   If emails and groups are both set, emails will be used"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
    }
}

protocol CircleciResponse: Content {}

struct CircleciBuildResponse: CircleciResponse {
    let build_url: String
    let build_num: Int
}

protocol Circleci {
    associatedtype Request: CircleciRequest
    associatedtype Response: CircleciResponse

    static func slackResponse(request: Request, response: Response) -> SlackResponse
}

extension Circleci {
    static func fetch(worker: Worker, request: Request) -> Future<SlackResponseRepresentable> {
        return HTTPClient.connect(scheme: .https, hostname: "circleci.com", port: nil, on: worker)
            .flatMap { $0.send(try request.request()) }
            .map { response -> Response in
                if let deployResponse = try response.body.data.map { try JSONDecoder().decode(Response.self, from: $0) } {
                    return deployResponse
                } else {
                    throw CircleciError.decodeError(helpResponse: Request.helpResponse)
                }
            }
            .map { slackResponse(request: request, response: $0) }
            .catchMap { CircleciError.fetchError(helpResponse: Request.helpResponse, error: $0) }
    }
}

struct CircleciDeploy: Circleci {
    static func slackResponse(request: CircleciDeployJobRequest, response: CircleciBuildResponse) -> SlackResponse {
        let fallback = "Deploy has started at <\(response.build_url)|#\(response.build_num)>. " +
        "(project: \(request.project), type: \(request.type), branch: \(request.branch), version: \(request.version ?? ""), groups: \(request.groups ?? ""), emails: \(request.emails ?? "") "
        var fields = [
            SlackResponse.Field(title: "Project", value: request.project, short: true),
            SlackResponse.Field(title: "Type", value: request.type, short: true),
            ]
        if let version = request.version {
            fields.append(SlackResponse.Field(title: "Version", value: version, short: true))
        }
        if let groups = request.groups {
            fields.append(SlackResponse.Field(title: "Groups", value: groups, short: false))
        }
        if let emails = request.emails {
            fields.append(SlackResponse.Field(title: "Emails", value: emails, short: false))
        }
        let attachment = SlackResponse.Attachment(
            fallback: fallback,
            text: "Deploy has started at <\(response.build_url)|#\(response.build_num)>.",
            color: "#764FA5",
            mrkdwn_in: ["text", "fields"],
            fields: fields)
        return SlackResponse(response_type: .inChannel, text: nil, attachments: [attachment], mrkdwn: true)
    }
}

struct CircleciTest: Circleci {
    static func slackResponse(request: CircleciTestJobRequest, response: CircleciBuildResponse) -> SlackResponse {
        let fallback = "Test has started at <\(response.build_url)|#\(response.build_num)>. " +
        "(project: \(request.project), branch: \(request.branch)"
        let fields = [
            SlackResponse.Field(title: "Project", value: request.project, short: true),
            SlackResponse.Field(title: "Branch", value: request.branch, short: true),
            ]
        let attachment = SlackResponse.Attachment(
            fallback: fallback,
            text: "Test has started at <\(response.build_url)|#\(response.build_num)>.",
            color: "#764FA5",
            mrkdwn_in: ["text", "fields"],
            fields: fields)
        return SlackResponse(response_type: .inChannel, text: nil, attachments: [attachment], mrkdwn: true)
    }
}
