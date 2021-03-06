//
//  Slack.swift
//  App
//
//  Created by Peter Geszten-Kovacs on 2018. 05. 16..
//
import APIConnect
import enum APIModels.Slack

import protocol Foundation.LocalizedError
import struct Foundation.Data
import struct Foundation.URL
import class Foundation.JSONEncoder

import struct HTTP.HTTPBody
import struct HTTP.HTTPHeaders
import struct HTTP.HTTPRequest
import enum HTTP.HTTPMethod

extension Slack {
    enum Error: LocalizedError {
        case badToken
        case missingResponseURL
        case combined([Error])
        
        public var errorDescription: String? {
            switch self {
            case .badToken: return "Bad slack token"
            case .missingResponseURL: return "Missing slack token"
            case .combined(let errors):
                return errors.map { $0.localizedDescription }.joined(separator: ", ")
            }
        }
    }
}

extension Slack.Request: DelayedRequestModel {
    public typealias ResponseModel = Slack.Response
    
    public enum Config: String, Configuration {
        case slackToken
    }
    
    public var responseURL: URL? { return URL(string: responseUrlString) }
}

extension Slack {
    static func check(_ from: Request, _ body: String? = nil, _ headers: Headers? = nil) -> Response? {
        var errors: [Error] = []
        let token = Environment.get(Request.Config.slackToken)
        if token == nil || from.token != token! {
            errors.append(.badToken)
        }
        if from.responseURL == nil {
            errors.append(.missingResponseURL)
        }
        guard !errors.isEmpty else { return nil }
        return Response.error(Error.combined(errors))
    }
    static func api(_ request: Request, _ context: Context) -> (Response) -> IO<Void> {
        return { response in
            guard let url = request.responseURL,
                let hostname = url.host,
                let body = try? JSONEncoder().encode(response) else {
                    
                return Environment.emptyApi(context).map { _ in () }
            }
            let returnAPI = Environment
                .api(hostname, url.port)
            let request = HTTPRequest(method: .POST,
                                      url: url.path,
                                      headers: HTTPHeaders([("Content-Type", "application/json")]),
                                      body: HTTPBody(data: body))
            return returnAPI(context, request).map { _ in () }
        }
    }
    static func instant(_ context: Context) -> (Request) -> IO<Response?> {
        return const(pure(Response.instant, context))
    }
}

extension Slack.Response {
    static var instant: Slack.Response? {
        return nil
    }
}

extension Slack.Response {
    static func error(_ error: LocalizedError, helpResponse: Slack.Response? = nil) -> Slack.Response {
        let text = error.localizedDescription
        let attachment = Slack.Response.Attachment(fallback: text,
                                                   text: text,
                                                   color: "danger",
                                                   mrkdwnIn: [],
                                                   fields: [])
        guard let helpResponse = helpResponse else {
            return Slack.Response(responseType: .ephemeral, text: nil, attachments: [attachment], mrkdwn: true)
        }
        var copy = helpResponse
        let attachments = copy.attachments
        copy.attachments = [attachment] + attachments
        return copy
    }
    
}
