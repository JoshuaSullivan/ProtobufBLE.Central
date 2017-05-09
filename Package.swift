// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "ProtobufReceiver",

    dependencies: [
      .Package(url: "https://github.com/apple/swift-protobuf.git", majorVersion:0, minor:9),
    ]
)
