//
//  CircleCi.swift
//  APIModels
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

public struct CircleCiResponse: Equatable, Codable {
    public let buildURL: String?
    public let buildNum: Int?
    public let message: String?
    
    public init(buildURL: String, buildNum: Int) {
        self.buildURL = buildURL
        self.buildNum = buildNum
        self.message = nil
    }
    
    public init(message: String) {
        self.buildURL = nil
        self.buildNum = nil
        self.message = message
    }
    
    enum CodingKeys: String, CodingKey {
        case buildURL = "build_url"
        case buildNum = "build_num"
        case message
    }
}
