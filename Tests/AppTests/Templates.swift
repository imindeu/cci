//
//  Templates.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

import APIConnect
import APIModels

import Foundation
import NIO

@testable import App

extension Dictionary: Headers where Key == String, Value == String {
    public func get(_ name: String) -> String? { return self[name] }
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
        sha: String = "sha",
        repo: Github.Repository = Github.Repository.template())
        -> Github.Branch {
            
        return Github.Branch(ref: ref, sha: sha, repo: repo)
    }
}

extension Github.Repository {
    static func template(
        name: String = "repo",
        url: String = "https://test.com/repos/company/project"
    ) -> Github.Repository {
        .init(name: name, url: url)
    }
}

extension Github.PullRequest {
    static func template(
        id: Int = 0,
        issueId: Int = 0,
        state: State = .open,
        title: String = "title",
        body: String = "body",
        updatedAt: Date = .init(),
        head: Github.Branch,
        base: Github.Branch,
        url: String = "https://test.com/repos/company/project"
    ) -> Github.PullRequest {
        .init(
            id: id,
            issueId: issueId,
            state: state,
            title: title,
            body: body,
            createdAt: .init(),
            updatedAt: updatedAt,
            mergedAt: .init(),
            draft: false,
            head: head,
            base: base,
            labels: [],
            url: url
        )
    }
}
