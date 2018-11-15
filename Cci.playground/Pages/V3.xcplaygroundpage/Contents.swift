// MARK: - Vapor, NIO try
// in case of 'error: missing required modules: ...
// https://medium.com/@serzhit/how-to-make-vapor-3-swift-playground-in-xcode-10-c7147b0f7f18
import Foundation
import NIO
import Core
import HTTP

// MARK: - Prelude

func id<A>(_ a: A) -> A {
    return a
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
        return either(Optional.some, { _ in .none })
    }
    
    var right: R? {
        return either({ _ in .none }, Optional.some)
    }
    
    var isLeft: Bool {
        return either({ _ in true }, { _ in false })
    }
    
    var isRight: Bool {
        return either({ _ in false }, { _ in true })
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

// MARK: - Models

protocol RequestModel {
    associatedtype Response: ResponseModel
    associatedtype Config: RawRepresentable & CaseIterable where Config.RawValue == String
    var responseURL: URL? { get }
}

extension RequestModel {
    static func check(_ request: Self? = nil, _ environment: Environment) -> [Config] {
        return Config.allCases.compactMap(hasConfig(request, environment))
    }
    private static func hasConfig(_ request: Self?, _ environment: Environment) -> (Config) -> Config? {
        return { config in
            let value = environment.get(config) ?? request?.get(config)
            return value == nil ? config : nil
        }
    }
    private func get(_ config: Config) -> String? {
        return Mirror(reflecting: self).children
            .first(where: { $0.label == config.rawValue })
            .flatMap { $0.value as? String }
    }
}

protocol ResponseModel {}

struct SlackRequest: Decodable, RequestModel {
    typealias Response = SlackResponse
    typealias Config = SlackConfig
    
    enum SlackConfig: String, CaseIterable {
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
    static func check(_ request: SlackRequest, _ environment: Environment) -> SlackResponse? {
        fatalError()
    }
    static func api(_ context: Context, _ environment: Environment) -> (SlackResponse) -> IO<Void> {
        fatalError()
    }
    static func instant(_ context: Context, _ environment: Environment) -> (SlackRequest) -> IO<SlackResponse> {
        fatalError()
    }
}

struct SlackResponse: Equatable, Encodable, ResponseModel {
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
    
    enum CircleCiConfig: String, CaseIterable {
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
    static func checkSlack(_ environment: Environment) -> SlackResponse? {
        fatalError()
    }
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

struct CircleCiBuildResponse: Decodable, ResponseModel {
    let build_url: String
    let build_num: Int
}

// MARK: - Side effects

typealias Context = EventLoopGroup
typealias IO = EventLoopFuture

typealias Request = HTTPRequest
typealias Response = HTTPResponse

protocol Environment {
    static var api: (String) -> (Context, Request) -> IO<Response> { get }

    func get<A>(_ a: A) -> String? where A: RawRepresentable & CaseIterable, A.RawValue == String
}

func pure<A>(_ a: A, _ context: Context) -> IO<A> {
    return IO.map(on: context, { a })
}

extension IO {
    func mapEither<A, L, R>(_ l2a: @escaping (L) -> A, _ r2a: @escaping (R) -> A) -> IO<A> where T == Either<L, R> {
        return map { $0.either(l2a, r2a) }
    }
}

// MARK: - APIConnect

struct APIConnect<From: RequestModel, To: RequestModel> {
    // check tokens
    let checkFrom: (_ request: From, _ environment: Environment) -> From.Response?
    let checkTo: (_ environment: Environment) -> From.Response?
    // slackrequest -> either<slackresponse, circlecirequest>
    let request: (_ from: From, _ environment: Environment) -> Either<From.Response, To>
    // circlecirequest -> either<slackresponse, circleciresponse>
    let toAPI: (_ context: Context, _ environment: Environment) -> (Either<From.Response, To>) -> IO<Either<From.Response, To.Response>>
    // circleciresponse -> slackresponse
    let response: (_ with: To.Response) -> From.Response
    // slackresponse -> void
    let fromAPI: (_ context: Context, _ environment: Environment) -> (From.Response) -> IO<Void>
    // slackrequest -> slackresponse
    let instant: (_ context: Context, _ environment: Environment) -> (From) -> IO<From.Response>
}

extension APIConnect {
    // main entry point (like: slackrequest -> slackresponse)
    func run(_ from: From, _ context: Context, _ environment: Environment) -> IO<From.Response> {
        if let error = checkFrom(from, environment) ?? checkTo(environment) {
            return pure(error, context)
        }
        let run = pure(request(from, environment), context)
            .flatMap(toAPI(context, environment))
            .mapEither(id, response)
        guard from.responseURL != nil else {
            return run
        }
        defer {
            let _ = run.flatMap(fromAPI(context, environment))
        }
        return instant(context, environment)(from)
    }
}

extension APIConnect where From == SlackRequest {
    init(checkTo: @escaping (_ environment: Environment) -> SlackResponse?,
         request: @escaping (_ from: SlackRequest, _ environment: Environment) -> Either<SlackResponse, To>,
         toAPI: @escaping (_ context: Context, _ environment: Environment) -> (Either<SlackResponse, To>) -> IO<Either<SlackResponse, To.Response>>,
         response: @escaping (_ with: To.Response) -> SlackResponse) {
        self.init(checkFrom: SlackRequest.check,
                  checkTo: checkTo,
                  request: request,
                  toAPI: toAPI,
                  response: response,
                  fromAPI: SlackRequest.api,
                  instant: SlackRequest.instant)
    }
}

extension APIConnect where From == SlackRequest, To == CircleCiTestJobRequest {
    static var slackToCircleCiTest: APIConnect {
        return APIConnect<SlackRequest, CircleCiTestJobRequest>(checkTo: CircleCiTestJobRequest.checkSlack,
                                                                request: CircleCiTestJobRequest.slackRequest,
                                                                toAPI: CircleCiTestJobRequest.apiWithSlack,
                                                                response: CircleCiTestJobRequest.responseToSlack)
    }
}

// start
//APIConnect<SlackRequest, CircleCiTestJobRequest>.slackToCircleCiTest.run(<#T##from: SlackRequest##SlackRequest#>, <#T##context: Context##Context#>, <#T##environment: Environment##Environment#>)
