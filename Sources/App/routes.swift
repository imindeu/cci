import Routing
import Vapor
import APIConnect
import APIModels

public func routes(_ router: Router) throws {
    router.post(Slack.Request.self, at: "slackCommand", use: { req, slack in
        return SlackToCircleCi.run(slack, req)
    })
    router.post(Github.Payload.self, at: "githubWebhook", use: { req, payload in
        return req.http.body.consumeData(max: .max, on: req)
            .map { String(data: $0, encoding: .utf8) }
            .flatMap { GithubToYoutrack.run(payload, req, $0, req.http.headers) }
    })
}

extension Slack.Request: Content {}
extension Slack.Response: Content {}
extension Github.Payload: Content {}
extension Github.PayloadResponse: Content {}

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
