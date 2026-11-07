// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AsunRemote",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "RemoteCore", targets: ["RemoteCore"])],
    targets: [
        .target(name: "RemoteCore", path: "AsunRemote/Core"),
        .testTarget(name: "RemoteCoreTests", dependencies: ["RemoteCore"], path: "Tests")
    ]
)
