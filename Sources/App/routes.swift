import Routing
import Vapor

public func routes(_ router: Router) throws {
    router.slackCommand("command", use: commandAction)
}

typealias SlackAction = (Request, SlackRequest) -> Future<SlackResponseRepresentable>

extension Router {
    func slackCommand(_ at: String, use: @escaping SlackAction) {
        self.post(SlackRequest.self, at: at) { req, slack -> Future<SlackResponse> in
            guard AppEnvironment.current.slackToken == slack.token else {
                return Future.map(on: req) { SlackResponse.error(text: "Error: wrong slackToken") }
            }
            return use(req, slack).map { $0.slackResponse }
        }
    }
}

private func commandAction(req: Request, slack: SlackRequest) -> Future<SlackResponseRepresentable> {
    do {
        let command = try Command(channel: slack.channel_name, text: slack.text)
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
