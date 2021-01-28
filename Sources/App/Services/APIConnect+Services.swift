//
//  APIConnect+Services.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 17..
//

import APIConnect
import APIModels

// MARK: - Custom types

typealias SlackToCircleCi = APIConnect<Slack.Request, CircleCi.JobRequest, Environment>
typealias GithubToYoutrack = APIConnect<Github.Payload, Youtrack.Request, Environment>
typealias GithubToGithub = APIConnect<Github.Payload, Github.APIRequest, Environment>
typealias GithubToCircleCi = APIConnect<Github.Payload, CircleCi.JobRequest, Environment>

// MARK: - Custom inits

extension APIConnect {
    static var slackToCircleCi: SlackToCircleCi {
        return SlackToCircleCi(request: CircleCi.slackRequest,
                               toAPI: CircleCi.apiWithSlack,
                               response: CircleCi.responseToSlack)
    }
    
    static var githubToCircleCi: GithubToCircleCi {
        return slackToCircleCi.transformFrom(check: Github.check,
                                             request: CircleCi.githubRequest,
                                             transform: CircleCi.slackToGithubResponse)
    }
    
    static var githubToYoutrack: GithubToYoutrack {
        return githubToCircleCi.tranformTo(request: Youtrack.githubRequest,
                                           toAPI: Youtrack.apiWithGithub,
                                           response: Youtrack.responseToGithub)
    }
    
    static var githubToGithub: GithubToGithub {
        return githubToCircleCi.tranformTo(request: Github.githubRequest,
                                           toAPI: Github.apiWithGithub,
                                           response: Github.responseToGithub)
    }
}

// MARK: Slack.Request
extension APIConnect where From == Slack.Request {
    init(request: @escaping (Slack.Request, Headers?, Context) -> EitherIO<Slack.Response, To>,
         toAPI: @escaping (Context) -> (To) -> EitherIO<Slack.Response, To.ResponseModel>,
         response: @escaping (To.ResponseModel) -> Slack.Response) {
        self.init(check: Slack.check,
                  request: request,
                  toAPI: toAPI,
                  response: response,
                  fromAPI: Slack.api,
                  instant: Slack.instant)
    }
}

// MARK: - Custom runs

// MARK: Slack.Request -> CircleCi.JobRequest
extension APIConnect where From == Slack.Request, To == CircleCi.JobRequest {
    static func run(_ from: Slack.Request, _ context: Context) -> IO<Slack.Response?> {
        if Environment.isDebugMode() {
            let contextString = String(describing: context).replacingOccurrences(of: "&", with: "\n")
            print(" ==================== ")
            print(" INCOMING REQUEST\n")
            print("Context:\n\(contextString)\n")
            print("Slack request:\n\(from)\n")
        }
        return slackToCircleCi.run(from, context, nil, nil)
    }
}

// MARK: Github.Payload -> Youtrack.Request
extension APIConnect where From == Github.Payload, To == Youtrack.Request {
    static func run(_ from: Github.Payload,
                    _ context: Context,
                    _ body: String?,
                    _ headers: Headers?) -> IO<Github.PayloadResponse?> {
        return githubToYoutrack.run(from, context, body, headers)
    }
}

// MARK: Github.Payload -> Github.APIRequest
extension APIConnect where From == Github.Payload, To == Github.APIRequest {
    static func run(_ from: Github.Payload,
                    _ context: Context,
                    _ body: String?,
                    _ headers: Headers?) -> IO<Github.PayloadResponse?> {
        return githubToGithub.run(from, context, body, headers)
    }
}

// MARK: Github.Payload -> CircleCi.JobRequest
extension APIConnect where From == Github.Payload, To == CircleCi.JobRequest {
    static func run(_ from: Github.Payload,
                    _ context: Context,
                    _ body: String?,
                    _ headers: Headers?) -> IO<Github.PayloadResponse?> {
        return githubToCircleCi.run(from, context, body, headers)
    }
}

extension Github {
    public static func webhook(_ from: Github.Payload,
                               _ context: Context,
                               _ headers: Headers?) -> (String?) -> IO<Github.PayloadResponse?> {
        return {
            [GithubToYoutrack.run(from, context, $0, headers),
             GithubToGithub.run(from, context, $0, headers),
             GithubToCircleCi.run(from, context, $0, headers)]
                .flatten(on: context)
                .map(Github.reduce)
        }
    }
}
