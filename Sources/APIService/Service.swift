//
//  Service.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 08..
//
import APIConnect

import protocol Foundation.LocalizedError
import struct Foundation.CharacterSet
import struct Foundation.Data
import struct Foundation.URL
import class Foundation.JSONDecoder

import struct HTTP.HTTPBody
import struct HTTP.HTTPHeaders
import struct HTTP.HTTPRequest
import struct HTTP.HTTPResponse
import enum HTTP.HTTPMethod

public typealias API = (String, Int?) -> (Context, HTTPRequest) -> IO<HTTPResponse>

public protocol TokenRequestable {
    var method: HTTPMethod? { get }
    var body: Data? { get }
    
    func url(token: String) -> URL?
    func headers(token: String) -> [(String, String)]
}

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

public struct Tokened<A> {
    public let token: String
    public let value: A
    
    public init(_ token: String, _ value: A) {
        self.token = token
        self.value = value
    }
}

public typealias TokenedIO<A> = IO<Tokened<A>>

public extension TokenedIO {
    
    public func map<A, B>(_ callback: @escaping (A) throws -> B) -> TokenedIO<B> where T == Tokened<A> {
        return map { tokened in return Tokened(tokened.token, try callback(tokened.value)) }
    }
    
    public func fetch<A: Decodable, B: TokenRequestable>(_ context: Context, _ returnType: A.Type)
        -> TokenedIO<A?> where T == Tokened<B?> {
            
            return self.flatMap { tokened in
                guard let value = tokened.value else { return pure(Tokened<A?>(tokened.token, nil), context) }
                return try Service.fetch(value, returnType, tokened.token, context, Environment.api)
            }
    }
    
    public func fetch<A, B: Decodable, C: TokenRequestable>(_ context: Context,
                                                           _ returnType: B.Type,
                                                           _ type: @escaping (A) -> C)
        -> TokenedIO<B?> where T == Tokened<A?> {
            
            return map { value -> C? in
                return value.map { type($0)
                }
            }.fetch(context, returnType)
    }

}
