//
//  Environment.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

import APIConnect
import APIService

import Foundation

import Vapor

public struct Environment: APIConnectEnvironment {
    public static var env: [String: String] = ProcessInfo.processInfo.environment    
}
