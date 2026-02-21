//
//  Github+Services.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

import APIConnect
import APIModels

import Foundation
import Vapor
import JWTKit

public extension Github {
    static var signatureHeaderName: String { return "X-Hub-Signature" }
    static var eventHeaderName: String { return "X-GitHub-Event" }
}

public extension Github {
    struct JWTPayloadData: JWTPayload {
        let iat: Int
        let exp: Int
        let iss: String
        
        public func verify(using algorithm: some JWTKit.JWTAlgorithm) async throws {}
    }
    
    static func verify(body: String?, secret: String?, signature: String?) -> Bool {
        guard
            let body = body?.data(using: .utf8),
            let secret = secret?.data(using: .utf8),
            let signature = signature
        else {
            return false
        }
        
        let digest = HMAC<Crypto.Insecure.SHA1>.authenticationCode(for: body, using: SymmetricKey(data: secret))
        return signature == "sha1=\(digest.hexEncodedString())"
    }
    
    static func jwt(date: Date = Date(), appId: String) async throws -> String {
        let iat = Int(date.timeIntervalSince1970)
        let exp = Int(date.addingTimeInterval(10 * 60).timeIntervalSince1970)
        let payload = JWTPayloadData(iat: iat, exp: exp, iss: appId)
        return try await Service.shared.signers.sign(payload)
    }
    
    static func accessToken(jwtToken: String, installationId: Int) throws -> IO<String?> {
        struct TokenResponse: Decodable {
            let token: String
        }
        
        let request = try HTTPClient.Request(
            url: URL(string: "https://api.github.com/app/installations/\(installationId)/access_tokens")!,
            method: .POST,
            headers: HTTPHeaders([
                ("Authorization", "Bearer \(jwtToken)"),
                ("Accept", "application/vnd.github.machine-man-preview+json"),
                ("User-Agent", "cci-imind")
            ])
        )
        
        return Service.shared.api
            .execute(request: request)
            .decode(TokenResponse.self)
            .map(\.?.token)
    }
    
}
