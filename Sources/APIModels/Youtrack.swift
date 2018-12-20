//
//  Youtrack.swift
//  APIModels
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 20..
//

public enum Youtrack {
    
    public struct Response: Equatable, Codable {
        public let value: String?
        
        public init (value: String? = nil) {
            self.value = value
        }
    }

}
