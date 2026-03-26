import App
import APIService
import APIModels
import Vapor
import Foundation

// The contents of main are wrapped in a do/catch block
// because any errors that get raised to the top level will crash Xcode
do {
    guard
        let githubPrivateKey = Environment.get(Github.APIRequest.Config.githubPrivateKey)?
            .replacingOccurrences(of: "\\n", with: "\n")
    else { throw Github.Error.jwt }

    let env = try Environment.detect()
    let app = try await Application.make(env)

    try await Service.load(ProductionAPI(app), githubPrivateKey: githubPrivateKey)
    try await configure(app)
    try await app.execute()
} catch {
    print(error)
    exit(1)
}

private final class ProductionAPI: BackendAPIType {
    private let application: Application
    
    init(_ application: Application) {
        self.application = application
    }
    
    func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
        application.http.client.shared.execute(request: request)
    }
}
