//
//  CircleCi.swift
//  APIModels
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

public enum CircleCi {

    public enum JobTrigger {
        public struct Response: Equatable, Codable {
            public let number: Int?
            public let state: String?
            public let createdAt: String?
            public let message: String?
            
            enum CodingKeys: String, CodingKey {
                case number
                case state
                case createdAt = "created_at"
                case message
            }
        }
    }
    
    public enum JobInfo {
        public struct Response: Equatable, Codable {
            public let url: String?
            public let message: String?
            
            enum CodingKeys: String, CodingKey {
                case url = "web_url"
                case message
            }
        }
    }
}
