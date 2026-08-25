// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FTMSKit",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [
        // Reine Logik-Bibliothek: Parser + Modelle, kein CoreBluetooth, kein UI.
        // Wird später von der iOS-App als lokales Package eingebunden.
        .library(name: "FTMSKit", targets: ["FTMSKit"]),
        // BLE-Transport + Persistenz + HealthKit. Nutzt FTMSKit, kein UI.
        .library(name: "FTMSTransport", targets: ["FTMSTransport"]),
        // macOS-CLI: scannt das Band, dumpt den GATT-Baum, protokolliert 0x2ACD.
        .executable(name: "ftms-dump", targets: ["FTMSDump"])
    ],
    targets: [
        .target(name: "FTMSKit"),
        .target(name: "FTMSTransport", dependencies: ["FTMSKit"]),
        .executableTarget(
            name: "FTMSDump",
            dependencies: ["FTMSKit"],
            exclude: ["Info.plist"],
            linkerSettings: [
                // macOS verlangt NSBluetoothAlwaysUsageDescription, sonst beendet
                // TCC den Prozess beim ersten CoreBluetooth-Zugriff mit SIGABRT.
                // Ein SwiftPM-CLI hat kein Bundle — die Plist wird deshalb direkt
                // in den __TEXT,__info_plist-Abschnitt des Binaries gelinkt.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/FTMSDump/Info.plist"
                ])
            ]
        ),
        .testTarget(name: "FTMSKitTests", dependencies: ["FTMSKit"]),
        .testTarget(name: "FTMSTransportTests", dependencies: ["FTMSTransport"])
    ]
)
