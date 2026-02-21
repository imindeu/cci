// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// swiftlint:disable:next prefixed_toplevel_constant
let package = Package(
    name: "CCI",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "APIConnect", targets: ["APIConnect"]),
        .library(name: "APIModels", targets: ["APIModels"]),
        .library(name: "APIService", targets: ["APIService"]),
        .executable(name: "cci", targets: ["CCI"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "APIConnect", 
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        .testTarget(name: "APIConnectTests", dependencies: ["APIConnect"]),
        
        .target(
            name: "Mocks", 
            dependencies: [
                "APIConnect",
                "APIModels",
                "APIService",
                .product(name: "Vapor", package: "vapor")
            ]
        ),

        .target(
            name: "APIModels", 
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        
        .target(
            name: "APIService", 
            dependencies: [
                "APIConnect", 
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt")
            ]
        ),
        .testTarget(
            name: "APIServiceTests", 
            dependencies: [
                "APIService",
                "APIModels",
                "Mocks",
                .product(name: "XCTVapor", package: "vapor")
            ]
        ),
        
        .target(
            name: "App", 
            dependencies: [
                "APIConnect", 
                "APIModels", 
                "APIService", 
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        .testTarget(name: "AppTests", dependencies: ["App", "Mocks"]),

        .executableTarget(name: "CCI", dependencies: ["App"])
    ]
)
