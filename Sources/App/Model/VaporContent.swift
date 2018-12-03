//
//  Content.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

// MARK: - Vapor conformance
import APIConnect
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
extension Empty: Content {}

extension Either: RequestEncodable where L == Empty, R == SlackResponse {
    public func encode(using container: Container) throws -> EventLoopFuture<Request> {
        switch self {
        case let .left(l):
            return try l.encode(using: container)
        case let .right(r):
            return try r.encode(using: container)
        }
    }
}
extension Either: RequestDecodable where L == Empty, R == SlackResponse {
    public static func decode(from req: Request) throws -> EventLoopFuture<Either<L, R>> {
        return try req.content.decode(Either<Empty, SlackResponse>.self)
    }
}
extension Either: ResponseEncodable where L == Empty, R == SlackResponse {
    public func encode(for req: Request) throws -> EventLoopFuture<Response> {
        switch self {
        case let .left(l):
            return try l.encode(for: req)
        case let .right(r):
            return try r.encode(for: req)
        }
    }
    
}
extension Either: ResponseDecodable where L == Empty, R == SlackResponse {
    public static func decode(from res: Response, for req: Request) throws -> EventLoopFuture<Either<L, R>> {
        return try res.content.decode(Either<Empty, SlackResponse>.self)
    }
    
}
