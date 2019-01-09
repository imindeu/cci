//
//  Github+Services.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

import APIConnect
import APIModels

import struct Foundation.Date

import class Crypto.HMAC
import struct Crypto.RSAKey
import struct JWT.JWT
import protocol JWT.JWTPayload
import class JWT.JWTSigner

import struct HTTP.HTTPHeaders
import struct HTTP.HTTPRequest

extension Github {
    static var signatureHeaderName: String { return "X-Hub-Signature" }
    static var eventHeaderName: String { return "X-GitHub-Event" }
}

extension Github {
    
    struct JWTPayloadData: JWTPayload {
        let iat: Int
        let exp: Int
        let iss: String
        
        func verify(using signer: JWTSigner) throws {  }
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

    static func jwt(date: Date = Date(), appId: String, privateKey: String) throws -> String {
        let iat = Int(date.timeIntervalSince1970)
        let exp = Int(date.addingTimeInterval(10 * 60).timeIntervalSince1970)
        let signer = try JWTSigner.rs256(key: RSAKey.private(pem: privateKey))
        let jwt = JWT<JWTPayloadData>(payload: JWTPayloadData(iat: iat, exp: exp, iss: appId))
        let data = try jwt.sign(using: signer)
        guard let string = String(data: data, encoding: .utf8) else { throw Error.signature }
        return string
    }
    
    static func accessToken(context: Context,
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
