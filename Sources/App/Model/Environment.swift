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
    
    static func empty() -> Environment {
        return Environment(circleciToken: "", slackToken: "", company: "", vcs: "", projects: [])
    }
}

enum AppEnvironmentError: Error {
    case noCircleciToken
    case noSlackToken
    case noCompany
    case noVcs
    case noProjects
    case wrongSlackToken
}

extension AppEnvironmentError: SlackResponseRepresentable {
    var slackResponse: SlackResponse {
        switch self {
        case .noCircleciToken:
            return SlackResponse.error(text: "Error: no circleciToken found")
        case .noSlackToken:
            return SlackResponse.error(text: "Error: no slackToken found")
        case .noCompany:
            return SlackResponse.error(text: "Error: no company found")
        case .noVcs:
            return SlackResponse.error(text: "Error: no vcs found")
        case .noProjects:
            return SlackResponse.error(text: "Error: no projects found")
        case .wrongSlackToken:
            return SlackResponse.error(text: "Error: wrong slackToken")
        }
    }
}

final class AppEnvironment {
    private static var stack: [Environment] = []

    static var current: Environment {
        if stack.isEmpty {
            stack.append(Environment.empty())
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
        replaceCurrent(Environment(circleciToken: circleciToken, slackToken: slackToken, company: company, vcs: vcs, projects: projects))

    }
}
