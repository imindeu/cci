//
//  APIConnect+Services.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 17..
//

import APIConnect
import APIModels

// MARK: - Custom types

typealias GithubToYoutrack = APIConnect<Github.Payload, Youtrack.Request, Environment>
typealias GithubToGithub = APIConnect<Github.Payload, Github.APIRequest, Environment>
typealias GithubToCircleCi = APIConnect<Github.Payload, CircleCi.JobRequest, Environment>
typealias SlackToCircleCi = APIConnect<Slack.Request, CircleCi.JobRequest, Environment>

// MARK: - Custom inits

// MARK: Github.Payload
extension APIConnect where From == Github.Payload {
    init(request: @escaping (_ from: Github.Payload, _ headers: Headers?) -> Either<Github.PayloadResponse, To>,
         toAPI: @escaping (_ context: Context)
        -> (To)
        -> EitherIO<Github.PayloadResponse, To.ResponseModel>,
         response: @escaping (_ with: To.ResponseModel) -> Github.PayloadResponse) {
        self.init(check: Github.check,
                  request: request,
                  toAPI: toAPI,
                  response: response)
    }
}

// MARK: Slack.Request
extension APIConnect where From == Slack.Request {
    init(request: @escaping (_ from: Slack.Request, _ headers: Headers?) -> Either<Slack.Response, To>,
         toAPI: @escaping (_ context: Context)
        -> (To)
        -> EitherIO<Slack.Response, To.ResponseModel>,
         response: @escaping (_ with: To.ResponseModel) -> Slack.Response) {
        self.init(check: Slack.Request.check,
                  request: request,
                  toAPI: toAPI,
                  response: response,
                  fromAPI: Slack.Request.api,
                  instant: Slack.Request.instant)
    }
}

// MARK: - Custom runs

// MARK: Github.Payload -> Youtrack.Request
extension APIConnect where From == Github.Payload, To == Youtrack.Request {
    static func run(_ from: Github.Payload,
                    _ context: Context,
                    _ body: String?,
                    _ headers: Headers?) -> IO<Github.PayloadResponse?> {
        return GithubToYoutrack(request: Youtrack.githubRequest,
                                toAPI: Youtrack.apiWithGithub,
                                response: Youtrack.responseToGithub)
            .run(from, context, body, headers)
    }
}

// MARK: Github.Payload -> Github.APIRequest
extension APIConnect where From == Github.Payload, To == Github.APIRequest {
    static func run(_ from: Github.Payload,
                    _ context: Context,
                    _ body: String?,
                    _ headers: Headers?) -> IO<Github.PayloadResponse?> {
        return GithubToGithub(request: Github.githubRequest,
                              toAPI: Github.apiWithGithub,
                              response: Github.responseToGithub)
            .run(from, context, body, headers)
    }
}

// MARK: Github.Payload -> Github.APIRequest
extension APIConnect where From == Github.Payload, To == CircleCi.JobRequest {
    static func run(_ from: Github.Payload,
                    _ context: Context,
                    _ body: String?,
                    _ headers: Headers?) -> IO<Github.PayloadResponse?> {
        return GithubToCircleCi(request: CircleCi.githubRequest,
                                toAPI: CircleCi.apiWithGithub,
                                response: CircleCi.responseToGithub)
            .run(from, context, body, headers)
    }
}

// MARK: Slack.Request -> CircleCi.JobRequest
extension APIConnect where From == Slack.Request, To == CircleCi.JobRequest {
    static func run(_ from: Slack.Request, _ context: Context) -> IO<Slack.Response?> {
        return SlackToCircleCi(request: CircleCi.slackRequest,
                               toAPI: CircleCi.apiWithSlack,
                               response: CircleCi.responseToSlack)
            .run(from, context, nil, nil)
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
