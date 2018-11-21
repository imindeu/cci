//
//  APIConnect.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

public struct APIConnect<From: RequestModel, To: RequestModel> where From.Response: Encodable, To.Response: Decodable {
    public indirect enum APIConnectError: Error {
        case collision([From.Config])
        case fromMissing([From.Config])
        case toMissing([To.Config])
        case all([APIConnectError])
    }
    
    // check tokens and environment variables
    public let check: (_ from: From) -> From.Response?
    // slackrequest -> either<slackresponse, circlecirequest>
    public let request: (_ from: From, _ environment: Environment) -> Either<From.Response, To>
    // circlecirequest -> either<slackresponse, circleciresponse>
    public let toAPI: (_ context: Context, _ environment: Environment) -> (Either<From.Response, To>) -> IO<Either<From.Response, To.Response>>
    // circleciresponse -> slackresponse
    public let response: (_ with: To.Response) -> From.Response
    // slackresponse -> void
    public let fromAPI: (_ request: From, _ context: Context, _ environment: Environment) -> (From.Response) -> IO<Void>
    // slackrequest -> slackresponse
    public let instant: (_ context: Context, _ environment: Environment) -> (From) -> IO<From.Response>
    
    public init(check: @escaping (_ from: From) -> From.Response?,
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

public extension APIConnect {
    
    // main entry point (like: slackrequest -> slackresponse)
    public func run(_ from: From, _ context: Context, _ environment: Environment) -> IO<From.Response> {
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
