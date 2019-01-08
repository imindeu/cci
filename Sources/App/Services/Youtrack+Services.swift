//
//  Youtrack+Services.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//
import APIConnect
import APIModels

import HTTP
import Core

extension Youtrack {
    static func path(base: String, issue: String) -> String {
        if base.hasSuffix("/") {
            return "\(base)issue/\(issue)"
        }
        return "\(base)/issue/\(issue)"
    }
    
    static func issues(from: String, pattern: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        return regex.matches(in: from, options: [], range: NSRange(from.startIndex..., in: from))
            .compactMap { Range($0.range, in: from).map { String(from[$0]) } }
    }
    
    static func issueURLs(from: String, base: String?, pattern: String) throws -> [String] {
        return try base
            .map { url in
                try issues(from: from, pattern: pattern)
                    .map {
                        path(base: url, issue: $0).replacingOccurrences(of: "/rest", with: "")
                    }
            } ?? []
    }
}
