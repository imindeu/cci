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

// MARK: - APIConnect Spec

protocol RequestModel {
    associatedtype Response: ResponseModel
    var responseURL: URL? { get }
}
protocol ResponseModel {}

protocol Context {}

protocol Environment {}

struct APIConnect<From: RequestModel, To: RequestModel> {
    // check tokens
    let check: (_ request: From, _ environment: Environment) -> From.Response?
    // slackrequest -> either<slackresponse, circlecirequest>
    let request: (_ from: From, _ environment: Environment) -> Either<From.Response, To>
    // circlecirequest -> either<slackresponse, circleciresponse>
    let innerAPI: (_ context: Context, _ environment: Environment) -> (Either<From.Response, To>) -> IO<Either<From.Response, To.Response>>
    // circleciresponse -> slackresponse
    let response: (_ with: To.Response) -> From.Response
    // slackresponse -> void
    let outerAPI: (_ context: Context, _ environment: Environment) -> (From.Response) -> IO<Void>
    // slackrequest -> slackresponse
    let defaultOuterAPI: (_ context: Context, _ environment: Environment) -> (From) -> IO<From.Response>
}

extension APIConnect {
    // main entry point (like: slackrequest -> slackresponse)
    func run(_ from: From, context: Context, _ environment: Environment) -> IO<From.Response> {
        if let error = check(from, environment) {
            return pure(error)
        }
        let run = pure(request(from, environment))
            .flatMap(innerAPI(context, environment))
            .mapEither(id, response)
        guard from.responseURL != nil else {
            return run
        }
        defer {
            let _ = run.flatMap(outerAPI(context, environment))
        }
        return defaultOuterAPI(context, environment)(from)
    }
}
