//
//  Tokened.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 09..
//
import APIConnect

import Foundation
import Vapor

public protocol TokenRequestable {
    var method: HTTPMethod? { get }
    var body: Data? { get }
    
    func url(token: String) -> URL?
    func headers(token: String) -> [(String, String)]
}

public struct Tokened<A: Sendable>: Sendable {
    public let token: String
    public let value: A
    
    public init(_ token: String, _ value: A) {
        self.token = token
        self.value = value
    }
}

public typealias TokenedIO<A> = IO<Tokened<A>>

public extension TokenedIO {
    
    func map<A, B>(_ callback: @escaping (A) throws -> B) -> TokenedIO<B> where Value == Tokened<A> {
        return flatMapThrowing { tokened in return Tokened(tokened.token, try callback(tokened.value)) }
    }
    
    func fetch<A: Decodable, B: TokenRequestable>(
        _ context: Context,
        _ returnType: A.Type
    ) -> TokenedIO<A?> where Value == Tokened<B?> {
        return self.flatMapThrowingIO { tokened in
            guard let value = tokened.value else { return pure(Tokened<A?>(tokened.token, nil), context) }
            return try Service.fetch(value, returnType, tokened.token)
        }
    }
    
    func fetch<A, B: Decodable, C: TokenRequestable>(
        _ context: Context,
        _ returnType: B.Type,
        _ type: @escaping (A) -> C?
    ) -> TokenedIO<B?> where Value == Tokened<A?> {
        return map { value -> C? in value.flatMap(type) }
            .fetch(context, returnType)
    }
    
}
