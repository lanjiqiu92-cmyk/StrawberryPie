// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChocolatePie",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ChocolatePie", targets: ["ChocolatePie"])
    ],
    targets: [
        .executableTarget(
            name: "ChocolatePie",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("Security")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
