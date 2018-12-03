//
//  SlackToCircleCi.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//
import APIConnect
import APIModels

typealias SlackToCircleCi = APIConnect<SlackRequest, CircleCiJobRequest, Environment>

extension APIConnect where From == SlackRequest {
    init(request: @escaping (_ from: SlackRequest) -> Either<SlackResponse, To>,
         toAPI: @escaping (_ context: Context) -> (Either<SlackResponse, To>) -> EitherIO<SlackResponse, To.ResponseModel>,
         response: @escaping (_ with: To.ResponseModel) -> SlackResponse) {
        self.init(check: SlackRequest.check,
                      request: request,
                      toAPI: toAPI,
                      response: response,
                      fromAPI: SlackRequest.api,
                      instant: SlackRequest.instant)
    }
}

extension APIConnect where From == SlackRequest, To == CircleCiJobRequest {
    static func run(_ from: SlackRequest, _ context: Context) -> EitherIO<Empty, SlackResponse> {
        return APIConnect<SlackRequest, CircleCiJobRequest, E>(
            request: CircleCiJobRequest.slackRequest,
            toAPI: CircleCiJobRequest.apiWithSlack,
            response: CircleCiJobRequest.responseToSlack)
            .run(from, context)
    }
}
