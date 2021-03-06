import Vapor

public func configure(
    _ config: inout Config,
    _ env: inout Vapor.Environment,
    _ services: inout Services
) throws {

    try SlackToCircleCi.checkConfigs()
    try GithubToYoutrack.checkConfigs()
    try GithubToGithub.checkConfigs()
    try GithubToCircleCi.checkConfigs()
    
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
}
