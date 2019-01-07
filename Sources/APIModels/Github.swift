//
//  Github.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

public enum Github {
    public struct Payload: Equatable, Codable {
        public let action: Action?
        public let review: Review?
        public let pullRequest: PullRequest?
        public let label: Label?
        public let ref: String?
        public let refType: RefType?
        public let installation: Installation?
        public let repository: Repository?
        public let commit: Commit?
        public let state: State?
        
        public init(action: Action? = nil,
                    review: Review? = nil,
                    pullRequest: PullRequest? = nil,
                    label: Label? = nil,
                    ref: String? = nil,
                    refType: RefType? = nil,
                    installation: Installation? = nil,
                    repository: Repository? = nil,
                    commit: Commit? = nil,
                    state: State? = nil) {
            self.action = action
            self.review = review
            self.pullRequest = pullRequest
            self.label = label
            self.ref = ref
            self.refType = refType
            self.installation = installation
            self.repository = repository
            self.commit = commit
            self.state = state
        }
        
        enum CodingKeys: String, CodingKey {
            case action, review, label, ref, installation, repository, commit, state
            case pullRequest = "pull_request"
            case refType = "ref_type"
        }
    }
    
    public struct PullRequest: Equatable, Codable {
        public let url: String
        public let id: Int
        public let title: String
        public let body: String
        public let head: Branch
        public let base: Branch
        public let assignees: [User]
        public let requestedReviewers: [User]

        public init(url: String,
                    id: Int,
                    title: String,
                    body: String,
                    head: Branch,
                    base: Branch,
                    assignees: [User] = [],
                    requestedReviewers: [User] = []) {
            self.url = url
            self.id = id
            self.title = title
            self.body = body
            self.head = head
            self.base = base
            self.assignees = assignees
            self.requestedReviewers = requestedReviewers
        }
        
        enum CodingKeys: String, CodingKey {
            case url, id, title, body, head, base, assignees
            case requestedReviewers = "requested_reviewers"
        }
    }
    
    public struct Repository: Equatable, Codable {
        public let name: String
        
        public init(name: String) {
            self.name = name
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
    
    public struct Commit: Equatable, Codable {
        public let sha: String
        
        public init(sha: String) {
            self.sha = sha
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
    
    public enum ReviewState: String, Equatable, Codable {
        case commented
        case changesRequested = "changes_requested"
        case approved
        case dismissed
    }
    
    public struct Review: Equatable, Codable {
        public let state: ReviewState
        
        public init(state: ReviewState) {
            self.state = state
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
        case requestedAction = "requested_action"
        case completed
        case requested
        case added
        case removed
        case transferred
        case pinned
        case unpinned
        case milestoned
        case demilestoned
        case submitted
        case dismissed
        case synchronize
        // ...
    }
    
    public enum State: String, Equatable, Codable {
        case pending
        case error
        case failure
        case success
    }
    
    public enum RefType: String, Equatable, Codable {
        case branch
        case tag
        case repository
    }
    
    public enum Event: String, Equatable, Codable {
        case create
        case pullRequest = "pull_request"
        case status
        case pullRequestReview = "pull_request_review"
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

public extension Github {
    public struct SearchResponse<A: Codable & Equatable>: Equatable, Codable {
        public let message: String?
        public let errors: [APIError]?
        public let items: [A]?
        public let totalCount: Int?
        public let incompleteResults: Bool?
        
        public init(items: [A]) {
            self.items = items
            self.message = nil
            self.errors = nil
            self.totalCount = nil
            self.incompleteResults = nil
        }
        
        enum CodingKeys: String, CodingKey {
            case message, errors, items
            case totalCount = "total_count"
            case incompleteResults = "incomplete_results"
        }
        
    }

    public struct SearchIssue: Equatable, Codable {
        public struct PullRequest: Equatable, Codable {
            public let url: String?
            
            public init(url: String) {
                self.url = url
            }
        }
        
        public let pullRequest: PullRequest?
        
        public init(pullRequest: PullRequest) {
            self.pullRequest = pullRequest
        }
        
        enum CodingKeys: String, CodingKey {
            case pullRequest = "pull_request"
        }
    }
}
