// swift-tools-version: 5.10
import PackageDescription

let settings: [SwiftSetting] = [.enableUpcomingFeature("BareSlashRegexLiterals")]

let package = Package(
    name: "ProofPositive",
    platforms: [.macOS(.v14)],
    targets: [
        // Scanning, rolls, marks and printing. No UI, so it can be checked headless.
        .target(name: "ProofCore", swiftSettings: settings),
        .executableTarget(name: "ProofPositive", dependencies: ["ProofCore"], swiftSettings: settings),
        // The Command Line Tools ship neither XCTest nor Swift Testing, so core checks run as a plain executable.
        .executableTarget(name: "ProofChecks", dependencies: ["ProofCore"], swiftSettings: settings),
    ]
)
