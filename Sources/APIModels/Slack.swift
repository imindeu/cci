//
//  Slack.swift
//  APIModels
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

public struct SlackRequest: Equatable, Codable {
    public let token: String
    public let teamId: String
    public let teamDomain: String
    public let enterpriseId: String?
    public let enterpriseName: String?
    public let channelId: String
    public let channelName: String
    public let userId: String
    public let userName: String
    public let command: String
    public let text: String
    public let responseUrlString: String
    public let triggerId: String
    
    public init(token: String,
                teamId: String,
                teamDomain: String,
                enterpriseId: String?,
                enterpriseName: String?,
                channelId: String,
                channelName: String,
                userId: String,
                userName: String,
                command: String,
                text: String,
                responseUrlString: String,
                triggerId: String) {
        self.token = token
        self.teamId = teamId
        self.teamDomain = teamDomain
        self.enterpriseId = enterpriseId
        self.enterpriseName = enterpriseName
        self.channelId = channelId
        self.channelName = channelName
        self.userId = userId
        self.userName = userName
        self.command = command
        self.text = text
        self.responseUrlString = responseUrlString
        self.triggerId = triggerId
    }
    
    enum CodingKeys: String, CodingKey {
        case token
        case teamId = "team_id"
        case teamDomain = "team_domain"
        case enterpriseId = "enterprise_id"
        case enterpriseName = "enterprise_name"
        case channelId = "channel_id"
        case channelName = "channel_name"
        case userId = "user_id"
        case userName = "user_name"
        case command
        case text
        case responseUrlString = "response_url"
        case triggerId = "trigger_id"
    }
}

public struct SlackResponse: Equatable, Codable {
    public let responseType: ResponseType
    public let text: String?
    public var attachments: [Attachment]
    public let mrkdwn: Bool?
    
    public init(responseType: ResponseType,
                text: String?,
                attachments: [Attachment],
                mrkdwn: Bool?) {
        self.responseType = responseType
        self.text = text
        self.attachments = attachments
        self.mrkdwn = mrkdwn
    }
    
    public enum ResponseType: String, Codable {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    
    public struct Attachment: Equatable, Codable {
        public let fallback: String?
        public let text: String?
        public let color: String?
        public let mrkdwnIn: [String]
        public let fields: [Field]
        
        public init(fallback: String?,
                    text: String?,
                    color: String?,
                    mrkdwnIn: [String],
                    fields: [Field]) {
            self.fallback = fallback
            self.text = text
            self.color = color
            self.mrkdwnIn = mrkdwnIn
            self.fields = fields
        }
        
        enum CodingKeys: String, CodingKey {
            case fallback
            case text
            case color
            case mrkdwnIn = "mrkdwn_in"
            case fields
        }
    }
    
    public struct Field: Equatable, Codable {
        public let title: String?
        public let value: String?
        public let short: Bool?
        
        public init(title: String?, value: String?, short: Bool?) {
            self.title = title
            self.value = value
            self.short = short
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case responseType = "response_type"
        case text
        case attachments
        case mrkdwn
    }
    
}
