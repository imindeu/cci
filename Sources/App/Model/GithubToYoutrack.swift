//
//  GithubToYoutrack.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

import APIConnect
import APIModels

typealias GithubToYoutrack = APIConnect<GithubWebhook.Request, Youtrack.Request, Environment>

extension APIConnect where From == GithubWebhook.Request {
    init(request: @escaping (_ from: GithubWebhook.Request, _ headers: Headers?) -> Either<GithubWebhook.Response, To>,
         toAPI: @escaping (_ context: Context)
            -> (Either<GithubWebhook.Response, To>)
            -> EitherIO<GithubWebhook.Response, To.ResponseModel>,
         response: @escaping (_ with: To.ResponseModel) -> GithubWebhook.Response) {
        self.init(check: GithubWebhook.check,
                  request: request,
                  toAPI: toAPI,
                  response: response)
    }
}

extension APIConnect where From == GithubWebhook.Request, To == Youtrack.Request {
    static func run(_ from: GithubWebhook.Request,
                    _ context: Context,
                    _ payload: String?,
                    _ headers: Headers?) -> IO<GithubWebhook.Response?> {
        return GithubToYoutrack(request: Youtrack.githubWebhookRequest,
                                toAPI: Youtrack.apiWithGithubWebhook,
                                response: Youtrack.responseToGithubWebhook)
            .run(from, context, payload, headers)
    }
}
