// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CurrencyConverterFeature",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CurrencyConverterFeature",
            targets: ["CurrencyConverterFeature"]
        )
    ],
    targets: [
        .target(
            name: "CurrencyConverterFeature",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CurrencyConverterFeatureTests",
            dependencies: ["CurrencyConverterFeature"]
        )
    ]
)
