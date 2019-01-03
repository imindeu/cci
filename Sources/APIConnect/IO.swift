//
//  IO.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

import HTTP

public typealias Context = EventLoopGroup
public typealias IO = EventLoopFuture

public func pure<A>(_ a: A, _ context: Context) -> IO<A> {
    return IO.map(on: context, const(a))
}

public typealias EitherIO<L, R> = IO<Either<L, R>>

public func leftIO<A, B>(_ context: Context) -> (A) -> EitherIO<A, B> {
    return { pure(.left($0), context) }
}

public extension IO {
    func mapEither<A, L, R>(_ l2a: @escaping (L) -> A, _ r2a: @escaping (R) -> A) -> IO<A> where T == Either<L, R> {
        return map { $0.either(l2a, r2a) }
    }
}
