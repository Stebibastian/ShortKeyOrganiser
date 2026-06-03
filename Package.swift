// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuShortcutRebinder",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MenuShortcutRebinder",
            path: "Sources/MenuShortcutRebinder"
        )
    ]
)
