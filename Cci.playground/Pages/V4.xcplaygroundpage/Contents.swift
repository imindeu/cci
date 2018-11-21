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

protocol RequestModel {
    associatedtype Response: ResponseModel
    associatedtype Config: Configuration
    var responseURL: URL? { get }
}

extension RequestModel {
    static func check() -> [Config] {
        return Config.allCases.compactMap { Environment.get($0) == nil ? $0 : nil }
    }
}

protocol ResponseModel {}

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

struct APIConnect<From: RequestModel, To: RequestModel> where From.Response: Encodable, To.Response: Decodable {
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
        guard URL(string: from.response_url) != nil else {
            return SlackResponse.error(text: "Error: bad response_url")
        }
        return nil
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

struct SlackResponse: ResponseModel, Encodable {
    enum ResponseType: String, Encodable {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    let response_type: ResponseType
    let text: String?
    var attachments: [Attachment]
    let mrkdwn: Bool?
    
    struct Attachment: Encodable {
        let fallback: String?
        let text: String?
        let color: String?
        let mrkdwn_in: [String]
        let fields: [Field]
    }
    
    struct Field: Encodable {
        let title: String?
        let value: String?
        let short: Bool?
    }
}

extension SlackResponse {
    static func error(text: String, helpResponse: SlackResponse? = nil) -> SlackResponse {
        let attachment = SlackResponse.Attachment(fallback: text, text: text, color: "danger", mrkdwn_in: [], fields: [])
        guard let helpResponse = helpResponse else {
            return SlackResponse(response_type: .ephemeral, text: nil, attachments: [attachment], mrkdwn: true)
        }
        var copy = helpResponse
        let attachments = copy.attachments
        copy.attachments = [attachment] + attachments
        return copy
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

enum CircleCiError: Error {
    case noChannel(String)
    case unknownCommand(String)
    case parse(String)
}

protocol CircleCiJob {
    var name: String { get }
    var project: String { get }
    var branch: String { get }
    var options: [String] { get }
    var username: String { get }
    
    static var helpResponse: SlackResponse { get }
    
    static func parse(project: String, parameters: [String], options:[String], username: String) throws -> Either<SlackResponse, CircleCiJob>
}

enum CircleCiJobKind: String, CaseIterable {
    case deploy
    case test
}

extension CircleCiJobKind {
    var type: CircleCiJob.Type {
        switch self {
        case .deploy:
            return CircleCiDeployJob.self
        case .test:
            return CircleCiTestJob.self
        }
    }
}

struct CircleCiTestJob: CircleCiJob {
    let name: String = CircleCiJobKind.test.rawValue
    let project: String
    let branch: String
    let options: [String]
    let username: String
}

extension CircleCiTestJob {
    static var helpResponse: SlackResponse {
        let text = "`test`: test a branch\n" +
            "Usage:\n`/cci test branch [options]`\n" +
            "  - *branch*: branch name to test\n" +
        "  - *options*: optional fastlane options in the xyz:qwo format\n"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
    }
    
    static func parse(project: String, parameters: [String], options:[String], username: String) throws -> Either<SlackResponse, CircleCiJob> {
        guard parameters.count > 0 else {
            throw CircleCiError.parse("No branch found: (\(parameters.joined(separator: " ")))")
        }
        guard parameters[0] != "help" else {
            return .left(CircleCiTestJob.helpResponse)
        }
        let branch = parameters[0]
        return .right(CircleCiTestJob(project: project, branch: branch, options: options, username: username))
        
    }
}

struct CircleCiDeployJob: CircleCiJob {
    let name: String = CircleCiJobKind.deploy.rawValue
    let project: String
    let branch: String
    let options: [String]
    let username: String
    let type: String
}

extension CircleCiDeployJob {
    static var helpResponse: SlackResponse {
        let text = "`deploy`: deploy a build\n" +
            "Usage:\n`/cci deploy type [options] [branch]`\n" +
            "  - *type*: alpha|beta|app_store\n" +
            "  - *options*: optional fastlane options in the xyz:qwo format\n" +
            "    (eg. emails:xy@test.com,zw@test.com groups:qa,beta-customers version:2.0.1)\n" +
            "    (space shouldn't be in the option for now)\n" +
            "  - *branch*: an optional branch name to deploy from\n" +
            "  If emails and groups are both set, emails will be used\n" +
            "  (currently available options, maybe not up to date: " +
        "    emails, groups, use_git, version, skip_xcode_version_check)"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
    }
    
    static func parse(project: String, parameters: [String], options: [String], username: String) throws -> Either<SlackResponse, CircleCiJob> {
        if parameters.count == 1 && parameters[0] == "help" {
            return .left(CircleCiDeployJob.helpResponse)
        }
        let types = [
            "alpha": "dev",
            "beta": "master",
            "app_store": "release"]
        if parameters.count == 0 || !types.keys.contains(parameters[0]) {
            throw CircleCiError.parse("Unknown type: (\(parameters.joined(separator: " ")))")
        }
        let type = parameters[0]
        guard let branch = parameters[safe: 1] ?? types[type] else {
            throw CircleCiError.parse("No branch found: (\(parameters.joined(separator: " ")))")
        }
        return .right(CircleCiDeployJob(project: project, branch: branch, options: options, username: username, type: type))
    }
}

struct CircleCiJobRequest: RequestModel {
    typealias Response = CircleCiBuildResponse
    typealias Config = CircleCiConfig
    
    enum CircleCiConfig: String, Configuration {
        case circleCiTokens
        case company
        case vcs
        case projects
    }
    
    let job: CircleCiJob
    let responseURL: URL? = nil
}

extension CircleCiJobRequest {
    static var helpResponse: SlackResponse {
        let text = "Help:\n- `/cci command [help]`\n" +
            "Current command\n" +
            "  - help: show this message\n" +
            "  - deploy: deploy a build\n" +
            "  - test: test a branch\n\n" +
        "All commands have a help subcommand to show their functionality\n"
        let attachment = SlackResponse.Attachment(
            fallback: text, text: text, color: "good", mrkdwn_in: ["text"], fields: [])
        let response = SlackResponse(response_type: .ephemeral, text: "Send commands to <https://circleci.com|CircleCI>", attachments: [attachment], mrkdwn: true)
        return response
    }
    
    static func slackRequest(_ from: SlackRequest, _ environment: Environment) -> Either<SlackResponse, CircleCiJobRequest> {
        let projects: [String] = Environment.get(CircleCiConfig.projects)?.split(separator: ",").map(String.init) ?? []
        
        guard let index = projects.index(where: { from.channel_name.hasPrefix($0) }) else {
            return .left(SlackResponse.error(text: CircleCiError.noChannel(from.channel_name).localizedDescription))
        }
        let project = projects[index]
        
        var parameters = from.text.split(separator: " ").map(String.init).filter({ !$0.isEmpty })
        guard parameters.count > 0 else {
            return .left(SlackResponse.error(text: CircleCiError.unknownCommand(from.text).localizedDescription))
        }
        let command = parameters[0]
        parameters.removeFirst()
        
        let isOption: (String) -> Bool = { $0.contains(":") }
        let options = parameters.filter(isOption)
        parameters = parameters.filter { !isOption($0) }
        
        if let job = CircleCiJobKind(rawValue: command) {
            do {
                return try job.type.parse(project: project, parameters: parameters, options: options, username: from.user_name).flatMap { .right(CircleCiJobRequest(job: $0)) }
            } catch {
                return .left(SlackResponse.error(text: error.localizedDescription, helpResponse: job.type.helpResponse))
            }
        } else if command == "help" {
            return .left(helpResponse)
        } else {
            return .left(SlackResponse.error(text: CircleCiError.unknownCommand(from.text).localizedDescription))
        }
    }
    static func apiWithSlack(_ context: Context, _ environment: Environment) -> (Either<SlackResponse, CircleCiJobRequest>) -> IO<Either<SlackResponse, CircleCiBuildResponse>> {
        fatalError()
    }
    static func responseToSlack(_ with: CircleCiBuildResponse) -> SlackResponse {
        fatalError()
    }
}

struct CircleCiBuildResponse: ResponseModel, Decodable {
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

extension APIConnect where From == SlackRequest, To == CircleCiJobRequest {
    static func slackToCircleCiTest() throws -> APIConnect {
        return try APIConnect<SlackRequest, CircleCiJobRequest>(request: CircleCiJobRequest.slackRequest,
                                                                toAPI: CircleCiJobRequest.apiWithSlack,
                                                                response: CircleCiJobRequest.responseToSlack)
    }
}

// start
//APIConnect<SlackRequest, CircleCiJobRequest>.slackToCircleCiTest().run(<#T##from: SlackRequest##SlackRequest#>, <#T##context: Context##Context#>, <#T##environment: Environment##Environment#>)
