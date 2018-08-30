//
//  Circleci.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import Foundation
import Vapor

enum CircleciError: Error {
    case parse(helpResponse: SlackResponse, text: String)
    case fetch(helpResponse: SlackResponse, error: Error)
    case decode(helpResponse: SlackResponse)
    case encode(helpResponse: SlackResponse, error: Error)
}

extension CircleciError: SlackResponseRepresentable {
    var slackResponse: SlackResponse {
        switch self {
        case .fetch(let helpResponse, let error):
            return SlackResponse.error(helpResponse: helpResponse, text: "Fetch error \(error)")
        case .decode(let helpResponse):
            return SlackResponse.error(helpResponse: helpResponse, text: "Decode error")
        case .parse(let helpResponse, let text):
            return SlackResponse.error(helpResponse: helpResponse, text: "Parse error \(text)")
        case .encode(let helpResponse, let error):
            return SlackResponse.error(helpResponse: helpResponse, text: "Encode error \(error)")
        }
    }
}

protocol CircleciRequest: HelpResponse {
    associatedtype Response: CircleciResponse
    
    var request: Either<SlackResponseRepresentable, HTTPRequest> { get }
    func slackResponse(response: Response) -> SlackResponse
    static func parse(project: String, parameters: [String], options:[String], username: String) throws -> Self
}

extension CircleciRequest {
    func fetch(worker: Worker) -> Future<SlackResponseRepresentable> {
        let badRequest: (SlackResponseRepresentable) -> Future<SlackResponseRepresentable> = { response in
            return Future.map(on: worker, { return response })
        }
        let goodRequest: (HTTPRequest) -> Future<SlackResponseRepresentable> = { request in
            return Environment.current.circleci(worker, request)
                .map { response -> Response in
                    if let deployResponse = try response.body.data.map { try JSONDecoder().decode(Response.self, from: $0) } {
                        return deployResponse
                    } else {
                        throw CircleciError.decode(helpResponse: Self.helpResponse)
                    }
                }
                .map { self.slackResponse(response: $0) }
                .catchMap {
                    CircleciError.fetch(helpResponse: Self.helpResponse, error: $0)
                }
        }
        return request.either(badRequest, goodRequest)

    }

}

protocol CircleciJobRequest: CircleciRequest {
    var name: String { get }
    var project: String { get }
    var branch: String { get }
    var options: [String] { get }
    var username: String { get }
    
    var buildParameters: [String : String] { get }
    var slackResponseFields: [SlackResponse.Field] { get }
}

extension CircleciJobRequest {
    var urlEncodedBranch: String {
        return branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? branch
    }
    
    var request: Either<SlackResponseRepresentable, HTTPRequest> {
        let environment = Environment.current
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
            return .left(CircleciError.encode(
                helpResponse: Self.helpResponse,
                error: error))
        }
    }

    func slackResponse(response: CircleciBuildResponse) -> SlackResponse {
        let fallback = "Job '\(name)' has started at <\(response.build_url)|#\(response.build_num)>. " +
        "(project: \(project), branch: \(branch)"
        var fields = slackResponseFields
        options.forEach { option in
            let array = option.split(separator: ":").map(String.init)
            if array.count == 2 {
                fields.append(SlackResponse.Field(title: array[0], value: array[1], short: true))
            }
        }
        let attachment = SlackResponse.Attachment(
            fallback: fallback,
            text: "Job '\(name)' has started at <\(response.build_url)|#\(response.build_num)>.",
            color: "#764FA5",
            mrkdwn_in: ["text", "fields"],
            fields: fields)
        return SlackResponse(response_type: .inChannel, text: nil, attachments: [attachment], mrkdwn: true)
    }

}

struct CircleciTestJobRequest {
    let name: String = "test"
    let project: String
    let branch: String
    let options: [String]
    let username: String
}

extension CircleciTestJobRequest: CircleciJobRequest {
    
    var buildParameters: [String: String] {
        return ["DEPLOY_OPTIONS": options.joined(separator: " ")]
    }
    
    var slackResponseFields: [SlackResponse.Field] {
        return [
            SlackResponse.Field(title: "Project", value: project, short: true),
            SlackResponse.Field(title: "Branch", value: branch, short: true),
            SlackResponse.Field(title: "User", value: username, short: true)
        ]
    }

    static func parse(project: String, parameters: [String], options: [String], username: String) throws -> CircleciTestJobRequest {
        
        guard parameters.count > 0 else {
            throw CircleciError.parse(helpResponse: CircleciTestJobRequest.helpResponse, text: "No branch")
        }
        let branch = parameters[0]
        return CircleciTestJobRequest(project: project, branch: branch, options: options, username: username)
    }
    
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
    
}

struct CircleciDeployJobRequest {
    let name: String = "deploy"
    let project: String
    let branch: String
    let options: [String]
    let username: String
    let type: String
    
}

extension CircleciDeployJobRequest: CircleciJobRequest {

    var buildParameters: [String: String] {
        return [
            "DEPLOY_TYPE": type,
            "DEPLOY_OPTIONS": options.joined(separator: " ")
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

    static func parse(project: String, parameters: [String], options: [String], username: String) throws -> CircleciDeployJobRequest {
        let types = [
            "alpha": "dev",
            "beta": "master",
            "app_store": "release"]
        if parameters.count == 0 || !types.keys.contains(parameters[0]) {
            throw CircleciError.parse(helpResponse: CircleciDeployJobRequest.helpResponse, text: "Unknown type: (\(parameters.joined(separator: " ")))")
        }
        let type = parameters[0]
        guard let branch = parameters[safe: 1] ?? types[type] else {
            throw CircleciError.parse(helpResponse: CircleciDeployJobRequest.helpResponse, text: "No branch found: (\(parameters.joined(separator: " ")))")
        }
        return CircleciDeployJobRequest(project: project, branch: branch, options: options, username: username, type: type)
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

extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
