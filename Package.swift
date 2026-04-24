// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "mcopy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "mcopy", targets: ["mcopy"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.23.0")
    ],
    targets: [
        .executableTarget(
            name: "mcopy",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "mcopy",
            exclude: [
                "Info.plist",
                "mcopy.entitlements"
            ]
        )
    ]
)
