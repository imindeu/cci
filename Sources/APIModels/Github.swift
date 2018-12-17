//
//  Github.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

public enum Github {
    public struct Payload: Equatable, Codable {
        public let action: Action?
        public let pullRequest: PullRequest?
        public let ref: String?
        public let refType: RefType?
        public let installation: Installation?
        
        public init(action: Action? = nil,
                    pullRequest: PullRequest? = nil,
                    ref: String? = nil,
                    refType: RefType? = nil,
                    installation: Installation? = nil) {
            self.action = action
            self.pullRequest = pullRequest
            self.ref = ref
            self.refType = refType
            self.installation = installation
        }
        
        enum CodingKeys: String, CodingKey {
            case action
            case pullRequest = "pull_request"
            case ref
            case refType = "ref_type"
            case installation
        }
    }
    
    public struct PullRequest: Equatable, Codable {
        public let id: Int
        public let title: String
        public let head: Branch
        public let base: Branch
        public let label: Label?
        public let assignees: [User]
        public let requestedReviewers: [User]
        public let links: Links

        public init(id: Int,
                    title: String,
                    head: Branch,
                    base: Branch,
                    label: Label? = nil,
                    assignees: [User] = [],
                    requestedReviewers: [User] = [],
                    links: Links) {
            self.id = id
            self.title = title
            self.head = head
            self.base = base
            self.label = label
            self.assignees = assignees
            self.requestedReviewers = requestedReviewers
            self.links = links
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case head
            case base
            case label
            case assignees
            case requestedReviewers = "requested_reviewers"
            case links = "_links"
        }
    }
    
    public struct User: Equatable, Codable {
        public let login: String
        
        public init(login: String) {
            self.login = login
        }
    }
    
    public struct Branch: Equatable, Codable {
        public let ref: String
        
        public init(ref: String) {
            self.ref = ref
        }
    }
    
    public struct Label: Equatable, Codable {
        public let name: String
        
        public init(name: String) {
            self.name = name
        }
    }
    
    public struct IssueComment: Equatable, Codable {
        public let body: String
        
        public init(body: String) {
            self.body = body
        }
    }

    public struct Links: Equatable, Codable {
        public let comments: String
        
        public init(comments: String) {
            self.comments = comments
        }
    }
    
    public struct Installation: Equatable, Codable {
        public let id: Int
        
        public init(id: Int) {
            self.id = id
        }
    }

    public enum Action: String, Equatable, Codable {
        case opened
        case closed
        case labeled
        case unlabeled
    }
    
    public enum RefType: String, Equatable, Codable {
        case branch
    }
    
    public enum Event: String, Equatable, Codable {
        case create
        case pullRequest = "pull_request"
    }
}
