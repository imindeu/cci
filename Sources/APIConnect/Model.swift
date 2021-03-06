//
//  Model.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

import struct Foundation.URL

public protocol Configuration: RawRepresentable & CaseIterable where RawValue == String {}

public protocol Headers {
    func get(_ name: String) -> String?
}

public protocol APIConnectEnvironment {
    static var env: [String: String] { get }
}

extension APIConnectEnvironment {
    public static func get(key: String) -> String? {
        return env[key]
    }

    public static func isDebugMode() -> Bool {
        return env["debugMode"] == "true"
    }

    public static func get<A: Configuration>(_ key: A) -> String? {
        return env[key.rawValue]
    }
    
    public static func getArray<A: Configuration>(_ key: A, separator: Character = "@") -> [String] {
        return get(key)?.split(separator: separator).map(String.init) ?? []
    }
}

public protocol Checkable {}

public protocol RequestModel {
    associatedtype ResponseModel
    associatedtype Config: Configuration
}

public protocol DelayedRequestModel: RequestModel {
    var responseURL: URL? { get }
}

public extension RequestModel {
    static func check<A: APIConnectEnvironment>(_ type: A.Type) -> [Config] {
        return Config.allCases.compactMap { A.get($0) == nil ? $0 : nil }
    }
}
