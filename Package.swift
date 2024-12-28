// swift-tools-version:6.0
import PackageDescription

nonisolated(unsafe) let package = Package(
    name: "CoreDataStack",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CoreDataStack", targets: ["CoreDataStack"]),
    ],
    dependencies: [
        .package(url: "git@github.com:apple/swift-docc-plugin.git", from: "1.4.3")
    ],
    targets: [
        .target(
            name: "CoreDataStack",
            path: "Sources/Main"
        ),
        .testTarget(
            name: "CoreDataStackTests",
            dependencies: [
                "CoreDataStack"
            ],
            path: "Sources/Tests",
            resources: [
                .process("Resources"),
                .process("Model.xcdatamodeld")
            ]
        )
    ]
)
