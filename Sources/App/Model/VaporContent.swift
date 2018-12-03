//
//  Content.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

// MARK: - Vapor conformance
import APIModels
import Vapor

protocol DecodableContent: Decodable, RequestDecodable {}
extension DecodableContent {
    public static func decode(from req: Request) throws -> Future<Self> {
        return try req.content.decode(Self.self)
    }
}

extension SlackRequest: DecodableContent {}
extension SlackResponse: Content {}

extension Optional: ResponseEncodable where Wrapped: ResponseEncodable {
    public func encode(for req: Request) throws -> EventLoopFuture<Response> {
        switch self {
        case let .some(some):
            return try some.encode(for: req)
        case .none:
            return req.future(Response(http: .init(), using: req))
        }
    }
    
}
