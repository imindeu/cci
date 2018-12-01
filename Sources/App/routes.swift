import Routing
import Vapor
import APIModels

protocol DecodableContent: Decodable, RequestDecodable {}
extension DecodableContent {
    public static func decode(from req: Request) throws -> Future<Self> {
        return try req.content.decode(Self.self)
    }
}

extension SlackRequest: DecodableContent {}

extension SlackResponse: Content {}

public func routes(_ router: Router) throws {
    router.post(SlackRequest.self, at: "command", use: { req, slack in
        return SlackToCircleCi.run(slack, req)
    })
}

