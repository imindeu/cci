import Foundation

import Vapor

public protocol BackendAPIType {
    func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response>
}
