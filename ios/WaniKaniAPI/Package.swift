// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "WaniKaniAPI",
                      platforms: [
                        .iOS("12.0"),
                        .macOS("14.6"),
                      ],
                      products: [
                        // Products define the executables and libraries a package produces, and
                        // make them visible to other packages.
                        .library(name: "WaniKaniAPI",
                                 targets: ["WaniKaniAPI"]),
                      ],
                      dependencies: [
                        // Dependencies declare other packages that this package depends on.
                        .package(url: "https://github.com/apple/swift-protobuf", from: "1.15.0"),
                        .package(url: "https://github.com/mxcl/PromiseKit",
                                 from: "6.13.3"),
                        .package(name: "PMKFoundation",
                                 url: "https://github.com/PromiseKit/Foundation.git",
                                 from: "3.3.4"),
                        .package(url: "https://github.com/JanGorman/Hippolyte",
                                 from: "1.3.0"),
                      ],
                      targets: [
                        // Targets are the basic building blocks of a package. A target can define a
                        // module or a test suite.
                        // Targets can depend on other targets in this package, and on products in
                        // packages this package depends on.
                        .target(name: "WaniKaniAPI",
                                dependencies: [
                                  "PromiseKit",
                                  "PMKFoundation",
                                  .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                                ],
                                resources: [
                                  .copy("Resources/old-mnemonics.json"),
                                  .copy("Resources/visually-similar-kanji.json"),
                                ]),
                        .testTarget(name: "WaniKaniAPITests",
                                    dependencies: ["Hippolyte", "WaniKaniAPI"]),
                        .testTarget(name: "WaniKaniAPIProber",
                                dependencies: ["WaniKaniAPI"]),
                      ])
