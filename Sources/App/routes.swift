import Routing
import Vapor

public func routes(_ router: Router) throws {
    // for local test, without the deferred answer
//    router.post(SlackRequest.self, at: "command", use: { req, slack in
//        return commandAction(req: req, slack: slack).map({ $0.slackResponse })
//    })
    router.slackCommand("command", use: commandAction)
}

extension Router {
    func slackCommand(_ at: String,
                      use: @escaping (Request, SlackRequest) -> Future<SlackResponseRepresentable>) {
        
        let responder = BasicResponder { req in
            return try SlackRequest.decode(from: req).flatMap { content in

                guard let url = URL(string: content.response_url) else {
                    return try SlackResponse.error(text: "Error: bad response_url")
                        .encode(for: req)
                }
                guard Environment.current.slackToken == content.token else {
                    return try SlackResponse.error(text: "Error: wrong slackToken")
                        .encode(for: req)
                }
                
                // slack needs fast response, so we send an empty status ok
                // and we send the real answer when it's done
                defer {
                    let _ = use(req, content)
                        .flatMap {
                            return Environment.current.slack(req, url, $0)
                        }
                }
                
                return Future.map(on: req, { return Response(http: .init(), using: req) })
            }
        }
        let route = Route<Responder>(
            path: [.constant("POST")] + at.convertToPathComponents(),
            output: responder)
        register(route: route)
    }
}

private func commandAction(req: Request, slack: SlackRequest) -> Future<SlackResponseRepresentable> {
    do {
        let command = try Command(slack: slack)
        return command.fetch(worker: req)
    } catch let error {
        return Future.map(on: req) {
            if let error = error as? SlackResponseRepresentable {
                return error
            } else {
                return CommandError.any(error: error)
            }
        }
    }
}
