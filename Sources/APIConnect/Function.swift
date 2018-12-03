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
