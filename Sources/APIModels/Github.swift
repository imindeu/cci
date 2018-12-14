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
        
        public init(action: Action?, pullRequest: PullRequest?, ref: String?, refType: RefType?) {
            self.action = action
            self.pullRequest = pullRequest
            self.ref = ref
            self.refType = refType
        }
        
        enum CodingKeys: String, CodingKey {
            case action
            case pullRequest = "pull_request"
            case ref
            case refType = "ref_type"
        }
    }
    
    public struct PullRequest: Equatable, Codable {
        public let id: Int
        public let title: String
        public let head: Branch
        public let base: Branch
        public let labels: [Label]
        
        public init(id: Int, title: String, head: Branch, base: Branch, labels: [Label] = []) {
            self.id = id
            self.title = title
            self.head = head
            self.base = base
            self.labels = labels
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
