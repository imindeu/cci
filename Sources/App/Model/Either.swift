//
//  Either.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 14..
//

import Foundation

enum Either<A, B> {
    case left(A)
    case right(B)
}

extension Either {
    
    func map<C>(_ f: (A) -> C, _ g: (B) -> C) -> C {
        switch self {
        case let .left(a):
            return f(a)
        case let .right(b):
            return g(b)
        }
    }
}
