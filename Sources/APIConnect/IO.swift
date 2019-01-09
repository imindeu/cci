//
//  IO.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

import protocol NIO.EventLoopGroup
import class NIO.EventLoopFuture
import class HTTP.Future

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
    
    func bimapEither<A, B, L, R>(_ l2a: @escaping (L) -> A, _ r2b: @escaping (R) -> B) -> EitherIO<A, B> where T == Either<L, R> {
        return map { $0.bimap(l2a, r2b) }
    }
}
