//
//  Service.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 08..
//
import protocol APIConnect.Context
import class APIConnect.IO

import protocol Foundation.LocalizedError
import struct Foundation.CharacterSet
import class Foundation.JSONDecoder

import struct HTTP.HTTPBody
import struct HTTP.HTTPHeaders
import struct HTTP.HTTPRequest
import struct HTTP.HTTPResponse

public typealias API = (String, Int?) -> (Context, HTTPRequest) -> IO<HTTPResponse>

public enum Service {
    public enum Error: LocalizedError {
        case noMethod
        case noURL
        case badUrl(String)
        
        public var errorDescription: String? {
            switch self {
            case .noMethod: return "Type doesn't have a method"
            case .noURL: return "Type doesn't have an url"
            case .badUrl(let url): return "Bad url (\(url))"
            }
        }
    }

    public static func fetch<A: Decodable>(_ request: TokenRequestable,
                                           _ responseType: A.Type,
                                           _ token: String,
                                           _ context: Context,
                                           _ api: @escaping API) throws -> TokenedIO<A?> {
        guard let method = request.method else {
            throw Error.noMethod
        }
        guard let url = request.url(token: token) else {
            throw Error.noURL
        }
        guard let host = url.host,
            let path = url.path
                .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else {
                    throw Error.badUrl(url.absoluteString)
        }
        
        let httpRequest = HTTPRequest(method: method,
                                      url: path + (url.query.map { "?\($0)" } ?? ""),
                                      headers: HTTPHeaders(request.headers(token: token)),
                                      body: request.body ?? HTTPBody())
        
        return api(host, url.port)(context, httpRequest)
            .decode(responseType)
            .map { Tokened(token, $0) }
    }
}

extension IO where T == HTTPResponse {
    func decode<A: Decodable>(_ type: A.Type) -> IO<A?> {
        return map { response -> A? in
            guard let data = response.body.data else { return nil }
            return try JSONDecoder().decode(type, from: data)
        }
    }
}
