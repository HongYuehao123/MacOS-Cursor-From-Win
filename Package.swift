// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WinToMacCursor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "WinToMacCursor",
            targets: ["WinToMacCursor"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WinToMacCursor",
            path: "Sources/WinToMacCursor",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/WinToMacCursor/Info.plist"
                ])
            ]
        )
    ]
)
