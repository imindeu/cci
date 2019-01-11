//
//  APIConnectTests.swift
//  APIConnectTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

import APIConnect
import HTTP
import XCTest

// MARK: - Mocks
struct FromRequest: RequestModel {
    typealias ResponseModel = FromResponse
    typealias Config = FromConfig
    enum FromConfig: String, Configuration {
        case config
    }
    
    var data: String
}

extension FromRequest {
    static var check: (FromRequest, String?, Headers?) -> FromResponse? = { _, _, _ in nil }
    static var request: (FromRequest, Headers?, Context) -> EitherIO<FromResponse, ToRequest> = { from, _, context in
        return rightIO(context)(ToRequest(data: from.data))
    }
}

struct DelayedFromRequest: DelayedRequestModel {
    typealias ResponseModel = FromResponse
    typealias Config = FromConfig
    enum FromConfig: String, Configuration {
        case config
    }
    
    var data: String
    var responseURL: URL?
}
extension DelayedFromRequest {
    static var request: (DelayedFromRequest, Headers?, Context)
        -> EitherIO<FromResponse, ToRequest> = { from, _, context in
        return rightIO(context)(ToRequest(data: from.data))
    }
    static var check: (DelayedFromRequest, String?, Headers?) -> FromResponse? = { from, payload, headers in
        return from.responseURL == nil ? FromResponse(data: "", error: true) : nil
    }
    static var instant: (Context) -> (DelayedFromRequest) -> IO<FromResponse?> = { context in
        return { _ in pure(nil, context) }
    }
    static var fromAPI: (DelayedFromRequest, Context) -> (FromResponse) -> IO<Void> = { _, context in
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
}
extension ToRequest {
    static var toAPI: (Context) -> (ToRequest)
        -> EitherIO<FromResponse, ToResponse> = { context in
        return {
            pure(Either<FromResponse, ToResponse>
                .right(ToResponse(data: $0.data )), context)
        }
    }
    static var response: (ToResponse) -> FromResponse = { FromResponse(data: $0.data, error: false) }
}
struct ToResponse {
    var data: String = ""
}

struct Environment: APIConnectEnvironment {
    static var env: [String: String] = [:]
}

typealias MockAPIConnect = APIConnect<FromRequest, ToRequest, Environment>

extension APIConnect where From == FromRequest, To == ToRequest {
    static func run(_ from: FromRequest,
                    _ context: Context,
                    _ payload: String? = nil,
                    _ headers: Headers? = nil) -> IO<FromResponse?> {
        return APIConnect<FromRequest, ToRequest, E>(
            check: FromRequest.check,
            request: FromRequest.request,
            toAPI: ToRequest.toAPI,
            response: ToRequest.response)
            .run(from, context, payload, headers)
        
    }
}

typealias MockDelayedAPIConnect = APIConnect<DelayedFromRequest, ToRequest, Environment>

extension APIConnect where From == DelayedFromRequest, To == ToRequest {
    static func run(_ from: DelayedFromRequest,
                    _ context: Context,
                    _ payload: String? = nil,
                    _ headers: Headers? = nil) -> IO<FromResponse?> {
        return APIConnect<DelayedFromRequest, ToRequest, E>(
            check: DelayedFromRequest.check,
            request: DelayedFromRequest.request,
            toAPI: ToRequest.toAPI,
            response: ToRequest.response,
            fromAPI: DelayedFromRequest.fromAPI,
            instant: DelayedFromRequest.instant)
            .run(from, context, payload, headers)

    }
}

// MARK: - Tests
class APIConnectTests: XCTestCase {
    
    private let context = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    func testCheckFail() throws {
        let response = try MockDelayedAPIConnect
            .run(DelayedFromRequest(data: "x", responseURL: nil), context)
            .wait()
        XCTAssertEqual(response, FromResponse(data: "", error: true))
    }
    
    func testNormalRun() throws {
        let response = try MockAPIConnect
            .run(FromRequest(data: "x"), context)
            .wait()
        XCTAssertEqual(response, FromResponse(data: "x", error: false))
    }

    func testDelayedRun() throws {
        Environment.env["fromAPI"] = nil
        let response = try MockDelayedAPIConnect
            .run(DelayedFromRequest(data: "x", responseURL: URL(string: "https://test.com")), context)
            .wait()
        XCTAssertNil(response)
        XCTAssertEqual(Environment.env["fromAPI"], "x")
    }

    func testDelayedRunWithoutResponseURL() throws {
        Environment.env["fromAPI"] = nil
        DelayedFromRequest.check = { _, _, _ in nil }
        let response = try MockDelayedAPIConnect
            .run(DelayedFromRequest(data: "x", responseURL: nil), context)
            .wait()
        XCTAssertEqual(response, FromResponse(data: "x", error: false))
        XCTAssertNil(Environment.env["fromAPI"])
    }

    func testCheckConfigs() {
        do {
            try MockDelayedAPIConnect.checkConfigs()
            XCTFail("Should fail")
        } catch {
            if case let MockDelayedAPIConnect.APIConnectError.combined(errors) = error {
                XCTAssertEqual(errors.count, 3, "We haven't found all the errors")
            } else {
                XCTFail("Wrong error \(error)")
            }
        }
    }
    
}
