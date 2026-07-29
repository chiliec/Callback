// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppCore",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"])
    ],
    targets: [
        .target(
            name: "AppCore",
            resources: [.process("Content/Resources")]
        ),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"])
    ]
)
