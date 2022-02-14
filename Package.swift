// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "webrtc-vapor",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "webrtc-vapor",
            targets: ["webrtc-vapor","WebRTC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0")
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "webrtc-vapor",
            dependencies: [.product(name: "Vapor", package: "vapor"),
                          ]),
        .binaryTarget(
                    name: "WebRTC",
                    path: "WebRTC.xcframework"
                ),
        .testTarget(
            name: "webrtc-vaporTests",
            dependencies: ["webrtc-vapor",
                           .product(name: "XCTVapor", package: "vapor")]),
    ]
)
