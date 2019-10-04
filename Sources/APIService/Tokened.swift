//
//  Tokened.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 09..
//
import protocol APIConnect.Context
import class APIConnect.IO
import func APIConnect.pure

import struct Foundation.Data
import struct Foundation.URL
import enum HTTP.HTTPMethod

public protocol TokenRequestable {
    var method: HTTPMethod? { get }
    var body: Data? { get }
    
    func url(token: String) -> URL?
    func headers(token: String) -> [(String, String)]
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
    
    func map<A, B>(_ callback: @escaping (A) throws -> B) -> TokenedIO<B> where T == Tokened<A> {
        return map { tokened in return Tokened(tokened.token, try callback(tokened.value)) }
    }
    
    func fetch<A: Decodable, B: TokenRequestable>(_ context: Context, _ returnType: A.Type, _ api: @escaping API)
        -> TokenedIO<A?> where T == Tokened<B?> {
            
            return self.flatMap { tokened in
                guard let value = tokened.value else { return pure(Tokened<A?>(tokened.token, nil), context) }
                return try Service.fetch(value, returnType, tokened.token, context, api)
            }
    }
    
    func fetch<A, B: Decodable, C: TokenRequestable>(_ context: Context,
                                                            _ returnType: B.Type,
                                                            _ api: @escaping API,
                                                            _ type: @escaping (A) -> C?)
        -> TokenedIO<B?> where T == Tokened<A?> {
            
            return map { value -> C? in
                return value.flatMap(type)
            }.fetch(context, returnType, api)
    }
    
}
