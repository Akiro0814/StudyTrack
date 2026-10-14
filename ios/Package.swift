// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StudyTrackCore",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [.library(name: "StudyTrackCore", targets: ["StudyTrackCore"])],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.8.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20"),
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.12.3")
    ],
    targets: [
        .target(name: "StudyTrackCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift"), "ZIPFoundation",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))],
                path: "StudyTrack", exclude: ["App", "Features", "DesignSystem", "Resources"],
                resources: [.copy("Data/Database/schema.sql")]),
        .testTarget(name: "StudyTrackCoreTests", dependencies: ["StudyTrackCore"], path: "StudyTrackTests", resources: [.copy("Fixtures")])
    ]
)
