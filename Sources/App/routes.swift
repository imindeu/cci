import Routing
import Vapor
import APIConnect
import APIModels

public func routes(_ router: Router) throws {
    router.post(Slack.Request.self, at: "slackCommand", use: { req, slack in
        return SlackToCircleCi.run(slack, req)
    })
    router.post(GithubWebhook.Request.self, at: "githubWebhook", use: { req, webhook in
        return req.http.body.consumeData(max: .max, on: req)
            .map { String(data: $0, encoding: .utf8) }
            .flatMap { GithubToYoutrack.run(webhook, req, $0, req.http.headers) }
    })
}

extension Slack.Request: Content {}
extension Slack.Response: Content {}
extension GithubWebhook.Request: Content {}
extension GithubWebhook.Response: Content {}

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
