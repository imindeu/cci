//
//  Circleci.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import Foundation
import Vapor

protocol Circleci: Content {
    associatedtype Element
    static func request(from: Element) -> HTTPRequest
    static func response(from: Self, with: Element) -> SlackResponseRepresentable
}

extension Circleci {
    static func fetch(worker: Worker, with: Element) -> Future<SlackResponseRepresentable> {
        return HTTPClient.connect(scheme: .https, hostname: "circleci.com", port: nil, on: worker)
            .flatMap { $0.send(request(from: with)) }
            .map { response -> Self in
                if let deployResponse = try response.body.data.map { try JSONDecoder().decode(Self.self, from: $0) } {
                    return deployResponse
                } else {
                    throw CircleciError.decodeError
                }
            }
            .map { response(from: $0, with: with) }
            .catchMap { CircleciError.fetchError(error: $0) }
    }
}

enum CircleciError: Error {
    case fetchError(error: Error)
    case decodeError
}

extension CircleciError: SlackResponseRepresentable {
    var slackResponse: SlackResponse {
        switch self {
        case .fetchError(let error):
            return SlackResponse.error(text: "Fetch error \(error)")
        case .decodeError:
            return SlackResponse.error(text: "Decode error")
        }
    }
}

struct CircleciDeploy: Content {
    let build_url: String
    let build_num: Int
}

extension CircleciDeploy: Circleci {
    
    static func response(from: CircleciDeploy, with deploy: Command.Deploy) -> SlackResponseRepresentable {
        let fallback = "Deploy has started at <\(from.build_url)|\(from.build_num)>. " +
            "(project: \(deploy.project), type: \(deploy.type), branch: \(deploy.branch), version: \(deploy.version ?? ""), groups: \(deploy.groups ?? ""), emails: \(deploy.emails ?? "") "
        var fields = [
            SlackResponse.Field(title: "Project", value: deploy.project, short: true),
            SlackResponse.Field(title: "Type", value: deploy.type, short: true),
            ]
        if let version = deploy.version {
            fields.append(SlackResponse.Field(title: "Version", value: version, short: true))
        }
        if let groups = deploy.groups {
            fields.append(SlackResponse.Field(title: "Groups", value: groups, short: false))
        }
        if let emails = deploy.emails {
            fields.append(SlackResponse.Field(title: "Emails", value: emails, short: false))
        }
        let attachment = SlackResponse.Attachment(
            fallback: fallback,
            text: "Deploy has started at <\(from.build_url)|\(from.build_num)>.",
            color: "#764FA5",
            mrkdwn_in: ["text", "fields"],
            fields: fields)
        return SlackResponse(responseType: .inChannel, text: nil, attachments: [attachment], mrkdwn: true)
    }
    
    static func request(from deploy: Command.Deploy) -> HTTPRequest {
        let environment = AppEnvironment.current
        var request = HTTPRequest.init()
        request.method = .POST
        var params: [String] = [
            "build_parameters[CIRCLE_JOB]=deploy",
            "build_paramaters[TYPE]=\(deploy.type)",
            "circle-token=\(environment.circleciToken)"
        ]
        if let version = deploy.version {
            params.append("build_parameters[NEW_VERSION]=\(version)")
        }
        if let groups = deploy.groups {
            params.append("build_parameters[GROUPS]=\(groups)")
        }
        if let emails = deploy.emails {
            params.append("build_parameters[EMAILS]=\(emails)")
        }
        request.urlString = "/api/v1.1/project/\(environment.vcs)/\(environment.company)/\(deploy.project)/tree/\(deploy.branch)?\(params.joined(separator: "&"))"
        print("urlString: \(request.urlString)")
        request.headers = HTTPHeaders([("Accept", "application/json")])
        return request
    }
}

