//
//  Youtrack+ServicesTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 07..
//

import APIModels

import XCTest

@testable import App

class YoutrackServicesTests: XCTestCase {
    let issues = ["4DM-2001", "4DM-2002"]

    func testIssues() throws {
        XCTAssertEqual(try Youtrack.issues(from: "test \(issues.joined(separator: ", "))"), issues)
        XCTAssertEqual(try Youtrack.issues(from: "test"), [])
    }
    
    func testIssueURLs() throws {
        let expected = [ "https://test.com/youtrack/issue/4DM-2001", "https://test.com/youtrack/issue/4DM-2002"]
        XCTAssertEqual(
            try Youtrack.issueURLs(from: "test \(issues.joined(separator: ", "))",
                                   url: "https://test.com/youtrack/rest/"),
            expected)
    }

}
