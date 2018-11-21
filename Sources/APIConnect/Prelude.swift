//
//  Prelude.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

public func id<A>(_ a: A) -> A {
    return a
}

public func const<A, B>(_ a: A) -> (B) -> A {
    return { _ in a }
}

public func const<A>(_ a: A) -> () -> A {
    return { a }
}

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
