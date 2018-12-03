// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "Cci",
    products: [
        .library(name: "APIConnect", targets: ["APIConnect"]),
        .library(name: "APIModels", targets: ["APIModels"]),
        .executable(name: "Run", targets: ["Run"]),
        ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.1.0"),
        .package(url: "https://github.com/vapor/http.git", from: "3.1.6"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.11.0"),
    ],
    targets: [
        .target(name: "APIConnect", dependencies: ["HTTP"]),
        .testTarget(name: "APIConnectTests", dependencies: ["APIConnect"]),
        .target(name: "APIModels", dependencies: []),
        .target(name: "App", dependencies: ["APIConnect", "APIModels", "Vapor"]),
        .testTarget(name: "AppTests", dependencies: ["App"]),
        .target(name: "Run", dependencies: ["App"]),
    ]
)

