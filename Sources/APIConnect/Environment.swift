//
//  Environment.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

import HTTP

public struct Environment {
    public var api: (String) -> (Context, HTTPRequest) -> IO<HTTPResponse> = { hostname in
        return { context, request in
            return HTTPClient
                .connect(scheme: .https, hostname: hostname, port: nil, on: context)
                .flatMap { $0.send(request) }
        }
    }
    
    public var emptyApi: (Context) -> IO<HTTPResponse> = { pure(HTTPResponse(), $0) }
    
    public static var env: [String: String] = ProcessInfo.processInfo.environment
    
    public static func get<A: Configuration>(_ key: A) -> String? {
        return env[key.rawValue]
    }
    
}
