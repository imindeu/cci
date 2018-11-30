//
//  Model.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

import Foundation

public protocol Configuration: RawRepresentable & CaseIterable where RawValue == String {}

public protocol APIConnectEnvironment {
    static func get<A: Configuration>(_ key: A) -> String?
}

public protocol RequestModel {
    associatedtype ResponseModel
    associatedtype Config: Configuration
    var responseURL: URL? { get }
}

public extension RequestModel {
    public static func check<A: APIConnectEnvironment>(_ type: A.Type) -> [Config] {
        return Config.allCases.compactMap { A.get($0) == nil ? $0 : nil }
    }
}
