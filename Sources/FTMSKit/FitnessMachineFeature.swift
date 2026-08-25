import Foundation

/// Fitness Machine Feature Characteristic `0x2ACC` — 8 Bytes:
/// uint32 »Fitness Machine Features« + uint32 »Target Setting Features«,
/// beide little endian.
///
/// Bit-Namen wörtlich aus FTMS v1.0, Tabellen 4.3 und 4.4.
public struct FitnessMachineFeature: Equatable, Sendable {
    public let merkmale: UInt32
    public let zielwerte: UInt32

    /// Was das Gerät messen/melden kann (Tabelle 4.3).
    public static let merkmalNamen = [
        "Average Speed", "Cadence", "Total Distance", "Inclination",
        "Elevation Gain", "Pace", "Step Count", "Resistance Level",
        "Stride Count", "Expended Energy", "Heart Rate Measurement",
        "Metabolic Equivalent", "Elapsed Time", "Remaining Time",
        "Power Measurement", "Force on Belt and Power Output",
        "User Data Retention"
    ]

    /// Was per Control Point `0x2AD9` gesetzt werden kann (Tabelle 4.4).
    public static let zielwertNamen = [
        "Speed Target Setting", "Inclination Target Setting",
        "Resistance Target Setting", "Power Target Setting",
        "Heart Rate Target Setting", "Targeted Expended Energy Configuration",
        "Targeted Step Number Configuration", "Targeted Stride Number Configuration",
        "Targeted Distance Configuration", "Targeted Training Time Configuration",
        "Targeted Time in Two Heart Rate Zones Configuration",
        "Targeted Time in Three Heart Rate Zones Configuration",
        "Targeted Time in Five Heart Rate Zones Configuration",
        "Indoor Bike Simulation Parameters", "Wheel Circumference Configuration",
        "Spin Down Control", "Targeted Cadence Configuration"
    ]

    /// Gibt `nil` zurück, wenn die Nutzlast kürzer als 8 Bytes ist.
    public init?(daten: Data) {
        guard daten.count >= 8 else { return nil }
        var leser = ByteLeser(daten)
        guard let m = try? leser.uint32("Fitness Machine Features"),
              let z = try? leser.uint32("Target Setting Features") else { return nil }
        merkmale = m
        zielwerte = z
    }

    public init(merkmale: UInt32, zielwerte: UInt32) {
        self.merkmale = merkmale
        self.zielwerte = zielwerte
    }

    private static func gesetzte(_ maske: UInt32, _ namen: [String]) -> [String] {
        namen.enumerated().compactMap { index, name in
            (maske >> UInt32(index)) & 1 == 1 ? name : nil
        }
    }

    public var unterstuetzteMerkmale: [String] {
        Self.gesetzte(merkmale, Self.merkmalNamen)
    }

    public var unterstuetzteZielwerte: [String] {
        Self.gesetzte(zielwerte, Self.zielwertNamen)
    }

    /// Kann das Band per Control Point auf eine Zielgeschwindigkeit gesetzt werden?
    /// Entscheidet, ob Phase 6 (Steuerung) an diesem Gerät überhaupt möglich ist.
    public var geschwindigkeitSteuerbar: Bool { zielwerte & 1 == 1 }
    public var neigungSteuerbar: Bool { (zielwerte >> 1) & 1 == 1 }
}
