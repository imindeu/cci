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
    associatedtype Response: CircleciResponse
    
    var request: Either<SlackResponseRepresentable, HTTPRequest> { get }
    func slackResponse(response: Response) -> SlackResponse
    static func parse(project: String, words: [String], username: String) throws -> Self
}

extension CircleciRequest {
    func fetch(worker: Worker) -> Future<SlackResponseRepresentable> {
        let badRequest: (SlackResponseRepresentable) -> Future<SlackResponseRepresentable> = { response in
            return Future.map(on: worker, { return response })
        }
        let goodRequest: (HTTPRequest) -> Future<SlackResponseRepresentable> = { request in
            return AppEnvironment.current.circleci(worker, request)
                .map { response -> Response in
                    if let deployResponse = try response.body.data.map { try JSONDecoder().decode(Response.self, from: $0) } {
                        return deployResponse
                    } else {
                        throw CircleciError.decodeError(helpResponse: Self.helpResponse)
                    }
                }
                .map { self.slackResponse(response: $0) }
                .catchMap {
                    CircleciError.fetchError(helpResponse: Self.helpResponse, error: $0)
            }
        }
        return request.either(badRequest, goodRequest)

    }

}

protocol CircleciJobRequest: CircleciRequest {
    var name: String { get }
    var project: String { get }
    var branch: String { get }
    var username: String { get }
    
    var buildParameters: [String: String] { get }
    var slackResponseFields: [SlackResponse.Field] { get }
}

extension CircleciJobRequest {
    var urlEncodedBranch: String {
        return branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? branch
    }
    
    var request: Either<SlackResponseRepresentable, HTTPRequest> {
        let environment = AppEnvironment.current
        var request = HTTPRequest.init()
        request.method = .POST
        var copy = buildParameters
        copy["CIRCLE_JOB"] = name
        
        request.urlString = "/api/v1.1/project/\(environment.vcs)/\(environment.company)/\(project)/tree/\(urlEncodedBranch)?circle-token=\(environment.circleciToken)"
        
        do {
            let body = try JSONEncoder().encode(["build_parameters": copy])
            request.body = HTTPBody(data: body)
            request.headers = HTTPHeaders([
                ("Accept", "application/json"),
                ("Content-Type", "application/json")
                ])
            return .right(request)
        } catch let error {
            return .left(CircleciError.fetchError(
                helpResponse: Self.helpResponse,
                error: error))
        }
    }

    func slackResponse(response: CircleciBuildResponse) -> SlackResponse {
        let fallback = "Job '\(name)' has started at <\(response.build_url)|#\(response.build_num)>. " +
        "(project: \(project), branch: \(branch)"
        let attachment = SlackResponse.Attachment(
            fallback: fallback,
            text: "Job '\(name)' has started at <\(response.build_url)|#\(response.build_num)>.",
            color: "#764FA5",
            mrkdwn_in: ["text", "fields"],
            fields: slackResponseFields)
        return SlackResponse(response_type: .inChannel, text: nil, attachments: [attachment], mrkdwn: true)
    }

}

struct CircleciTestJobRequest {
    let name: String = "test"
    let project: String
    let branch: String
    let username: String
}

extension CircleciTestJobRequest: CircleciJobRequest {
    
    var buildParameters: [String: String] { return [:] }
    
    var slackResponseFields: [SlackResponse.Field] {
        return [
            SlackResponse.Field(title: "Project", value: project, short: true),
            SlackResponse.Field(title: "Branch", value: branch, short: true),
            SlackResponse.Field(title: "User", value: username, short: true)
        ]
    }

    static func parse(project: String, words: [String], username: String) throws -> CircleciTestJobRequest {
        
        guard words.count > 0 else {
            throw CircleciError.parseError(helpResponse: CircleciTestJobRequest.helpResponse, text: "No branch")
        }
        let branch = words[0]
        return CircleciTestJobRequest(project: project, branch: branch, username: username)
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
    let name: String = "deploy"
    let project: String
    let branch: String
    let username: String
    let type: String
    let version: String?
    let groups: String?
    let emails: String?
    
}

extension CircleciDeployJobRequest: CircleciJobRequest {

    var buildParameters: [String: String] {
        var buildParameters: [String: String] = [
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
        return buildParameters
    }
    
    var slackResponseFields: [SlackResponse.Field] {
        var fields = [
            SlackResponse.Field(title: "Project", value: project, short: true),
            SlackResponse.Field(title: "Type", value: type, short: true),
            SlackResponse.Field(title: "User", value: username, short: true)
            ]
        if let version = version {
            fields.append(SlackResponse.Field(title: "Version", value: version, short: true))
        }
        if let groups = groups {
            fields.append(SlackResponse.Field(title: "Groups", value: groups, short: false))
        }
        if let emails = emails {
            fields.append(SlackResponse.Field(title: "Emails", value: emails, short: false))
        }

        return fields
    }

    static func parse(project: String, words: [String], username: String) throws -> CircleciDeployJobRequest {
        let types = [
            "alpha": "dev",
            "beta": "master",
            "app_store": "release"]
        
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
        return CircleciDeployJobRequest(project: project, branch: branch!, username: username, type: type!, version: version, groups: groups, emails: emails)
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
