//
//  Github+ServicesTests.swift
//  APIConnectTests
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 07..
//
import APIConnect
import APIModels

import XCTest
import JWT
import HTTP

@testable import App

class Github_ServicesTests: XCTestCase {

    func testVerify() throws {
        let signature = "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"
        XCTAssertTrue(Github.verify(body: "y", secret: "x", signature: signature))
        XCTAssertFalse(Github.verify(body: "x", secret: "x", signature: signature))
    }

    func testJwt() throws {
        let iss = "0101"
        let iat: TimeInterval = 1
        let exp = (10 * 60) + iat
        
        let token = try Github.jwt(date: Date(timeIntervalSince1970: iat), appId: iss, privateKey: privateKeyString)
        let data: Data = token.data(using: .utf8) ?? Data()
        let jwt = try JWT<Github.JWTPayloadData>(unverifiedFrom: data)
        
        XCTAssertEqual(jwt.payload.iss, iss)
        XCTAssertEqual(jwt.payload.iat, Int(iat))
        XCTAssertEqual(jwt.payload.exp, Int(exp))
        
    }
    
    func testAccessToken() throws {
        let token = "x"
        let api: API = { hostname, _ in
            return { context, _ in
                return pure(HTTPResponse(body: "{\"token\":\"\(token)\"}"), context)
            }
        }
        XCTAssertEqual(try Github.accessToken(context: context(), jwtToken: "a", installationId: 1, api: api)().wait(), token)
    }

}
