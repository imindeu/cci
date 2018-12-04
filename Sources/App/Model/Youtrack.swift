//
//  Youtrack.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//
import APIConnect
import APIModels
import Foundation

struct YoutrackRequest {}

extension YoutrackRequest: RequestModel {
    typealias ResponseModel = YoutrackResponse
    typealias Config = YoutrackConfig
    
    public enum YoutrackConfig: String, Configuration {
        case youtrackToken
        case youtrackURL
    }
    
    public var responseURL: URL? { return nil }
}

struct YoutrackResponse: Encodable {}
