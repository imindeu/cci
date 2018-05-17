import Vapor

public func configure(
    _ config: inout Config,
    _ env: inout Vapor.Environment,
    _ services: inout Services
) throws {
    
    try AppEnvironment.fromVapor()

    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    if let portString = Vapor.Environment.get("port"), let port = Int(portString) {
        let nioServer = NIOServerConfig.default(port: port)
        services.register(nioServer)
    }
}
