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
    static var signatureHeaderName: String { return "X-Hub-Signature-256" }
    static var eventHeaderName: String { return "X-GitHub-Event" }
}

public extension Github {
    struct JWTPayloadData: JWTPayload {
        let iss: IssuerClaim
        let iat: Int
        let exp: Int
        
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
        
        let digest = HMAC<SHA256>.authenticationCode(for: body, using: SymmetricKey(data: secret))
        return signature == "sha256=\(digest.hexEncodedString())"
    }
    
    static func jwt(date: Date = Date(), appId: String) async throws -> String {
        try await Service.shared.signers.sign(JWTPayloadData(
            iss: .init(value: appId),
            iat: Int(date.timeIntervalSince1970),
            exp: Int(date.addingTimeInterval(10 * 60).timeIntervalSince1970)
        ))
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
                ("Accept", "application/vnd.github+json"),
                ("X-GitHub-Api-Version", "2022-11-28"),
                ("User-Agent", "cci-imind")
            ])
        )
        
        return Service.shared.api
            .execute(request: request)
            .decode(TokenResponse.self)
            .map(\.?.token)
    }
    
}
