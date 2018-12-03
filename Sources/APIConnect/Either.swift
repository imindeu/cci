//
//  Either.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

public enum Either<L, R> {
    case left(L)
    case right(R)
}

public extension Either {
    public func either<A>(_ l2a: (L) -> A, _ r2a: (R) -> A) -> A {
        switch self {
        case let .left(l):
            return l2a(l)
        case let .right(r):
            return r2a(r)
        }
    }
    
    public var left: L? {
        return either(Optional.some, const(.none))
    }
    
    public var right: R? {
        return either(const(.none), Optional.some)
    }
    
    public var isLeft: Bool {
        return either(const(true), const(false))
    }
    
    public var isRight: Bool {
        return either(const(false), const(true))
    }
    
}

public extension Either {
    public func map<A>(_ r2a: (R) -> A) -> Either<L, A> {
        switch self {
        case let .left(l):
            return .left(l)
        case let .right(r):
            return .right(r2a(r))
        }
    }
    public func flatMap<A>(_ r2a: (R) -> Either<L, A>) -> Either<L, A> {
        return either(Either<L, A>.left, r2a)
    }
}

extension Either: Equatable where L: Equatable, R: Equatable {
    public static func == (lhs: Either, rhs: Either) -> Bool {
        switch (lhs, rhs) {
        case let (.left(lhs), .left(rhs)):
            return lhs == rhs
        case let (.right(lhs), .right(rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

extension Either: Encodable where L: Encodable, R: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .left(l):
            try l.encode(to: encoder)
        case let .right(r):
            try r.encode(to: encoder)
        }
    }
    
}

extension Either: Decodable where L: Decodable, R: Decodable {
    public init(from decoder: Decoder) throws {
        do {
            self = try .right(.init(from: decoder))
        } catch {
            self = try .left(.init(from: decoder))
        }
    }
    
    
}
