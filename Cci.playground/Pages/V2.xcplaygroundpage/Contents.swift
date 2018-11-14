import Foundation

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

struct IO<A> {
    let perform: () -> A
    init(perform: @escaping () -> A) {
        self.perform = perform
    }
}

func pure<A>(_ a: A) -> IO<A> {
    return IO { a }
}

extension IO {
    func map<B>(_ f: @escaping (A) -> B) -> IO<B> {
        return IO<B> {
            f(self.perform())
        }
    }
    func flatMap<B>(_ f: @escaping (A) -> IO<B>) -> IO<B> {
        return IO<B> {
            f(self.perform()).perform()
        }
    }
}

extension IO {
    func mapEither<B, L, R>(_ l2a: @escaping (L) -> B, _ r2a: @escaping (R) -> B) -> IO<B> where A == Either<L, R> {
        return map { $0.either(l2a, r2a) }
    }
}

// MARK: - Models

protocol RequestModel {
    associatedtype Response: ResponseModel
    var responseURL: URL? { get }
}

protocol ResponseModel {}

struct SlackRequest: Decodable, RequestModel {
    typealias Response = SlackResponse
    
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

struct CircleCiDeployJobRequest: Equatable, RequestModel {
    typealias Response = CircleCiBuildResponse
    let name: String = "deploy"
    let project: String
    let branch: String
    let options: [String]
    let username: String
    let type: String
    let responseURL: URL? = nil
}

struct CircleCiBuildResponse: Decodable, ResponseModel {
    let build_url: String
    let build_num: Int
}

// MARK: - Side effects

protocol Context {}

protocol Environment {}

// MARK: - APIConnect

struct APIConnect<From: RequestModel, To: RequestModel> {
    // check tokens
    let check: (_ request: From, _ environment: Environment) -> From.Response?
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
    func run(_ from: From, context: Context, _ environment: Environment) -> IO<From.Response> {
        if let error = check(from, environment) {
            return pure(error)
        }
        let run = pure(request(from, environment))
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
    init(request: @escaping (_ from: SlackRequest, _ environment: Environment) -> Either<SlackResponse, To>,
         toAPI: @escaping (_ context: Context, _ environment: Environment) -> (Either<SlackResponse, To>) -> IO<Either<SlackResponse, To.Response>>,
         response: @escaping (_ with: To.Response) -> SlackResponse) {
        self.init(check: SlackRequest.check,
                  request: request,
                  toAPI: toAPI,
                  response: response,
                  fromAPI: SlackRequest.api,
                  instant: SlackRequest.instant)
    }
}

extension APIConnect where From == SlackRequest, To == CircleCiTestJobRequest {
    static var slackToCircleCiTest: APIConnect {
        return APIConnect<SlackRequest, CircleCiTestJobRequest>(request: CircleCiTestJobRequest.slackRequest,
                                                                toAPI: CircleCiTestJobRequest.apiWithSlack,
                                                                response: CircleCiTestJobRequest.responseToSlack)
    }
}

