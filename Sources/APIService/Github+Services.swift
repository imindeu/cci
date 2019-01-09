//
//  Github+Services.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

import protocol APIConnect.Context
import class APIConnect.IO
import enum APIModels.Github

import struct Foundation.Date

import struct Crypto.RSAKey
import class Crypto.HMAC

import protocol JWT.JWTPayload
import struct JWT.JWT
import class JWT.JWTSigner

import struct HTTP.HTTPHeaders
import struct HTTP.HTTPRequest

public extension Github {
    public static var signatureHeaderName: String { return "X-Hub-Signature" }
    public static var eventHeaderName: String { return "X-GitHub-Event" }
}

public extension Github {
    
    struct JWTPayloadData: JWTPayload {
        let iat: Int
        let exp: Int
        let iss: String
        
        public func verify(using signer: JWTSigner) throws {  }
    }

    static func verify(body: String?, secret: String?, signature: String?) -> Bool {
        guard let body = body,
            let secret = secret,
            let signature = signature,
            let digest = try? HMAC(algorithm: .sha1).authenticate(body, key: secret) else {
            return false
        }
        return signature == "sha1=\(digest.hexEncodedString())"
    }

    public static func jwt(date: Date = Date(), appId: String, privateKey: String) throws -> String? {
        let iat = Int(date.timeIntervalSince1970)
        let exp = Int(date.addingTimeInterval(10 * 60).timeIntervalSince1970)
        let signer = try JWTSigner.rs256(key: RSAKey.private(pem: privateKey))
        let jwt = JWT<JWTPayloadData>(payload: JWTPayloadData(iat: iat, exp: exp, iss: appId))
        let data = try jwt.sign(using: signer)
        return String(data: data, encoding: .utf8)
    }
    
    public static func accessToken(context: Context,
                                   jwtToken: String,
                                   installationId: Int,
                                   api: @escaping API) -> IO<String?> {
        let headers = HTTPHeaders([
            ("Authorization", "Bearer \(jwtToken)"),
            ("Accept", "application/vnd.github.machine-man-preview+json"),
            ("User-Agent", "cci-imind")
        ])
        let request = HTTPRequest(method: .POST,
                                  url: "/app/installations/\(installationId)/access_tokens",
                                  headers: headers,
                                  body: "")
        struct TokenResponse: Decodable {
            let token: String
        }
        
        return api("api.github.com", nil)(context, request)
            .decode(TokenResponse.self)
            .map { $0?.token }
    }
    
}
