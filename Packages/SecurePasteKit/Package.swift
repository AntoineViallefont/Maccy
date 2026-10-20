// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SecurePasteKit",
  platforms: [.macOS(.v14)],
  products: [.library(name: "SecurePasteKit", targets: ["SecurePasteKit"])],
  targets: [
    .target(name: "SecurePasteKit"),
    .testTarget(name: "SecurePasteKitTests", dependencies: ["SecurePasteKit"])
  ]
)
