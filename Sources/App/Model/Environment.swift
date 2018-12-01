//
//  Environment.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

import APIConnect
import HTTP

public struct Environment: APIConnectEnvironment {
    public static var api: (String, Int?) -> (Context, HTTPRequest) -> IO<HTTPResponse> = { hostname, port in
        return { context, request in
            return HTTPClient
                .connect(scheme: .https, hostname: hostname, port: port, on: context)
                .flatMap { $0.send(request) }
        }
    }
    
    public static var emptyApi: (Context) -> IO<HTTPResponse> = { pure(HTTPResponse(), $0) }
    
    public static var env: [String: String] = ProcessInfo.processInfo.environment
    
}
