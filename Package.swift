// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TokenMeter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TokenMeterCore", targets: ["TokenMeterCore"]),
        .executable(name: "tokenmeter-probe", targets: ["tokenmeter-probe"]),
    ],
    targets: [
        .target(name: "TokenMeterCore"),
        .executableTarget(name: "tokenmeter-probe", dependencies: ["TokenMeterCore"]),
        .testTarget(name: "TokenMeterCoreTests", dependencies: ["TokenMeterCore"]),
    ]
)
