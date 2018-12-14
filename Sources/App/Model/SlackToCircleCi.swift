//
//  SlackToCircleCi.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//
import APIConnect
import APIModels

typealias SlackToCircleCi = APIConnect<Slack.Request, CircleCi.JobRequest, Environment>

extension APIConnect where From == Slack.Request {
    init(request: @escaping (_ from: Slack.Request, _ headers: Headers?) -> Either<Slack.Response, To>,
         toAPI: @escaping (_ context: Context)
            -> (Either<Slack.Response, To>)
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

extension APIConnect where From == Slack.Request, To == CircleCi.JobRequest {
    static func run(_ from: Slack.Request, _ context: Context) -> IO<Slack.Response?> {
        return SlackToCircleCi(request: CircleCi.slackRequest,
                               toAPI: CircleCi.apiWithSlack,
                               response: CircleCi.responseToSlack)
            .run(from, context, nil, nil)
    }
}
