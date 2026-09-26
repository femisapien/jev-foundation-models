// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "OfflineLayaApp",
    platforms: [
        .macOS("27.0"),
        .iOS("27.0")
    ],
    dependencies: [
        .package(name: "SystemOneFoundationModels", path: "../../..", traits: ["Laya"])
    ],
    targets: [
        .executableTarget(
            name: "OfflineLayaApp",
            dependencies: [
                .product(name: "SystemOneFoundationModels", package: "SystemOneFoundationModels")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
