// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "CoreDataStack",
    platforms: [
        .iOS(.v15), .macOS(.v12)
    ],
    products: [
        .library(name: "CoreDataStack", type: .dynamic, targets: ["CoreDataStack"]),
        .library(name: "CoreDataStackStatic", type: .static, targets: ["CoreDataStack"])
    ],
    dependencies: [
        .package(url: "git@github.com:janodevorg/Kit.git", branch: "main"),
        .package(url: "git@github.com:apple/swift-docc-plugin.git", branch: "main")
    ],
    targets: [
        .target(
            name: "CoreDataStack",
            path: "sources/main"
        ),
        .testTarget(
            name: "CoreDataStackTests",
            dependencies: [
                "CoreDataStack",
                .product(name: "Kit", package: "Kit"),
            ],
            path: "sources/tests",
            resources: [
                .process("resources")
            ]
        )
    ]
)
