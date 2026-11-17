// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TokenMeter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TokenMeterCore", targets: ["TokenMeterCore"]),
        .executable(name: "tokenmeter-probe", targets: ["tokenmeter-probe"]),
        .executable(name: "tokenmeter", targets: ["tokenmeter"]),
    ],
    targets: [
        .target(name: "TokenMeterCore"),
        .executableTarget(name: "tokenmeter-probe", dependencies: ["TokenMeterCore"]),
        .executableTarget(name: "tokenmeter", dependencies: ["TokenMeterCore"]),
        .testTarget(name: "TokenMeterCoreTests", dependencies: ["TokenMeterCore"]),
    ]
)
