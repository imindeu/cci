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
    
    public let check: (From, String?, Headers?) -> From.ResponseModel?
    public let request: (From, Headers?, Context) -> EitherIO<From.ResponseModel, To>
    public let toAPI: (Context) -> (To) -> EitherIO<From.ResponseModel, To.ResponseModel>
    public let response: (To.ResponseModel) -> From.ResponseModel
    public let fromAPI: ((From, Context) -> (From.ResponseModel) -> IO<Void>)?
    public let instant: ((Context) -> (From) -> IO<From.ResponseModel?>)?
} 

public extension APIConnect {
    
    init(check: @escaping (From, String?, Headers?) -> From.ResponseModel?,
         request: @escaping (From, Headers?, Context) -> EitherIO<From.ResponseModel, To>,
         toAPI: @escaping (Context) -> (To) -> EitherIO<From.ResponseModel, To.ResponseModel>,
         response: @escaping (To.ResponseModel) -> From.ResponseModel) {
        
        self.check = check
        self.request = request
        self.toAPI = toAPI
        self.response = response
        self.fromAPI = nil
        self.instant = nil
        
    }
    
    func transformFrom<A: RequestModel>(check: @escaping (A, String?, Headers?) -> A.ResponseModel?,
                                        request: @escaping (A, Headers?, Context)
        -> EitherIO<A.ResponseModel, To>,
                                        transform: @escaping (From.ResponseModel) -> A.ResponseModel)
        -> APIConnect<A, To, E> {
            
        return APIConnect<A, To, E>(check: check,
                                    request: request,
                                    toAPI: { context -> (To) -> EitherIO<A.ResponseModel, To.ResponseModel> in
                                        return { self.toAPI(context)($0).bimapEither(transform, id) }
                                    },
                                    response: { transform(self.response($0)) })
    }
    
    func tranformTo<A: RequestModel>(request: @escaping (From, Headers?, Context)
        -> EitherIO<From.ResponseModel, A>,
                                     toAPI: @escaping (Context)
        -> (A)
        -> EitherIO<From.ResponseModel, A.ResponseModel>,
                                     response: @escaping (A.ResponseModel) -> From.ResponseModel)
        -> APIConnect<From, A, E> {
            
        return APIConnect<From, A, E>(check: self.check,
                                      request: request,
                                      toAPI: toAPI,
                                      response: response)
    }
    
}

public extension APIConnect {
    
    static func checkConfigs() throws {
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
    
    func run(_ from: From,
             _ context: Context,
             _ body: String?,
             _ headers: Headers?) -> IO<From.ResponseModel?> {
        if let response = check(from, body, headers) {
            return pure(response, context)
        }
        return request(from, headers, context)
            .flatMap(to(context, toAPI))
            .mapEither(id, response)
            .map(Optional.some)
    }

    private func to(_ context: Context,
                    _ right: @escaping (Context)
                        -> (To)
                        -> EitherIO<From.ResponseModel, To.ResponseModel>)
        -> (Either<From.ResponseModel, To>)
        -> EitherIO<From.ResponseModel, To.ResponseModel> {
            return { return $0.either(leftIO(context), right(context)) }
    }
}

public extension APIConnect where From: DelayedRequestModel {
    
    init(check: @escaping (From, String?, Headers?) -> From.ResponseModel?,
         request: @escaping (From, Headers?, Context) -> EitherIO<From.ResponseModel, To>,
         toAPI: @escaping (Context) -> (To) -> EitherIO<From.ResponseModel, To.ResponseModel>,
         response: @escaping (To.ResponseModel) -> From.ResponseModel,
         fromAPI: @escaping (From, Context) -> (From.ResponseModel) -> IO<Void>,
         instant: @escaping (Context) -> (From) -> IO<From.ResponseModel?>) {
        
        self.check = check
        self.request = request
        self.toAPI = toAPI
        self.response = response
        self.fromAPI = fromAPI
        self.instant = instant
        
    }

    func run(_ from: From,
             _ context: Context,
             _ body: String?,
             _ headers: Headers?) -> IO<From.ResponseModel?> {
        if let response = check(from, body, headers) {
            return pure(response, context)
        }
        let run = request(from, headers, context)
            .flatMap(to(context, toAPI))
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
