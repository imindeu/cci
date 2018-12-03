//
//  APIConnectTests.swift
//  APIConnectTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

import APIConnect
import HTTP
import XCTest

struct FromRequest: RequestModel {
    typealias ResponseModel = FromResponse
    typealias Config = FromConfig
    enum FromConfig: String, Configuration {
        case config
    }
    var data: String
    var responseURL: URL?
}
extension FromRequest {
    static var check: (FromRequest) -> FromResponse? = {
        return $0.responseURL == nil ? FromResponse(data: "", error: true) : nil
    }
    static var request: (FromRequest) -> Either<FromResponse, ToRequest> = {
        return .right(ToRequest(data: $0.data, responseURL: nil))
    }
    static var instant: (Context) -> (FromRequest) -> EitherIO<Empty, FromResponse> = { context in return { _ in pure(.left(Empty()), context) } }
    static var fromAPI: (FromRequest, Context) -> (FromResponse) -> IO<Void> = { _, context in
        return {
            Environment.env["fromAPI"] = $0.data
            return pure((), context)
        }
    }
}
struct FromResponse: Encodable, Equatable {
    var data: String
    var error: Bool
}

struct ToRequest: RequestModel {
    typealias ResponseModel = ToResponse
    typealias Config = ToConfig
    enum ToConfig: String, Configuration {
        case config
    }
    var data: String
    var responseURL: URL? = nil
}
extension ToRequest {
    static var response: (ToResponse) -> FromResponse = { FromResponse(data: $0.data, error: false) }
    static var toAPI: (Context) -> (Either<FromResponse, ToRequest>) -> EitherIO<FromResponse, ToResponse> = { context in
        return {
            pure(Either<FromResponse, ToResponse>
                .right(ToResponse(data: $0.either({ $0.data }, { $0.data }))), context)
            
        }
    }
}
struct ToResponse {
    var data: String = ""
}

struct Environment: APIConnectEnvironment {
    static var env: [String: String] = [:]
}

typealias MockAPIConnect = APIConnect<FromRequest, ToRequest, Environment>

extension APIConnect where From == FromRequest, To == ToRequest {
    static func run(_ from: FromRequest, _ context: Context) -> EitherIO<Empty, FromResponse> {
        return APIConnect<FromRequest, ToRequest, E>(
            check: FromRequest.check,
            request: FromRequest.request,
            toAPI: ToRequest.toAPI,
            response: ToRequest.response,
            fromAPI: FromRequest.fromAPI,
            instant: FromRequest.instant)
            .run(from, context)

    }
}

class APIConnectTests: XCTestCase {
    
    func testCheckFail() throws {
        let response = try MockAPIConnect
            .run(FromRequest(data: "x", responseURL: nil),
                 MultiThreadedEventLoopGroup(numberOfThreads: 1))
            .wait()
        XCTAssertEqual(response.right, FromResponse(data: "", error: true))
    }
    
    func testRunWithResponseURL() throws {
        Environment.env["fromAPI"] = nil
        let response = try MockAPIConnect
            .run(FromRequest(data: "x", responseURL: URL(string: "https://test.com")),
                 MultiThreadedEventLoopGroup(numberOfThreads: 1))
            .wait()
        XCTAssertEqual(response.left, Empty())
        XCTAssertEqual(Environment.env["fromAPI"], "x")
    }
    
    func testRunWithoutResponseURL() throws {
        Environment.env["fromAPI"] = nil
        FromRequest.check = { _ in nil }
        let response = try MockAPIConnect
            .run(FromRequest(data: "x", responseURL: nil),
                 MultiThreadedEventLoopGroup(numberOfThreads: 1))
            .wait()
        XCTAssertEqual(response.right, FromResponse(data: "x", error: false))
        XCTAssertNil(Environment.env["fromAPI"])
    }

    func testCheckConfigs() {
        do {
            try MockAPIConnect.checkConfigs()
            XCTFail("Should fail")
        } catch {
            if case let MockAPIConnect.APIConnectError.combined(errors) = error {
                XCTAssertEqual(errors.count, 3, "We haven't found all the errors")
            } else {
                XCTFail("Wrong error \(error)")
            }
        }
    }
    
}
