// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "CoreDataStack",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "CoreDataStack", type: .static, targets: ["CoreDataStack"]),
        .library(name: "CoreDataStackDynamic", type: .dynamic, targets: ["CoreDataStack"])
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
                .process("resources"),
                .process("Model.xcdatamodeld")
            ]
        )
    ]
)
