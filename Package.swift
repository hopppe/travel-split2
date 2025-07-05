// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TravelSplit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "TravelSplitModels", targets: ["TravelSplitModels"]),
        .library(name: "TravelSplitServices", targets: ["TravelSplitServices"]),
        .library(name: "TravelSplitViewModels", targets: ["TravelSplitViewModels"]),
        .library(name: "TravelSplitExtensions", targets: ["TravelSplitExtensions"]),
        .library(name: "TravelSplitViews", targets: ["TravelSplitViews"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0")
    ],
    targets: [
        // Models - Start here for incremental conversion
        .target(
            name: "TravelSplitModels",
            dependencies: [
                .product(name: "SkipFoundation", package: "skip-foundation"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
            ],
            path: "travel split/Models",
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        
        // Services - Next phase
        .target(
            name: "TravelSplitServices", 
            dependencies: [
                "TravelSplitModels",
                .product(name: "SkipFoundation", package: "skip-foundation"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
            ],
            path: "travel split/Services",
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        
        // ViewModels - Third phase
        .target(
            name: "TravelSplitViewModels",
            dependencies: [
                "TravelSplitModels",
                "TravelSplitServices",
                .product(name: "SkipFoundation", package: "skip-foundation"),
                .product(name: "SkipUI", package: "skip-ui"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
            ],
            path: "travel split/ViewModels",
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        
        // Extensions - Fourth phase
        .target(
            name: "TravelSplitExtensions",
            dependencies: [
                "TravelSplitServices",
                .product(name: "SkipFoundation", package: "skip-foundation"),
                .product(name: "SkipUI", package: "skip-ui")
            ],
            path: "travel split/Extensions",
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        
        // Views - Fifth phase
        .target(
            name: "TravelSplitViews",
            dependencies: [
                "TravelSplitModels",
                "TravelSplitServices", 
                "TravelSplitViewModels",
                "TravelSplitExtensions",
                .product(name: "SkipFoundation", package: "skip-foundation"),
                .product(name: "SkipUI", package: "skip-ui"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
            ],
            path: "travel split/Views",
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        
        // Tests
        .testTarget(
            name: "TravelSplitModelsTests",
            dependencies: ["TravelSplitModels"]
        ),
    ]
) 