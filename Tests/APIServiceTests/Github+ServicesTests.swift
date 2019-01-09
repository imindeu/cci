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

@testable import APIService

class GithubServicesTests: XCTestCase {

    func testVerify() throws {
        let signature = "sha1=2c1c62e048a5824dfb3ed698ef8ef96f5185a369"
        XCTAssertTrue(Github.verify(body: "y", secret: "x", signature: signature))
        XCTAssertFalse(Github.verify(body: "x", secret: "x", signature: signature))
    }

    func testJwt() throws {
        let iss = "0101"
        let iat: TimeInterval = 1
        let exp = (10 * 60) + iat
        
        guard let token = try Github.jwt(date: Date(timeIntervalSince1970: iat),
                                         appId: iss,
                                         privateKey: privateKeyString) else {
            XCTFail("No token was created")
            return
        }
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
        XCTAssertEqual(try Github.accessToken(context: MultiThreadedEventLoopGroup(numberOfThreads: 1),
                                              jwtToken: "a",
                                              installationId: 1,
                                              api: api).wait(),
                       token)
    }

}

// swiftlint:disable prefixed_toplevel_constant
let privateKeyString = """
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQC0cOtPjzABybjzm3fCg1aCYwnxPmjXpbCkecAWLj/CcDWEcuTZ
kYDiSG0zgglbbbhcV0vJQDWSv60tnlA3cjSYutAv7FPo5Cq8FkvrdDzeacwRSxYu
Iq1LtYnd6I30qNaNthntjvbqyMmBulJ1mzLI+Xg/aX4rbSL49Z3dAQn8vQIDAQAB
AoGBAJeBFGLJ1EI8ENoiWIzu4A08gRWZFEi06zs+quU00f49XwIlwjdX74KP03jj
H14wIxMNjSmeixz7aboa6jmT38pQIfE3DmZoZAbKPG89SdP/S1qprQ71LgBGOuNi
LoYTZ96ZFPcHbLZVCJLPWWWX5yEqy4MS996E9gMAjSt8yNvhAkEA38MufqgrAJ0H
VSgL7ecpEhWG3PHryBfg6fK13RRpRM3jETo9wAfuPiEodnD6Qcab52H2lzMIysv1
Ex6nGv2pCQJBAM5v9SMbMG20gBzmeZvjbvxkZV2Tg9x5mWQpHkeGz8GNyoDBclAc
BFEWGKVGYV6jl+3F4nqQ6YwKBToE5KIU5xUCQEY9Im8norgCkrasZ3I6Sa4fi8H3
PqgEttk5EtVe/txWNJzHx3JsCuD9z5G+TRAwo+ex3JIBtxTRiRCDYrkaPuECQA2W
vRI0hfmSuiQs37BtRi8DBNEmFrX6oyg+tKmMrDxXcw8KrNWtInOb+r9WZK5wIl4a
epAK3fTD7Bgnnk01BwkCQHQwEdGNGN3ntYfuRzPA4KiLrt8bpACaHHr2wn9N3fRI
bxEd3Ax0uhHVqKRWNioL7UBvd4lxoReY8RmmfghZHEA=
-----END RSA PRIVATE KEY-----
"""

// public key for later testing
let publicKeyString = """
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC0cOtPjzABybjzm3fCg1aCYwnx
PmjXpbCkecAWLj/CcDWEcuTZkYDiSG0zgglbbbhcV0vJQDWSv60tnlA3cjSYutAv
7FPo5Cq8FkvrdDzeacwRSxYuIq1LtYnd6I30qNaNthntjvbqyMmBulJ1mzLI+Xg/
aX4rbSL49Z3dAQn8vQIDAQAB
-----END PUBLIC KEY-----
"""

// swiftlint:enable prefixed_toplevel_constant
