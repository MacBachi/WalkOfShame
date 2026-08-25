import Foundation

/// Training Status `0x2AD3` — uint8 Flags, uint8 Training Status,
/// optional ein UTF-8-String.
public struct TrainingStatus: Equatable, Sendable {
    public let flags: UInt8
    public let status: UInt8
    public let text: String?

    /// Werte laut FTMS v1.0, Tabelle 4.13.
    public static let bezeichnungen: [UInt8: String] = [
        0x00: "Other",
        0x01: "Idle",
        0x02: "Warming Up",
        0x03: "Low Intensity Interval",
        0x04: "High Intensity Interval",
        0x05: "Recovery Interval",
        0x06: "Isometric",
        0x07: "Heart Rate Control",
        0x08: "Fitness Test",
        0x09: "Speed Outside of Control Region - Low",
        0x0A: "Speed Outside of Control Region - High",
        0x0B: "Cool Down",
        0x0C: "Watt Control",
        0x0D: "Manual Mode (Quick Start)",
        0x0E: "Pre-Workout",
        0x0F: "Post-Workout"
    ]

    public init?(daten: Data) {
        guard daten.count >= 2 else { return nil }
        var leser = ByteLeser(daten)
        guard let f = try? leser.uint8("Flags"),
              let s = try? leser.uint8("Training Status") else { return nil }
        flags = f
        status = s
        let rest = leser.rest
        text = rest.isEmpty ? nil : String(data: Data(rest), encoding: .utf8)
    }

    public var bezeichnung: String {
        Self.bezeichnungen[status] ?? String(format: "Reserved (0x%02X)", status)
    }

    /// Läuft gerade ein Training? Relevant für Start/Stopp der HealthKit-Session.
    public var trainingLaeuft: Bool {
        ![0x00, 0x01, 0x0F].contains(status)
    }
}
