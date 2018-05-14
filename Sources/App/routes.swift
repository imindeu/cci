import Routing
import Vapor

public func routes(_ router: Router) throws {
    router.post(SlackCommand.self, at: "command", use: commandAction)
}

func commandAction(req: Request, slackCommand: SlackCommand) -> Future<SlackResponse> {
    return token(slackCommand: slackCommand).map(
        { response in return Future.map(on: req, { return response })},
        { config in return command(slackCommand, config: config, worker: req) })
}

func token(slackCommand: SlackCommand) -> Either<SlackResponse, AppConfig> {
    guard let circleciToken = Environment.get("circleciToken") else {
        return .left(SlackResponse(responseType: .ephemeral, text: "Error: no circleciToken found", attachements: []))
    }
    guard let slackToken = Environment.get("slackToken"), slackCommand.token == slackToken else {
        return .left(SlackResponse(responseType: .ephemeral, text: "Error: slackToken mismatch found", attachements: []))
    }
    guard let company = Environment.get("company") else {
        return .left(SlackResponse(responseType: .ephemeral, text: "Error: company not found found", attachements: []))
    }
    guard let vcs = Environment.get("vcs") else {
        return .left(SlackResponse(responseType: .ephemeral, text: "Error: vcs not found found", attachements: []))
    }
    guard let projects = Environment.get("projects")?.split(separator: ",").map(String.init) else {
        return .left(SlackResponse(responseType: .ephemeral, text: "Error: projects not found found", attachements: []))
    }
    return .right(AppConfig(circleciToken: circleciToken, company: company, vcs: vcs, projects: projects))
}

func command(_ slackCommand: SlackCommand, config: AppConfig, worker: Worker) -> Future<SlackResponse> {
    do {
        let cciCommand = try Command(channel: slackCommand.channel_name, text: slackCommand.text, projects: config.projects)
        let parsed = cciCommand.parse(config: config)
        switch parsed {
        case .left(let request):
            return fetch(request: request, worker: worker)
        case .right(let slackResponse):
            return Future.map(on: worker) { return slackResponse }
        }
    } catch let error {
        return Future.map(on: worker) {
            if let error = error as? CommandError {
                return error.slackResponse
            } else {
                return SlackResponse(responseType: .ephemeral, text: "Error", attachements: [])
            }
        }
    }
}

func fetch(request: HTTPRequest, worker: Worker) -> Future<SlackResponse> {
    return HTTPClient
        .connect(scheme: .https, hostname: "circleci.com", port: nil, on: worker)
        .flatMap({ client -> Future<SlackResponse> in
            return client.send(request)
                .map({ response -> CircleciResponse? in
                    return try response.body.data
                        .map({ try JSONDecoder().decode(CircleciResponse.self, from: $0) })
                })
                .map({ ci -> SlackResponse in
                    if let ci = ci {
                        return SlackResponse(responseType: .inChannel, text: "Deploy has started at \(ci.build_url)", attachements: [])
                    } else {
                        return SlackResponse(responseType: .ephemeral, text: "Error: something went wrong. The build wasn't started", attachements: [])
                    }
                })
        })
}
