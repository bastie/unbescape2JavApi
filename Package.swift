// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "unbescape²JavApi",
    platforms: [.macOS(.v15),.visionOS(.v1),.iOS(.v16),.tvOS(.v16)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "unbescape",
            targets: ["unbescape2JavApi"]),
    ],
    dependencies: [
      .package(
        url: "https://github.com/bastie/JavApi4Swift.git",
        .upToNextMajor(from: "0.23.0") //
      )
    ],
   targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
          name: "unbescape2JavApi",
          dependencies: [
            .product(name: "JavApi", package: "JavApi4Swift")
          ]),
        .testTarget(
            name: "unbescape2JavApiTests",
            dependencies: ["unbescape2JavApi",
                           .product(name: "JavApi", package: "JavApi4Swift")],
            resources: [.process("Resources")]
        ),
    ]
)
