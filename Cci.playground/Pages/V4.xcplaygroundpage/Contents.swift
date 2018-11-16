// MARK: - Vapor example
// in case of "error: missing required modules: ..."
// https://medium.com/@serzhit/how-to-make-vapor-3-swift-playground-in-xcode-10-c7147b0f7f18
import Foundation
import HTTP

typealias Context = EventLoopGroup
typealias IO = EventLoopFuture

// MARK: - Prelude

func id<A>(_ a: A) -> A {
    return a
}

public func const<A, B>(_ a: A) -> (B) -> A {
    return { _ in a }
}

public func const<A>(_ a: A) -> () -> A {
    return { a }
}

enum Either<L, R> {
    case left(L)
    case right(R)
}

extension Either {
    func either<A>(_ l2a: (L) -> A, _ r2a: (R) -> A) -> A {
        switch self {
        case let .left(l):
            return l2a(l)
        case let .right(r):
            return r2a(r)
        }
    }
    
    var left: L? {
        return either(Optional.some, const(.none))
    }
    
    var right: R? {
        return either(const(.none), Optional.some)
    }
    
    var isLeft: Bool {
        return either(const(true), const(false))
    }
    
    var isRight: Bool {
        return either(const(false), const(true))
    }
    
}

extension Either {
    func map<A>(_ r2a: (R) -> A) -> Either<L, A> {
        switch self {
        case let .left(l):
            return .left(l)
        case let .right(r):
            return .right(r2a(r))
        }
    }
    func flatMap<A>(_ r2a: (R) -> Either<L, A>) -> Either<L, A> {
        return either(Either<L, A>.left, r2a)
    }
}

func pure<A>(_ a: A, _ context: Context) -> IO<A> {
    return IO.map(on: context, const(a))
}

extension IO {
    func mapEither<A, L, R>(_ l2a: @escaping (L) -> A, _ r2a: @escaping (R) -> A) -> IO<A> where T == Either<L, R> {
        return map { $0.either(l2a, r2a) }
    }
}

// MARK: - Models

protocol Configuration: RawRepresentable & CaseIterable where RawValue == String {}

protocol RequestModel: Decodable {
    associatedtype Response: ResponseModel
    associatedtype Config: Configuration
    var responseURL: URL? { get }
}

extension RequestModel {
    static func check() -> [Config] {
        return Config.allCases.compactMap { Environment.get($0) == nil ? $0 : nil }
    }
}

protocol ResponseModel: Encodable {}

// MARK: - Side effects

struct Environment {
    var api: (String) -> (Context, HTTPRequest) -> IO<HTTPResponse> = { hostname in
            return { context, request in
                return HTTPClient
                    .connect(scheme: .https, hostname: hostname, port: nil, on: context)
                    .flatMap { $0.send(request) }
            }
        }
    
    var emptyApi: (Context) -> IO<HTTPResponse> = { pure(HTTPResponse(), $0) }
    
    static var env: [String: String] = ProcessInfo.processInfo.environment
    
    static func get<A: Configuration>(_ key: A) -> String? {
        return env[key.rawValue]
    }

}

// MARK: - APIConnect

struct APIConnect<From: RequestModel, To: RequestModel> {
    indirect enum APIConnectError: Error {
        case collision([From.Config])
        case fromMissing([From.Config])
        case toMissing([To.Config])
        case all([APIConnectError])
    }
    
    // check tokens and environment variables
    let check: (_ from: From) -> From.Response?
    // slackrequest -> either<slackresponse, circlecirequest>
    let request: (_ from: From, _ environment: Environment) -> Either<From.Response, To>
    // circlecirequest -> either<slackresponse, circleciresponse>
    let toAPI: (_ context: Context, _ environment: Environment) -> (Either<From.Response, To>) -> IO<Either<From.Response, To.Response>>
    // circleciresponse -> slackresponse
    let response: (_ with: To.Response) -> From.Response
    // slackresponse -> void
    let fromAPI: (_ request: From, _ context: Context, _ environment: Environment) -> (From.Response) -> IO<Void>
    // slackrequest -> slackresponse
    let instant: (_ context: Context, _ environment: Environment) -> (From) -> IO<From.Response>
    
    init(check: @escaping (_ from: From) -> From.Response?,
         request: @escaping (_ from: From, _ environment: Environment) -> Either<From.Response, To>,
         toAPI: @escaping (_ context: Context, _ environment: Environment) -> (Either<From.Response, To>) -> IO<Either<From.Response, To.Response>>,
         response: @escaping (_ with: To.Response) -> From.Response,
         fromAPI: @escaping (_ request: From, _ context: Context, _ environment: Environment) -> (From.Response) -> IO<Void>,
         instant: @escaping (_ context: Context, _ environment: Environment) -> (From) -> IO<From.Response>) throws {

        self.check = check
        self.request = request
        self.toAPI = toAPI
        self.response = response
        self.fromAPI = fromAPI
        self.instant = instant
        try checkConfigs()
        
    }
    
    private func checkConfigs() throws {
        var errors: [APIConnectError] = []
        let configCollision = From.Config.allCases.filter { To.Config.allCases.map { $0.rawValue }.contains($0.rawValue) }
        if !configCollision.isEmpty {
            errors += [.collision(configCollision)]
        }
        let fromCheck = From.check()
        if !fromCheck.isEmpty {
            errors += [.fromMissing(fromCheck)]
        }
        let toCheck = To.check()
        if !toCheck.isEmpty {
            errors += [.toMissing(toCheck)]
        }
        guard errors.isEmpty else {
            throw APIConnectError.all(errors)
        }
    }
}

extension APIConnect {
    
    // main entry point (like: slackrequest -> slackresponse)
    func run(_ from: From, _ context: Context, _ environment: Environment) -> IO<From.Response> {
        if let response = check(from) {
            return pure(response, context)
        }
        let run = pure(request(from, environment), context)
            .flatMap(toAPI(context, environment))
            .mapEither(id, response)
        guard from.responseURL != nil else {
            return run
        }
        defer {
            let _ = run.flatMap(fromAPI(from, context, environment))
        }
        return instant(context, environment)(from)
    }
}

// MARK: - Slack to CircleCi

struct SlackRequest: RequestModel {
    typealias Response = SlackResponse
    typealias Config = SlackConfig
    
    enum SlackConfig: String, Configuration {
        case slackToken
    }
    
    let token: String
    let team_id: String
    let team_domain: String
    let enterprise_id: String?
    let enterprise_name: String?
    let channel_id: String
    let channel_name: String
    let user_id: String
    let user_name: String
    let command: String
    let text: String
    let response_url: String
    let trigger_id: String
    
    var responseURL: URL? { return URL(string: response_url) }
}

extension SlackRequest {
    static func check(_ from: SlackRequest) -> SlackResponse? {
        fatalError()
    }
    static func api(_ request: SlackRequest, _ context: Context, _ environment: Environment) -> (SlackResponse) -> IO<Void> {
        return { response in
            guard let url = request.responseURL, let hostname = url.host, let body = try? JSONEncoder().encode(response) else {
                return environment.emptyApi(context).map { _ in () }
            }
            let returnAPI = environment.api(hostname)
            let request = HTTPRequest.init(method: .POST,
                                           url: url.path,
                                           headers: HTTPHeaders([("Content-Type", "application/json")]),
                                           body: HTTPBody(data: body))
            return returnAPI(context, request).map { _ in () }
        }
    }
    static func instant(_ context: Context, _ environment: Environment) -> (SlackRequest) -> IO<SlackResponse> {
        return const(pure(SlackResponse(response_type: .ephemeral, text: nil, attachments: [], mrkdwn: false), context))
    }
}

struct SlackResponse: Equatable, ResponseModel {
    enum ResponseType: String, Encodable {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    let response_type: ResponseType
    let text: String?
    var attachments: [Attachment]
    let mrkdwn: Bool?
    
    struct Attachment: Equatable, Encodable {
        let fallback: String?
        let text: String?
        let color: String?
        let mrkdwn_in: [String]
        let fields: [Field]
    }
    
    struct Field: Equatable, Encodable {
        let title: String?
        let value: String?
        let short: Bool?
    }
}

struct CircleCiTestJobRequest: Equatable, RequestModel {
    typealias Response = CircleCiBuildResponse
    typealias Config = CircleCiConfig
    
    enum CircleCiConfig: String, Configuration {
        case circleCiToken
    }
    
    let name: String = "test"
    let project: String
    let branch: String
    let options: [String]
    let username: String
    let responseURL: URL? = nil
}

extension CircleCiTestJobRequest {
    static func slackRequest(_ from: SlackRequest, _ environment: Environment) -> Either<SlackResponse, CircleCiTestJobRequest> {
        fatalError()
    }
    static func apiWithSlack(_ context: Context, _ environment: Environment) -> (Either<SlackResponse, CircleCiTestJobRequest>) -> IO<Either<SlackResponse, CircleCiBuildResponse>> {
        fatalError()
    }
    static func responseToSlack(_ with: CircleCiBuildResponse) -> SlackResponse {
        fatalError()
    }
}

struct CircleCiBuildResponse: ResponseModel {
    let build_url: String
    let build_num: Int
}

extension APIConnect where From == SlackRequest {
    init(request: @escaping (_ from: SlackRequest, _ environment: Environment) -> Either<SlackResponse, To>,
         toAPI: @escaping (_ context: Context, _ environment: Environment) -> (Either<SlackResponse, To>) -> IO<Either<SlackResponse, To.Response>>,
         response: @escaping (_ with: To.Response) -> SlackResponse) throws {
        try self.init(check: SlackRequest.check,
                      request: request,
                      toAPI: toAPI,
                      response: response,
                      fromAPI: SlackRequest.api,
                      instant: SlackRequest.instant)
    }
}

extension APIConnect where From == SlackRequest, To == CircleCiTestJobRequest {
    static func slackToCircleCiTest() throws -> APIConnect {
        return try APIConnect<SlackRequest, CircleCiTestJobRequest>(request: CircleCiTestJobRequest.slackRequest,
                                                                toAPI: CircleCiTestJobRequest.apiWithSlack,
                                                                response: CircleCiTestJobRequest.responseToSlack)
    }
}

// start
//APIConnect<SlackRequest, CircleCiTestJobRequest>.slackToCircleCiTest().run(<#T##from: SlackRequest##SlackRequest#>, <#T##context: Context##Context#>, <#T##environment: Environment##Environment#>)
