//
//  APIConnect.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//

public struct APIConnect<From: RequestModel, To: RequestModel, E: APIConnectEnvironment>
    where From.ResponseModel: Encodable {

    public indirect enum APIConnectError: Error {
        case collision([From.Config])
        case fromMissing([From.Config])
        case toMissing([To.Config])
        case combined([APIConnectError])
    }
    
    public let check: (_ from: From, _ payload: String?, _ headers: Headers?) -> From.ResponseModel?
    public let request: (_ from: From) -> Either<From.ResponseModel, [To]>
    public let toAPI: (_ context: Context)
        -> (Either<From.ResponseModel, [To]>)
        -> EitherIO<From.ResponseModel, [To.ResponseModel]>
    public let response: (_ from: [To.ResponseModel]) -> From.ResponseModel
    public let fromAPI: ((_ request: From, _ context: Context) -> (From.ResponseModel) -> IO<Void>)?
    public let instant: ((_ context: Context) -> (From) -> IO<From.ResponseModel?>)?
}

public extension APIConnect {
    
    public init(check: @escaping (_ from: From, _ payload: String?, _ headers: Headers?) -> From.ResponseModel?,
                request: @escaping (_ from: From) -> Either<From.ResponseModel, [To]>,
                toAPI: @escaping (_ context: Context)
                    -> (Either<From.ResponseModel, [To]>)
                    -> EitherIO<From.ResponseModel, [To.ResponseModel]>,
                response: @escaping (_ with: [To.ResponseModel]) -> From.ResponseModel) {
        
        self.check = check
        self.request = request
        self.toAPI = toAPI
        self.response = response
        self.fromAPI = nil
        self.instant = nil
        
    }
}

public extension APIConnect {
    
    public static func checkConfigs() throws {
        var errors: [APIConnectError] = []
        let configCollision = From.Config.allCases.filter {
            To.Config.allCases.map { $0.rawValue }.contains($0.rawValue)
        }
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
            throw APIConnectError.combined(errors)
        }
    }
    
    public func run(_ from: From, _ context: Context, _ payload: String?, _ headers: Headers?) -> IO<From.ResponseModel?> {
        if let response = check(from, payload, headers) {
            return pure(response, context)
        }
        return pure(request(from), context)
            .flatMap(toAPI(context))
            .mapEither(id, response)
            .map(Optional.some)
    }

}

public extension APIConnect where From: DelayedRequestModel {
    
    public init(check: @escaping (_ from: From, _ payload: String?, _ headers: Headers?) -> From.ResponseModel?,
                request: @escaping (_ from: From) -> Either<From.ResponseModel, [To]>,
                toAPI: @escaping (_ context: Context)
                    -> (Either<From.ResponseModel, [To]>)
                    -> EitherIO<From.ResponseModel, [To.ResponseModel]>,
                response: @escaping (_ with: [To.ResponseModel]) -> From.ResponseModel,
                fromAPI: @escaping (_ request: From, _ context: Context)
                    -> (From.ResponseModel)
                    -> IO<Void>,
                instant: @escaping (_ context: Context) -> (From) -> IO<From.ResponseModel?>) {
        
        self.check = check
        self.request = request
        self.toAPI = toAPI
        self.response = response
        self.fromAPI = fromAPI
        self.instant = instant
        
    }

    public func run(_ from: From, _ context: Context, _ payload: String?, _ headers: Headers?) -> IO<From.ResponseModel?> {
        if let response = check(from, payload, headers) {
            return pure(response, context)
        }
        let run = pure(request(from), context)
            .flatMap(toAPI(context))
            .mapEither(id, response)
        guard from.responseURL != nil, let instant = instant, let fromAPI = fromAPI else {
            return run.map(Optional.some)
        }
        defer {
            _ = run.flatMap(fromAPI(from, context))
        }
        return instant(context)(from)
    }
}
