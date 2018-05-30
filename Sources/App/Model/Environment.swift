//
//  Environment.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import Foundation
import Vapor

struct Environment {
    let circleciToken: String
    let slackToken: String
    let company: String
    let vcs: String
    let projects: [String]
    let circleci: (Worker, HTTPRequest) -> Future<HTTPResponse>
    let slack: (Worker, URL, SlackResponseRepresentable) -> Future<HTTPResponse>
    
    static let emptyApi: (Worker) -> Future<HTTPResponse> = { worker in
        return Future.map(on: worker, { return HTTPResponse() })
    }

    static let api: (String) -> (Worker, HTTPRequest) -> Future<HTTPResponse> = { hostname in
        return { worker, request in
            return HTTPClient
                .connect(scheme: .https, hostname: hostname, port: nil, on: worker)
                .flatMap { $0.send(request) }
        }
    }
    
    static var empty: Environment {
        return Environment(
            circleciToken: "",
            slackToken: "",
            company: "",
            vcs: "",
            projects: [],
            circleci: { worker, _ in return Environment.emptyApi(worker) },
            slack: { worker, _, _ in return Environment.emptyApi(worker) }
        )
    }
}

enum AppEnvironmentError: Error {
    case noCircleciToken
    case noSlackToken
    case noCompany
    case noVcs
    case noProjects
}

final class AppEnvironment {
    private static var stack: [Environment] = []

    static var current: Environment {
        if stack.isEmpty {
            stack.append(Environment.empty)
        }
        return stack.last!
    }

    
    static func push(_ env: Environment) {
        stack.append(env)
    }
    
    @discardableResult
    static func pop() -> Environment? {
        let last = stack.popLast()
        return last
    }
    
    static func replaceCurrent(_ env: Environment) {
        push(env)
        if stack.count >= 2 {
            stack.remove(at: stack.count - 2)
        }
    }

    static func fromVapor() throws {
        guard let circleciToken = Vapor.Environment.get("circleciToken") else {
            throw AppEnvironmentError.noCircleciToken
        }
        guard let slackToken = Vapor.Environment.get("slackToken") else {
            throw AppEnvironmentError.noSlackToken
        }
        guard let company = Vapor.Environment.get("company") else {
            throw AppEnvironmentError.noCompany
        }
        guard let vcs = Vapor.Environment.get("vcs") else {
            throw AppEnvironmentError.noVcs
        }
        guard let projects = Vapor.Environment.get("projects")?.split(separator: ",").map(String.init) else {
            throw AppEnvironmentError.noProjects
        }

        let circleci: (Worker, HTTPRequest) -> Future<HTTPResponse> = Environment.api("circleci.com")

        let slack: (Worker, URL, SlackResponseRepresentable) -> Future<HTTPResponse> = {
            worker, url, response in
            if let hostname = url.host,
                let body = try? JSONEncoder().encode(response.slackResponse) {
                
                let api = Environment.api(hostname)
                var request = HTTPRequest.init()
                request.method = .POST
                request.urlString = url.path
                request.body = HTTPBody(data: body)
                request.headers = HTTPHeaders([
                    ("Content-Type", "application/json")
                    ])
                return api(worker, request)
            } else {
                return Environment.emptyApi(worker)
            }
        }
        
        replaceCurrent(Environment(circleciToken: circleciToken,
                                   slackToken: slackToken,
                                   company: company,
                                   vcs: vcs,
                                   projects: projects,
                                   circleci: circleci,
                                   slack: slack))

    }
}
