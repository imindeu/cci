//
//  Either.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 25..
//

import Foundation

enum Either<L, R> {
    case left(L)
    case right(R)
}

extension Either {
    func either<A>(_ l2a: (L) -> A, _ r2a: (R) -> A) -> A {
        switch self {
        case let .left(l):
            return l2a(l)
        case let .right(r):
            return r2a(r)
        }
    }
    
    var left: L? {
        return either(Optional.some, { _ in .none })
    }
    
    public var right: R? {
        return either({ _ in .none }, Optional.some)
    }
    
    public var isLeft: Bool {
        return either({ _ in true }, { _ in false })
    }
    
    public var isRight: Bool {
        return either({ _ in false }, { _ in true })
    }
}
