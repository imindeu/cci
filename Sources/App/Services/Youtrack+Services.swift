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
    
    static func issues(from: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: "4DM-[0-9]+")
        return regex.matches(in: from, options: [], range: NSRange(from.startIndex..., in: from))
            .compactMap { Range($0.range, in: from).map { String(from[$0]) } }
    }
    
    static func issueURLs(from: String, url: String?) throws -> [String] {
        return try url
            .map { url in
                try issues(from: from).map { path(base: url, issue: $0).replacingOccurrences(of: "/rest", with: "") }
            } ?? []
    }
    
    private static func path(base: String, issue: String, command: Request.Command) -> String {
        return path(base: base, issue: issue) + "/execute?command=\(command.rawValue)"
    }
    
    static func fetch(_ context: Context,
                      _ url: URL,
                      _ host: String,
                      _ token: String,
                      _ api: @escaping API)
        -> (Request.RequestData)
        -> EitherIO<Github.PayloadResponse, ResponseContainer> {
            
        return { requestData in
            let headers = HTTPHeaders([
                ("Accept", "application/json"),
                ("Content-Type", "application/json"),
                ("Authorization", "Bearer \(token)")
            ])

            let httpRequest = HTTPRequest(method: .POST,
                                          url: path(base: url.path,
                                                    issue: requestData.issue,
                                                    command: requestData.command),
                                          headers: headers)
            return api(host, url.port)(context, httpRequest)
                .decode(Response.self)
                .map { response in
                    let youtrackResponse = response ?? Response(value: "issue: \(requestData.issue)")
                    return .right(ResponseContainer(response: youtrackResponse, data: requestData))
                }
                .catchMap {
                    return .left(
                        Github.PayloadResponse(
                            value: "issue: \(requestData.issue): " +
                                "\(Error.underlying($0).localizedDescription)"))
                }
        }
    }
}
