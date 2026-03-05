//
//  Github+ServicesTests.swift
//  APIConnectTests
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 07..
//
import APIConnect
import APIModels
import Mocks

import XCTest
import JWT
import Vapor

@testable import APIService

class GithubServicesTests: XCTestCase {
    
    func testVerify() throws {
        let signature = "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"
        XCTAssertTrue(Github.verify(body: "y", secret: "x", signature: signature))
        XCTAssertFalse(Github.verify(body: "x", secret: "x", signature: signature))
    }
    
    func testJwt() async throws {
        try await Service.loadTestWithEmptyAPI()
        
        let iss = IssuerClaim(value: "0101")
        let iat: TimeInterval = 1
        let exp = (10 * 60) + iat
        
        let token = try await Github.jwt(date: Date(timeIntervalSince1970: iat), appId: "0101")
        let data = token.data(using: .utf8) ?? Data()
        let jwt = try await Service.shared.signers.defaultJWTParser.parse(data, as: Github.JWTPayloadData.self)
        
        XCTAssertEqual(jwt.payload.iss, iss)
        XCTAssertEqual(jwt.payload.iat, Int(iat))
        XCTAssertEqual(jwt.payload.exp, Int(exp))
    }
    
    func testAccessToken() async throws {
        class MockAPI: BackendAPIType {
            func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
                pure(MockHTTPResponse.okResponse(body: "{\"token\":\"x\"}"), Service.mockContext)
            }
        }
        try await Service.loadTest(MockAPI())
        
        
        let result = try await Github.accessToken(jwtToken: "a", installationId: 1,).get()
        XCTAssertEqual(result, "x")
    }
}
