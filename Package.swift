// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VinylAudio",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "VinylAudio",
            path: "Sources/VinylAudio"
        )
    ]
)
