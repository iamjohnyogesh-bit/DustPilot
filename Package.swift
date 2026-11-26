// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DustPilot",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DustPilot", targets: ["DustPilot"])],
    targets: [
        // Foundation-only logic: scanning, filtering, selection, trashing. Unit-tested.
        .target(name: "DustPilotCore", path: "Sources/DustPilotCore"),
        // SwiftUI app (macOS only; the sources compile to nothing elsewhere).
        .executableTarget(name: "DustPilot", dependencies: ["DustPilotCore"], path: "Sources/DustPilot"),
        .testTarget(name: "DustPilotCoreTests", dependencies: ["DustPilotCore"], path: "Tests/DustPilotCoreTests"),
    ]
)
