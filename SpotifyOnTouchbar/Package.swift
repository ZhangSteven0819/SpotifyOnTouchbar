// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpotifyOnTouchbar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SpotifyOnTouchbar",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"])
            ]
        )
    ]
)
