//
//  Github.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

public struct GithubWebhookRequest: Equatable, Codable {
    public let action: String?
    public let pullRequest: PullRequest?
    public let ref: String?
    public let refType: String?
    
    public init(action: String?, pullRequest: PullRequest?, ref: String?, refType: String?) {
        self.action = action
        self.pullRequest = pullRequest
        self.ref = ref
        self.refType = refType
    }

    public struct PullRequest: Equatable, Codable {
        public let title: String
        
        public init(title: String) {
            self.title = title
        }
    }

    enum CodingKeys: String, CodingKey {
        case action
        case pullRequest = "pull_request"
        case ref
        case refType = "ref_type"
    }

}
