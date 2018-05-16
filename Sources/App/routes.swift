import Routing
import Vapor

public func routes(_ router: Router) throws {
    router.slackCommand("command", use: commandAction)
}

typealias SlackCommandAction = (Request, SlackCommand) -> Future<SlackResponseRepresentable>

extension Router {
    func slackCommand(_ at: String, use: @escaping SlackCommandAction) {
        self.post(SlackCommand.self, at: at) { req, command -> Future<SlackResponse> in
            guard AppEnvironment.current.slackToken == command.token else {
                return Future.map(on: req) { AppEnvironmentError.wrongSlackToken.slackResponse }
            }
            return use(req, command).map { $0.slackResponse }
        }
    }
}

private func commandAction(req: Request, slackCommand: SlackCommand) -> Future<SlackResponseRepresentable> {
    do {
        let command = try Command(channel: slackCommand.channel_name, text: slackCommand.text)
        return command.fetch(worker: req)
    } catch let error {
        return Future.map(on: req) { CommandError.any(error: error) }
    }
}
