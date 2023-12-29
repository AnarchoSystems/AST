// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "AST",
                      platforms: [.iOS(.v16), .macOS(.v13)],
                      products: [
                        .library(name: "AST",
                                 targets: ["AST"]),
                      ],
                      dependencies: [.package(url: "https://github.com/apple/swift-argument-parser.git",
                                              from: Version(1, 3, 0))],
                      targets: [
                        .target(name: "AST"),
                        .target(name: "TestGrammars",
                                dependencies: ["AST"]),
                        .executableTarget(name: "MakeTestGrammarSources",
                                          dependencies: ["AST", "TestGrammars", .product(name: "ArgumentParser", package: "swift-argument-parser")]),
                        .plugin(name: "GenerateTestGrammarSources",
                                capability: .buildTool(),
                                dependencies: ["MakeTestGrammarSources"]),
                        .testTarget(name: "ASTTests",
                                    dependencies: ["AST", "TestGrammars"],
                                    plugins: ["GenerateTestGrammarSources"]),
                      ]
)
