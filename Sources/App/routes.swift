import Routing
import Vapor
import APIConnect
import APIModels

public func routes(_ router: Router) throws {
    router.post(SlackRequest.self, at: "command", use: { req, slack in
        return SlackToCircleCi.run(slack, req)
    })
}

