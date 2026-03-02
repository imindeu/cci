import APIModels
import APIService
import Vapor
import JWTKit

public func configure(_ app: Application) async throws {
    try SlackToCircleCi.checkConfigs()
    try GithubToYoutrack.checkConfigs()
    try GithubToGithub.checkConfigs()
    try GithubToCircleCi.checkConfigs()
    
    try routes(app)
}
