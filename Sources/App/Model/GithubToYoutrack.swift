//
//  GithubToYoutrack.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

import APIConnect
import APIModels

typealias GithubToYoutrack = APIConnect<Github.Payload, Youtrack.Request, Environment>

extension APIConnect where From == Github.Payload {
    init(request: @escaping (_ from: Github.Payload, _ headers: Headers?) -> Either<Github.PayloadResponse, To>,
         toAPI: @escaping (_ context: Context)
            -> (Either<Github.PayloadResponse, To>)
            -> EitherIO<Github.PayloadResponse, To.ResponseModel>,
         response: @escaping (_ with: To.ResponseModel) -> Github.PayloadResponse) {
        self.init(check: Github.check,
                  request: request,
                  toAPI: toAPI,
                  response: response)
    }
}

extension APIConnect where From == Github.Payload, To == Youtrack.Request {
    static func run(_ from: Github.Payload,
                    _ context: Context,
                    _ payload: String?,
                    _ headers: Headers?) -> IO<Github.PayloadResponse?> {
        return GithubToYoutrack(request: Youtrack.githubWebhookRequest,
                                toAPI: Youtrack.apiWithGithub,
                                response: Youtrack.responseToGithub)
            .run(from, context, payload, headers)
    }
}
