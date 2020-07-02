// swift-tools-version:5.1
import PackageDescription

let package = Package(name: "SwiftFormatTools",
                      platforms: [.macOS(.v10_11)],
                      dependencies: [
                        .package(url: "https://github.com/nicklockwood/SwiftFormat",
                                 from: "0.44.11"),
                      ],
                      targets: [.target(name: "SwiftFormatTools", path: "")])
