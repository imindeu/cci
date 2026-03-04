import Vapor
import APIService
import APIConnect
import APIModels

public func routes(_ app: Application) throws {
    app.post("slackCommand") { req in
        let slack = try req.content.decode(Slack.Request.self)
        return SlackToCircleCi.run(slack, req.eventLoop)
    }
    
    app.on(.POST, "githubWebhook", body: .collect(maxSize: "2mb")) { req in
        guard let byteBuffer = req.body.data else { throw Abort(.badRequest) }
        
        let data = Data(buffer: byteBuffer)
        let github = try Service.decoder.decode(Github.Payload.self, from: data)
        let body = String(data: data, encoding: .utf8)
        return Github.webhook(github, req.eventLoop, body, req.headers)
    }

    app.get("status") { _ -> String in "OK" }
    /// This route will match everything that is not in other routes
    app.get(PathComponent.anything) { _ in "" }
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

extension Optional: @retroactive ResponseEncodable where Wrapped: ResponseEncodable {
    public func encodeResponse(for req: Vapor.Request) -> NIOCore.EventLoopFuture<Vapor.Response> {
        switch self {
        case let .some(some):
            return some.encodeResponse(for: req)
        case .none:
            return req.eventLoop.makeSucceededFuture(Response(status: .ok))
        }
    }
}

extension HTTPHeaders: Headers {
    public func get(_ name: String) -> String? {
        return self[name].first
    }
}
