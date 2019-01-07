//
//  Tokened.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 07..
//

import APIConnect

public struct Tokened<A> {
    public let token: String
    public let value: A
    
    public init(_ token: String, _ value: A) {
        self.token = token
        self.value = value
    }
}

public typealias TokenedIO<A> = IO<Tokened<A>>
