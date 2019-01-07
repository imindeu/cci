//
//  Github+Services.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

import APIConnect
import APIModels

import Crypto
import JWT
import HTTP

protocol HTTPRequestable {
    var url: URL? { get }
    var method: HTTPMethod? { get }
    var body: Data? { get }
}

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
                            api: @escaping API) -> () -> IO<String> {
        return {
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
                .map { response in
                    guard let response = response else {
                        throw Error.accessToken
                    }
                    return response.token
                }
        }
    }
    
    static func fetch<A: Decodable>(_ request: HTTPRequestable,
                                    _ responseType: A.Type,
                                    _ token: String,
                                    _ context: Context,
                                    _ api: @escaping API) throws -> TokenedIO<A?> {
        guard let method = request.method else {
            throw Error.noMethod
        }
        guard let url = request.url else {
            throw Error.noURL
        }
        guard let host = url.host,
            let path = url.path
                .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else {
                    throw Error.badUrl(url.absoluteString)
        }
        
        let headers = HTTPHeaders([
            ("Authorization", "token \(token)"),
            ("Accept", "application/vnd.github.machine-man-preview+json"),
            ("User-Agent", "cci-imind")
        ])
        
        let httpRequest = HTTPRequest(method: method,
                                      url: path,
                                      headers: headers,
                                      body: request.body ?? HTTPBody())
        
        return api(host, url.port)(context, httpRequest)
            .decode(responseType)
            .map { Tokened(token, $0) }
    }
}
