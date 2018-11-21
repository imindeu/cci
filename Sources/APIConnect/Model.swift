//
//  Model.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

import Foundation

public protocol Configuration: RawRepresentable & CaseIterable where RawValue == String {}

public protocol RequestModel {
    associatedtype Response: ResponseModel
    associatedtype Config: Configuration
    var responseURL: URL? { get }
}

public extension RequestModel {
    public static func check() -> [Config] {
        return Config.allCases.compactMap { Environment.get($0) == nil ? $0 : nil }
    }
}

public protocol ResponseModel {}
