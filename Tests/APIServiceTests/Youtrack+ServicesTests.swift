//
//  Youtrack+ServicesTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 07..
//

import APIModels

import XCTest

@testable import APIService

class YoutrackServicesTests: XCTestCase {
    let issues = ["4DM-2001", "4DM-2002"]

    func testIssues() throws {
        XCTAssertEqual(try Youtrack.issues(from: "test \(issues.joined(separator: ", "))",
                                           pattern: "4DM-[0-9]+"),
                       issues)
        XCTAssertEqual(try Youtrack.issues(from: "test", pattern: "4DM-[0-9]+"), [])
    }
    
    func testIssueURLs() throws {
        let expected = [ "https://test.com/youtrack/issue/4DM-2001", "https://test.com/youtrack/issue/4DM-2002"]
        XCTAssertEqual(
            try Youtrack.issueURLs(from: "test \(issues.joined(separator: ", "))",
                                   base: "https://test.com/youtrack/api/",
                                   pattern: "4DM-[0-9]+"),
            expected)
    }

}
