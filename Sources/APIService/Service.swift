//
//  Service.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2019. 01. 08..
//

import APIConnect
import APIModels

import Foundation
import Vapor
import JWTKit

public final class Service {
    
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    public private(set) static var shared: Service!
    
    public static func load(_ api: BackendAPIType, githubPrivateKey: String) async throws {
        shared = try await .init(api, githubPrivateKey: githubPrivateKey)
    }
    
    public let api: BackendAPIType
    public let signers: JWTKeyCollection
    
    private init(_ api: BackendAPIType, githubPrivateKey: String) async throws {
        self.api = api
        
        signers = JWTKeyCollection()
        await signers.add(rsa: try Insecure.RSA.PrivateKey(pem: githubPrivateKey), digestAlgorithm: .sha256)
    }
    
    public enum Error: LocalizedError {
        case noMethod
        case noURL
        
        public var errorDescription: String? {
            switch self {
            case .noMethod: return "Type doesn't have a method"
            case .noURL: return "Type doesn't have an url"
            }
        }
    }

    public static func fetch<A: Decodable>(
        _ request: TokenRequestable,
        _ responseType: A.Type,
        _ token: String,
        isDebugMode: Bool = false
    ) throws -> TokenedIO<A?> {
        guard let method = request.method else {
            if isDebugMode {
                print("\n\n ==================== ")
                print(" ERROR: No method\n")
            }
            throw Error.noMethod
        }
        guard let url = request.url(token: token) else {
            if isDebugMode {
                print("\n\n ==================== ")
                print(" ERROR: No URL\n")
            }
            throw Error.noURL
        }
        
        let httpRequest = try HTTPClient.Request(
            url: url,
            method: method,
            headers: HTTPHeaders(request.headers(token: token))
        )
        
        if isDebugMode {
            print("\n\n ==================== ")
            print(" OUTGOING REQUEST\n")
            print("request:\n\(request)\n")
            print("httpRequest:\n\(httpRequest)\n")
        }
        
        return shared.api
            .execute(request: httpRequest)
            .map { response in
                if isDebugMode {
                    print("\n\n ==================== ")
                    print(" INCOMING RESPONSE\n")
                    print("response:\n\(response)\n")
                }
                return response
            }
            .decode(responseType)
            .map { Tokened(token, $0) }
    }
}

extension IO where Value == HTTPClient.Response {
    func decode<A: Decodable & Sendable>(_ type: A.Type) -> IO<A?> {
        flatMapThrowing { response -> A? in
            guard let byteBuffer = response.body else { return nil }
            return try Service.decoder.decode(type, from: byteBuffer)
        }
    }
}
