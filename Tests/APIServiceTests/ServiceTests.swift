//
//  ServiceTests.swift
//  AppTests
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 09..
//

import APIConnect
import APIModels
import APIService
import Mocks

import XCTest
import Vapor

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
    
    func testFetch() async throws {
        class MockAPI: BackendAPIType {
            
            func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
                let response = MockResponse(
                    body: "x",
                    hostname: "test.com",
                    port: 8080,
                    path: "/path?value=x&label=%22test%20label%22&token=t",
                    headers: request.headers.filter { name, value in name == "Test-Header" }.map { $0 + ":" + $1 }
                )

                do {
                    let body = try JSONEncoder().encode(response)
                    return pure(MockHTTPResponse.okResponse(body: String(data: body, encoding: .utf8)!), Service.mockContext)
                } catch {
                    XCTFail(error.localizedDescription)
                    return pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
                }
            }
        }
        try await Service.loadTest(MockAPI())
        
        let expected = MockResponse(
            body: "x",
            hostname: "test.com",
            port: 8080,
            path: "/path?value=x&label=%22test%20label%22&token=t",
            headers: ["Test-Header:Token t"]
        )
        let response = try await Service.fetch(MockRequest(value: "x"), MockResponse.self, "t").get()
        XCTAssertEqual(response.value, expected)
        XCTAssertEqual(response.token, "t")
    }
}
