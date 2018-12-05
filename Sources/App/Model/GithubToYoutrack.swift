//
//  GithubToYoutrack.swift
//  APIConnect
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 03..
//

import APIConnect
import APIModels

typealias GithubToYoutrack = APIConnect<GithubWebhookRequest, YoutrackRequest, Environment>

extension APIConnect where From == GithubWebhookRequest {
    init(request: @escaping (_ from: GithubWebhookRequest) -> Either<GithubWebhookResponse, To>,
         toAPI: @escaping (_ context: Context)
            -> (Either<GithubWebhookResponse, To>)
            -> EitherIO<GithubWebhookResponse, To.ResponseModel>,
         response: @escaping (_ with: To.ResponseModel) -> GithubWebhookResponse) {
        self.init(check: GithubWebhookRequest.check,
                  request: request,
                  toAPI: toAPI,
                  response: response)
    }
}

extension APIConnect where From == GithubWebhookRequest, To == YoutrackRequest {
    static func run(_ from: GithubWebhookRequest,
                    _ context: Context,
                    _ payload: String?,
                    _ headers: Headers?) -> IO<GithubWebhookResponse?> {
        return GithubToYoutrack(request: YoutrackRequest.githubWebhookRequest,
                                toAPI: YoutrackRequest.apiWithGithubWebhook,
                                response: YoutrackRequest.responseToGithubWebhook)
            .run(from, context, payload, headers)
    }
}
