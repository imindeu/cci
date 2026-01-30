import Foundation

import Foundation

public enum Github {
    public enum Error: LocalizedError {
        case signature
        case jwt
        case accessToken
        case installation
        case underlying(Swift.Error)
        
        public var errorDescription: String? {
            switch self {
            case .signature: return "Bad github webhook signature"
            case .jwt: return "JWT token problem"
            case .accessToken: return "Bad github access token"
            case .installation: return "No installation"
            case .underlying(let error):
                return (error as? LocalizedError).map { $0.localizedDescription } ?? "Unknown error (\(error))"
            }
        }
    }
    
    public enum Url {
        public static let base = URL(string: "https://api.github.com")!
        public static let organisation = "imindeu"
        public static let ios = base
            .appendingPathComponent(Path.repos.rawValue)
            .appendingPathComponent(organisation)
            .appendingPathComponent(Repository.ios.rawValue)
        public static let android = base
            .appendingPathComponent(Path.repos.rawValue)
            .appendingPathComponent(organisation)
            .appendingPathComponent(Repository.android.rawValue)
        public static let search = base
            .appendingPathComponent(Path.search.rawValue)

        public enum Repository: String {
            case ios = "4dmotion-ios"
            case android = "4dmotion-android"
        }
    }
    
    public enum Path: String, Sendable {
        case commits
        case issues
        case labels
        case pulls
        case repos
        case search
        case statuses
    }
    
    public struct Payload: Equatable, Codable, Sendable {
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
    
    public struct PullRequest: Equatable, Codable, Sendable {
        public enum State: String, Codable, Sendable {
            case open, closed, all
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case issueId = "number"
            case state
            case title
            case body
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case mergedAt = "merged_at"
            case draft
            case head
            case base
            case labels
            case url
        }
        
        public let id: Int
        public let issueId: Int
        public let state: State
        public let title: String
        public let body: String?
        public let createdAt: Date
        public let updatedAt: Date
        public let mergedAt: Date
        public let draft: Bool
        public let head: Branch
        public let base: Branch
        public let labels: [Label]
        public let url: String
        
        public init(
            id: Int,
            issueId: Int,
            state: Github.PullRequest.State,
            title: String,
            body: String? = nil,
            createdAt: Date,
            updatedAt: Date,
            mergedAt: Date,
            draft: Bool,
            head: Github.Branch,
            base: Github.Branch,
            labels: [Github.Label],
            url: String
        ) {
            self.id = id
            self.issueId = issueId
            self.state = state
            self.title = title
            self.body = body
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.mergedAt = mergedAt
            self.draft = draft
            self.head = head
            self.base = base
            self.labels = labels
            self.url = url
        }
    }
    
    public struct Repository: Equatable, Codable, Sendable {
        public let name: String
        public let url: String
        
        public init(name: String, url: String) {
            self.name = name
            self.url = url
        }
    }
    
    public struct User: Equatable, Codable, Sendable {
        public let login: String
        
        public init(login: String) {
            self.login = login
        }
    }
    
    public struct Branch: Equatable, Codable, Sendable {
        public let ref: String
        public let sha: String
        public let repo: Repository
        
        public init(ref: String, sha: String, repo: Repository) {
            self.ref = ref
            self.sha = sha
            self.repo = repo
        }
    }
    
    public struct Label: Equatable, Codable, Sendable {
        public let name: String
        
        public init(name: String) {
            self.name = name
        }
    }
    
    public struct Commit: Equatable, Codable, Sendable {
        public let sha: String
        
        public init(sha: String) {
            self.sha = sha
        }
    }
    
    public struct IssueComment: Equatable, Codable, Sendable {
        public let body: String
        
        public init(body: String) {
            self.body = body
        }
    }
    
    public struct Link: Equatable, Codable, Sendable {
        public let href: String
        
        public init(href: String) {
            self.href = href
        }
    }

    public struct Links: Equatable, Codable, Sendable {
        public let comments: Link
        
        public init(comments: Link) {
            self.comments = comments
        }
    }
    
    public struct Installation: Equatable, Codable, Sendable {
        public let id: Int
        
        public init(id: Int) {
            self.id = id
        }
    }
    
    public enum ReviewState: String, Equatable, Codable, Sendable {
        case commented
        case changesRequested = "changes_requested"
        case approved
        case dismissed
    }
    
    public struct Review: Equatable, Codable, Sendable {
        public let state: ReviewState
        
        public init(state: ReviewState) {
            self.state = state
        }
    }
    
    public struct Status: Equatable, Codable, Sendable {
        public let state: State
        
        public init(state: State) {
            self.state = state
        }
    }

    public enum Action: String, Equatable, Codable, Sendable {
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
    
    public enum State: String, Equatable, Codable, Sendable {
        case pending
        case error
        case failure
        case success
    }
    
    public enum RefType: String, Equatable, Codable, Sendable {
        case branch
        case tag
        case repository
    }
    
    public enum Event: String, Equatable, Codable, Sendable {
        case create
        case push
        case pullRequest = "pull_request"
        case status
        case pullRequestReview = "pull_request_review"
    }
    
}

public extension Github {
    
    enum APIErrorCode: String, Equatable, Codable {
        case missing
        case missingField = "missing_field"
        case invalid
        case alreadyExists = "already_exists"
    }
    
    struct APIError: Equatable, Codable {
        public let resource: String?
        public let field: String?
        public let code: APIErrorCode?
        
        public init(resource: String? = nil, field: String? = nil, code: APIErrorCode? = nil) {
            self.resource = resource
            self.field = field
            self.code = code
        }
    }
    
    struct APIResponse: Equatable, Codable {
        public let message: String?
        public let errors: [APIError]?
        
        public init(message: String? = nil, errors: [APIError]? = nil) {
            self.message = message
            self.errors = errors
        }
    }

}

public extension Github {
    struct SearchResponse<A: Codable & Equatable>: Equatable, Codable {
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

    struct SearchIssue: Equatable, Codable {
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
