//
//  SlackToCircleCi.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 11. 21..
//
import APIConnect

extension APIConnect where From == SlackRequest {
    init(request: @escaping (_ from: SlackRequest, _ environment: Environment) -> Either<SlackResponse, To>,
         toAPI: @escaping (_ context: Context, _ environment: Environment) -> (Either<SlackResponse, To>) -> IO<Either<SlackResponse, To.Response>>,
         response: @escaping (_ with: To.Response) -> SlackResponse) throws {
        try self.init(check: SlackRequest.check,
                      request: request,
                      toAPI: toAPI,
                      response: response,
                      fromAPI: SlackRequest.api,
                      instant: SlackRequest.instant)
    }
}

extension APIConnect where From == SlackRequest, To == CircleCiJobRequest {
    static func slackToCircleCiTest() throws -> APIConnect {
        return try APIConnect<SlackRequest, CircleCiJobRequest>(request: CircleCiJobRequest.slackRequest,
                                                                toAPI: CircleCiJobRequest.apiWithSlack,
                                                                response: CircleCiJobRequest.responseToSlack)
    }
}
