//
//  Templates.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

import APIConnect
import APIModels

import NIO

@testable import App

extension Dictionary: Headers where Key == String, Value == String {
    public func get(_ name: String) -> String? { return self[name] }
}

func context() -> Context {
    return MultiThreadedEventLoopGroup(numberOfThreads: 1)
}

extension Slack.Request {
    static func template(token: String = "",
                         teamId: String = "",
                         teamDomain: String = "",
                         enterpriseId: String? = nil,
                         enterpriseName: String? = nil,
                         channelId: String = "",
                         channelName: String = "",
                         userId: String = "",
                         userName: String = "",
                         command: String = "",
                         text: String = "",
                         responseUrlString: String = "",
                         triggerId: String = "") -> Slack.Request {
        return Slack.Request(token: token,
                             teamId: teamId,
                             teamDomain: teamDomain,
                             enterpriseId: enterpriseId,
                             enterpriseName: enterpriseName,
                             channelId: channelId,
                             channelName: channelName,
                             userId: userId,
                             userName: userName,
                             command: command,
                             text: text,
                             responseUrlString: responseUrlString,
                             triggerId: triggerId)
    }
}

extension Github.Branch {
    static func template(
        ref: String = "dev",
        repo: Github.Repository = Github.Repository.template())
        -> Github.Branch {
            
        return Github.Branch(ref: ref, repo: repo)
    }
}

extension Github.Repository {
    static func template(name: String = "repo",
                         url: String = "https://test.com/repos/company/project")
        -> Github.Repository {
            
        return Github.Repository(name: name, url: url)
    }
}
