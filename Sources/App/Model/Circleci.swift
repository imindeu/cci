//
//  Circleci.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import Foundation
import Vapor

enum CircleciDeployResponseError: Error {
    case fetchError(error: Error)
    case decodeError
}

extension CircleciDeployResponseError: SlackResponseRepresentable {
    var slackResponse: SlackResponse {
        switch self {
        case .fetchError(let error):
            return SlackResponse.error(text: "Fetch error \(error)")
        case .decodeError:
            return SlackResponse.error(text: "Decode error")
        }
        
    }
}

struct CircleciDeployResponse: Content {
    let build_url: String
    let build_num: Int
}

extension CircleciDeployResponse {
    
    static func fetch(worker: Worker, deploy: Deploy) -> Future<SlackResponseRepresentable> {
        return HTTPClient.connect(scheme: .https, hostname: "circleci.com", port: nil, on: worker)
            .flatMap { $0.send(request(deploy: deploy)) }
            .map { response -> CircleciDeployResponse in
                if let deployResponse = try response.body.data.map { try JSONDecoder().decode(CircleciDeployResponse.self, from: $0) } {
                    return deployResponse
                } else {
                    throw CircleciDeployResponseError.decodeError
                }
            }.map { deployResponse -> SlackResponseRepresentable in
                let fallback = "Deploy has started at <\(deployResponse.build_url)|\(deployResponse.build_num)>. (project: \(deploy.project), type: \(deploy.type), branch: \(deploy.branch), version: \(deploy.version ?? ""), groups: \(deploy.groups ?? ""), emails: \(deploy.emails ?? "") "
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
                    text: "Deploy has started at <\(deployResponse.build_url)|\(deployResponse.build_num)>.",
                    color: "#764FA5",
                    mrkdwn_in: ["text", "fields"],
                    fields: fields)
                return SlackResponse(responseType: .inChannel, text: nil, attachments: [attachment], mrkdwn: true)
            }
            .catchMap { CircleciDeployResponseError.fetchError(error: $0) }
    }
    
    private static func request(deploy: Deploy) -> HTTPRequest {
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

