import Routing
import Vapor
import APIConnect
import APIModels

public func routes(_ router: Router) throws {
    router.post(SlackRequest.self, at: "command", use: { req, slack in
        return SlackToCircleCi.run(slack, req)
    })
    router.post(GithubWebhookRequest.self, at: "g2y", use: { req, webhook in
        return req.http.body.consumeData(max: .max, on: req)
            .map { String(data: $0, encoding: .utf8) }
            .flatMap { GithubToYoutrack.run(webhook, req, $0, req.http.headers) }
    })
}

extension SlackRequest: Content {}
extension SlackResponse: Content {}
extension GithubWebhookRequest: Content {}
extension GithubWebhookResponse: Content {}

extension Optional: ResponseEncodable where Wrapped: ResponseEncodable {
    public func encode(for req: Request) throws -> EventLoopFuture<Response> {
        switch self {
        case let .some(some):
            return try some.encode(for: req)
        case .none:
            return req.future(Response(http: .init(), using: req))
        }
    }
    
}

extension HTTPHeaders: Headers {
    public func get(_ name: String) -> String? {
        return self[name].first
    }
}
