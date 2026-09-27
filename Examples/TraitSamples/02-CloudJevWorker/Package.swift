// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CloudJevWorker",
    platforms: [
        .macOS("27.0"),
        .iOS("27.0")
    ],
    dependencies: [
        .package(name: "SystemOneFoundationModels", path: "../../..", traits: ["Jev"])
    ],
    targets: [
        .executableTarget(
            name: "CloudJevWorker",
            dependencies: [
                .product(name: "SystemOneFoundationModels", package: "SystemOneFoundationModels")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
