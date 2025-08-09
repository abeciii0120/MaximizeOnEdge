// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MaximizeOnEdge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MaximizeOnEdge", targets: ["MaximizeOnEdge"])    
    ],
    targets: [
        .executableTarget(
            name: "MaximizeOnEdge",
            path: "Sources/MaximizeOnEdge",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
