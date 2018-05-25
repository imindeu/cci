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
    
    static var empty: Environment {
        return Environment(
            circleciToken: "",
            slackToken: "",
            company: "",
            vcs: "",
            projects: [],
            circleci: { worker, _ in
                return Future.map(on: worker, { return HTTPResponse() })
            }
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
        let circleci: (Worker, HTTPRequest) -> Future<HTTPResponse> = { worker, request in
            return HTTPClient
                .connect(scheme: .https, hostname: "circleci.com", port: nil, on: worker)
                .flatMap { $0.send(request) }
        }
        replaceCurrent(Environment(circleciToken: circleciToken, slackToken: slackToken, company: company, vcs: vcs, projects: projects, circleci: circleci))

    }
}
