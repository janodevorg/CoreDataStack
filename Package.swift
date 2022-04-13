// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "CoreDataStack",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "CoreDataStack", type: .dynamic, targets: ["CoreDataStack"]),
        .library(name: "CoreDataStackStatic", type: .static, targets: ["CoreDataStack"])
    ],
    dependencies: [
        .package(url: "git@github.com:apple/swift-docc-plugin.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "CoreDataStack",
            path: "sources/main"
        ),
        .testTarget(
            name: "CoreDataStackTests",
            dependencies: [
                "CoreDataStack"
            ],
            path: "sources/tests",
            resources: [
                .process("resources")
            ]
        )
    ]
)
