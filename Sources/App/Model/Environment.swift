//
//  Environment.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//

import Foundation
import Vapor

struct Environment {
    // MARK: - Environment
    let circleciTokens: [String]
    let slackToken: String
    let company: String
    let vcs: String
    let circleciPath: (String, String) -> String
    let projects: [String]
    let circleci: (Worker, HTTPRequest) -> Future<HTTPResponse>
    let slack: (Worker, URL, SlackResponseRepresentable) -> Future<HTTPResponse>

    static let api: (String) -> (Worker, HTTPRequest) -> Future<HTTPResponse> = { hostname in
        return { worker, request in
            return HTTPClient
                .connect(scheme: .https, hostname: hostname, port: nil, on: worker)
                .flatMap { $0.send(request) }
        }
    }
    
    // MARK: - Empty
    static let emptyApi: (Worker) -> Future<HTTPResponse> = { worker in
        return Future.map(on: worker, { return HTTPResponse() })
    }
    
    static let goodApi: (String) -> (Worker, HTTPRequest) -> Future<HTTPResponse> = { body in
        return { worker, _ in
            return Future.map(on: worker, {
                return HTTPResponse(
                    status: .ok,
                    version: HTTPVersion.init(major: 1, minor: 1),
                    headers: HTTPHeaders([]),
                    body: body)
            })
        }
    }

    static var empty: Environment {
        return Environment(
            circleciTokens: [],
            slackToken: "",
            company: "",
            vcs: "",
            circleciPath: { _, _ in return "" },
            projects: [],
            circleci: { worker, _ in return Environment.emptyApi(worker) },
            slack: { worker, _, _ in return Environment.emptyApi(worker) }
        )
    }

    // MARK: - Current
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

    // MARK: - Vapor
    enum Error: Swift.Error {
        case noCircleciTokens
        case noSlackToken
        case noCompany
        case noVcs
        case noProjects
        case wrongCircleciTokenProjectCount
    }
    
    static func fromVapor() throws {
        guard let circleciTokens = Vapor.Environment.get("circleciToken")?.split(separator: ",").map(String.init) else {
            throw Error.noCircleciTokens
        }
        guard let slackToken = Vapor.Environment.get("slackToken") else {
            throw Error.noSlackToken
        }
        guard let company = Vapor.Environment.get("company") else {
            throw Error.noCompany
        }
        guard let vcs = Vapor.Environment.get("vcs") else {
            throw Error.noVcs
        }
        guard let projects = Vapor.Environment.get("projects")?.split(separator: ",").map(String.init) else {
            throw Error.noProjects
        }
        if projects.count != circleciTokens.count {
            throw Error.wrongCircleciTokenProjectCount
        }

        let circleciPath: (String, String) -> String = { project, branch in
            let index = projects.index(of: project)! // TODO: catch forced unwrap
            let circleciToken = circleciTokens[index]
            return "/api/v1.1/project/\(vcs)/\(company)/\(project)/tree/\(branch)?circle-token=\(circleciToken)"
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
        
        replaceCurrent(Environment(circleciTokens: circleciTokens,
                                   slackToken: slackToken,
                                   company: company,
                                   vcs: vcs,
                                   circleciPath: circleciPath,
                                   projects: projects,
                                   circleci: circleci,
                                   slack: slack))

    }
}
