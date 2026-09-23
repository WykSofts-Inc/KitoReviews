// swift-tools-version: 5.9
//
//  Package.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "KitoReviews",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoReviews", targets: ["KitoReviews"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoCore.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "KitoReviews", dependencies: [.product(name: "KitoCore", package: "KitoCore")]),
        .testTarget(name: "KitoReviewsTests", dependencies: ["KitoReviews"]),
    ]
)
