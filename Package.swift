// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Pomodoro", targets: ["Pomodoro"])
    ],
    targets: [
        .executableTarget(name: "Pomodoro")
    ]
)
