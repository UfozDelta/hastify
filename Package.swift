// swift-tools-version:5.9
// Test-only package: compiles the platform-neutral logic in Shared/ so CI can run it
// on a cheap Linux runner. The app itself is still built by XcodeGen (project.yml).
import PackageDescription

let package = Package(
    name: "HastifyCore",
    products: [
        .library(name: "HastifyCore", targets: ["HastifyCore"]),
    ],
    targets: [
        .target(name: "HastifyCore", path: "Shared"),
        .testTarget(name: "HastifyCoreTests", dependencies: ["HastifyCore"], path: "Tests/HastifyCoreTests"),
    ]
)
