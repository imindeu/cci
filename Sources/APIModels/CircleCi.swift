//
//  CircleCi.swift
//  APIModels
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

public struct CircleCiResponse: Equatable, Codable {
    public let buildURL: String
    public let buildNum: Int
    
    public init(buildURL: String, buildNum: Int) {
        self.buildURL = buildURL
        self.buildNum = buildNum
    }
    
    enum CodingKeys: String, CodingKey {
        case buildURL = "build_url"
        case buildNum = "build_num"
    }
}
