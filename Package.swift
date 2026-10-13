// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ITunesSearchKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ITunesSearchKit", targets: ["ITunesSearchKit"]),
        .library(name: "ITunesSearchUI", targets: ["ITunesSearchUI"]),
    ],
    targets: [
        .target(name: "ITunesSearchKit"),
        .target(name: "ITunesSearchUI", dependencies: ["ITunesSearchKit"]),
        .testTarget(
            name: "ITunesSearchKitTests",
            dependencies: ["ITunesSearchKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
