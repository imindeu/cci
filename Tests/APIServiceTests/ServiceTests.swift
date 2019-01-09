//
//  ServiceTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 09..
//

import APIConnect
import App

import XCTest
import HTTP

class ServiceTests: XCTestCase {

    private struct MockRequest: TokenRequestable {
        let value: String
        
        var method: HTTPMethod? { return .POST }
        
        var body: Data? { return value.data(using: .utf8) }
        
        func url(token: String) -> URL? {
            return URL(string: "https://test.com:8080")?
                .appendingPathComponent("/path?value=\(value)&label=\"test label\"&token=\(token)")
        }
        
        func headers(token: String) -> [(String, String)] {
            return [("Test-Header", "Token \(token)")]
        }
    }
    
    private struct MockResponse: Codable, Equatable {
        let body: String
        let hostname: String
        let port: Int?
        let path: String
        let headers: [String]
    }
    
    func testFetch() throws {
        let api: API = { hostname, port in
            return { context, request in
                let response = MockResponse(body: String(data: request.body.data!, encoding: .utf8)!,
                                            hostname: hostname,
                                            port: port,
                                            path: request.url.absoluteString,
                                            headers: request.headers
                                                .filter { $0.0 == "Test-Header" }
                                                .map { $0 + ":" + $1 })
                return pure(HTTPResponse(body: try! JSONEncoder().encode(response)), context)
            }
        }
        let expected = MockResponse(body: "x",
                                    hostname: "test.com",
                                    port: 8080,
                                    path: "/path?value=x&label=%22test%20label%22&token=t",
                                    headers: ["Test-Header:Token t"])
        let response = try Service.fetch(MockRequest(value: "x"), MockResponse.self, "t", context(), api).wait()
        XCTAssertEqual(response.value, expected)
        XCTAssertEqual(response.token, "t")
    }
}
