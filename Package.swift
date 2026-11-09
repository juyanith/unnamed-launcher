// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "UnnamedLauncher",
    platforms: [.macOS(.v27)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "UnnamedLauncherKit"),
        .executableTarget(
            name: "UnnamedLauncher",
            dependencies: ["UnnamedLauncherKit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "UnnamedLauncherKitTests", dependencies: ["UnnamedLauncherKit"]),
    ]
)
