import Vapor

public func configure(
    _ config: inout Config,
    _ env: inout Vapor.Environment,
    _ services: inout Services
) throws {

    try SlackToCircleCi.checkConfigs()
    try GithubToYoutrack.checkConfigs()
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
//    let serverConfiure = NIOServerConfig.default(hostname: "0.0.0.0", port: 8080)
//    services.register(serverConfiure)
}
