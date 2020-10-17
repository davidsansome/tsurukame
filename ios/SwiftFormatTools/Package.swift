// swift-tools-version:5.1
import PackageDescription

let package = Package(name: "SwiftFormatTools",
                      platforms: [.macOS(.v10_11)],
                      dependencies: [
                         .package(url: "https://github.com/nicklockwood/SwiftFormat",
                                  .upToNextMinor(from: "0.46.0")),
                      ],
                      targets: [.target(name: "SwiftFormatTools", path: "")])
