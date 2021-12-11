import Routing
import Vapor
import APIConnect
import APIModels

public func routes(_ router: Router) throws {
    router.post(Slack.Request.self, at: "slackCommand") { req, slack in
        return SlackToCircleCi.run(slack, req)
    }
    router.post(Github.Payload.self, at: "githubWebhook") { req, payload -> IO<Github.PayloadResponse?> in
        return req.http.body.consumeData(max: .max, on: req)
            .map(String.init)
            .flatMap(Github.webhook(payload, req, req.http.headers))
    }
    router.get("status") { _ -> String in
        return "OK"
    }
    /// This route will match everything that is not in other routes
    router.get(PathComponent.anything) { _ in "" }
}

extension Slack.Request: Content {}
extension Slack.Response: Content {}
extension Github.Payload: Content {}
extension Github.PayloadResponse: Content {}

private extension String {
    init?(data: Data) {
        self.init(data: data, encoding: .utf8)
    }
}

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
