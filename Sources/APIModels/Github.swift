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
        public let label: Label?
        public let ref: String?
        public let refType: RefType?
        public let installation: Installation?
        
        public init(action: Action? = nil,
                    pullRequest: PullRequest? = nil,
                    label: Label? = nil,
                    ref: String? = nil,
                    refType: RefType? = nil,
                    installation: Installation? = nil) {
            self.action = action
            self.pullRequest = pullRequest
            self.label = label
            self.ref = ref
            self.refType = refType
            self.installation = installation
        }
        
        enum CodingKeys: String, CodingKey {
            case action
            case pullRequest = "pull_request"
            case label
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
        public let assignees: [User]
        public let requestedReviewers: [User]
        public let links: Links

        public init(id: Int,
                    title: String,
                    head: Branch,
                    base: Branch,
                    assignees: [User] = [],
                    requestedReviewers: [User] = [],
                    links: Links) {
            self.id = id
            self.title = title
            self.head = head
            self.base = base
            self.assignees = assignees
            self.requestedReviewers = requestedReviewers
            self.links = links
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case head
            case base
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
    
    public struct Link: Equatable, Codable {
        public let href: String
        
        public init(href: String) {
            self.href = href
        }
    }

    public struct Links: Equatable, Codable {
        public let comments: Link
        
        public init(comments: Link) {
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
        case edited
        case closed
        case reopened
        case labeled
        case unlabeled
        case assigned
        case unassigned
        case reviewRequested = "review_requested"
        case reviewRequestRemoved = "review_request_removed"
        case created
        case deleted
        case rerequested
        case rerequestedAction = "requested_action"
        case completed
        case requested
        case added
        case removed
        case transferred
        case pinned
        case unpinned
        case milestoned
        case demilestoned
        // ...
    }
    
    public enum RefType: String, Equatable, Codable {
        case branch
    }
    
    public enum Event: String, Equatable, Codable {
        case create
        case pullRequest = "pull_request"
    }
    
}

public extension Github {
    
    public enum APIErrorCode: String, Equatable, Codable {
        case missing
        case missingField = "missing_field"
        case invalid
        case alreadyExists = "already_exists"
    }
    
    public struct APIError: Equatable, Codable {
        public let resource: String?
        public let field: String?
        public let code: APIErrorCode?
        
        public init(resource: String? = nil, field: String? = nil, code: APIErrorCode? = nil) {
            self.resource = resource
            self.field = field
            self.code = code
        }
    }
    
    public struct APIResponse: Equatable, Codable {
        public let message: String?
        public let errors: [APIError]?
        
        public init(message: String? = nil, errors: [APIError]? = nil) {
            self.message = message
            self.errors = errors
        }
    }

}
