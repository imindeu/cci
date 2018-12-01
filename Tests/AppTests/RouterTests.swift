//
//  RouterTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2018. 09. 10..
//

import XCTest
import Vapor
@testable import App

class RouterTests: XCTestCase {
    let circleciTokens = ["circleciToken"]
    let slackToken = "slackToken"
    let project = "projectX"
    let branch = "feature/branch-X"
    var urlEncodedBranch: String {
        return branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
    let username = "tester"
    let options = ["options1:x", "options2:y"]
    let headers = HTTPHeaders([
        ("Accept", "application/json"),
        ("Content-Type", "application/json")
        ])
}
