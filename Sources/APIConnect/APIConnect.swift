//
//  APIConnect.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

public struct APIConnect<From: RequestModel, To: RequestModel, E: APIConnectEnvironment> where From.ResponseModel: Encodable {

    public indirect enum APIConnectError: Error {
        case collision([From.Config])
        case fromMissing([From.Config])
        case toMissing([To.Config])
        case all([APIConnectError])
    }
    
    // check tokens and environment variables
    public let check: (_ from: From) -> From.ResponseModel?
    // slackrequest -> either<slackresponse, circlecirequest>
    public let request: (_ from: From) -> Either<From.ResponseModel, To>
    // circlecirequest -> either<slackresponse, circleciresponse>
    public let toAPI: (_ context: Context) -> (Either<From.ResponseModel, To>) -> IO<Either<From.ResponseModel, To.ResponseModel>>
    // circleciresponse -> slackresponse
    public let response: (_ from: To.ResponseModel) -> From.ResponseModel
    // slackresponse -> void
    public let fromAPI: (_ request: From, _ context: Context) -> (From.ResponseModel) -> IO<Void>
    // slackrequest -> slackresponse
    public let instant: (_ context: Context) -> (From) -> IO<From.ResponseModel>
    
    public init(check: @escaping (_ from: From) -> From.ResponseModel?,
         request: @escaping (_ from: From) -> Either<From.ResponseModel, To>,
         toAPI: @escaping (_ context: Context) -> (Either<From.ResponseModel, To>) -> IO<Either<From.ResponseModel, To.ResponseModel>>,
         response: @escaping (_ with: To.ResponseModel) -> From.ResponseModel,
         fromAPI: @escaping (_ request: From, _ context: Context) -> (From.ResponseModel) -> IO<Void>,
         instant: @escaping (_ context: Context) -> (From) -> IO<From.ResponseModel>) {
        
        self.check = check
        self.request = request
        self.toAPI = toAPI
        self.response = response
        self.fromAPI = fromAPI
        self.instant = instant
        
    }
}

public extension APIConnect {
    
    public static func checkConfigs() throws {
        var errors: [APIConnectError] = []
        let configCollision = From.Config.allCases.filter { To.Config.allCases.map { $0.rawValue }.contains($0.rawValue) }
        if !configCollision.isEmpty {
            errors += [.collision(configCollision)]
        }
        let fromCheck = From.check(E.self)
        if !fromCheck.isEmpty {
            errors += [.fromMissing(fromCheck)]
        }
        let toCheck = To.check(E.self)
        if !toCheck.isEmpty {
            errors += [.toMissing(toCheck)]
        }
        guard errors.isEmpty else {
            throw APIConnectError.all(errors)
        }
    }

    // main entry point (like: slackrequest -> slackresponse)
    public func run(_ from: From, _ context: Context) -> IO<From.ResponseModel> {
        if let response = check(from) {
            return pure(response, context)
        }
        guard from.responseURL != nil else {
            let run = pure(request(from), context)
                .flatMap(toAPI(context))
                .mapEither(id, response)
            return run
        }
        defer {
            let run = pure(request(from), context)
                .flatMap(toAPI(context))
                .mapEither(id, response)
            let _ = run.flatMap(fromAPI(from, context))
        }
        return instant(context)(from)
    }
}